// JNI bridge between Kotlin's VisualizerBridge and libprojectM-4.so.
//
// The Kotlin side owns the Flutter SurfaceTexture and the render
// thread; this C++ owns the EGL context and the projectm_handle.
// projectM rendering must happen on the same thread that created
// the GL context, so the render thread invariably runs Kotlin →
// JNI → here → projectM.
//
// JNI naming convention: function names mirror the Kotlin class
// 'com.example.mstream_music.VisualizerBridge'. Underscore in the
// package name (mstream_music) becomes '_1' in the JNI symbol.

#include <jni.h>
#include <android/log.h>
#include <android/native_window_jni.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES3/gl3.h>
#include <projectM-4/projectM.h>
#include <cstdlib>

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

struct BridgeContext {
    EGLDisplay display = EGL_NO_DISPLAY;
    EGLContext context = EGL_NO_CONTEXT;
    EGLSurface surface = EGL_NO_SURFACE;
    ANativeWindow* window = nullptr;
    projectm_handle pm = nullptr;
    int width = 0;
    int height = 0;
};

bool setupEgl(BridgeContext* ctx) {
    ctx->display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (ctx->display == EGL_NO_DISPLAY) {
        LOGE("eglGetDisplay failed");
        return false;
    }
    if (!eglInitialize(ctx->display, nullptr, nullptr)) {
        LOGE("eglInitialize failed: 0x%x", eglGetError());
        return false;
    }

    const EGLint configAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_WINDOW_BIT,
        EGL_RED_SIZE,   8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE,  8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 0,
        EGL_STENCIL_SIZE, 0,
        EGL_NONE,
    };
    EGLConfig config;
    EGLint numConfigs = 0;
    if (!eglChooseConfig(ctx->display, configAttrs, &config, 1, &numConfigs)
        || numConfigs < 1) {
        LOGE("eglChooseConfig failed: 0x%x", eglGetError());
        return false;
    }

    const EGLint contextAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    ctx->context = eglCreateContext(ctx->display, config, EGL_NO_CONTEXT,
                                     contextAttrs);
    if (ctx->context == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed: 0x%x", eglGetError());
        return false;
    }

    ctx->surface = eglCreateWindowSurface(ctx->display, config,
                                           ctx->window, nullptr);
    if (ctx->surface == EGL_NO_SURFACE) {
        LOGE("eglCreateWindowSurface failed: 0x%x", eglGetError());
        return false;
    }

    if (!eglMakeCurrent(ctx->display, ctx->surface, ctx->surface,
                         ctx->context)) {
        LOGE("eglMakeCurrent failed: 0x%x", eglGetError());
        return false;
    }
    return true;
}

void teardownEgl(BridgeContext* ctx) {
    if (ctx->display == EGL_NO_DISPLAY) return;
    eglMakeCurrent(ctx->display, EGL_NO_SURFACE, EGL_NO_SURFACE,
                    EGL_NO_CONTEXT);
    if (ctx->surface != EGL_NO_SURFACE) {
        eglDestroySurface(ctx->display, ctx->surface);
    }
    if (ctx->context != EGL_NO_CONTEXT) {
        eglDestroyContext(ctx->display, ctx->context);
    }
    eglTerminate(ctx->display);
    ctx->display = EGL_NO_DISPLAY;
    ctx->surface = EGL_NO_SURFACE;
    ctx->context = EGL_NO_CONTEXT;
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeInit(
        JNIEnv* env, jobject /*thiz*/, jobject surfaceObj,
        jint width, jint height) {

    auto* ctx = new BridgeContext();
    ctx->width = width;
    ctx->height = height;

    ctx->window = ANativeWindow_fromSurface(env, surfaceObj);
    if (!ctx->window) {
        LOGE("ANativeWindow_fromSurface returned null");
        delete ctx;
        return 0;
    }
    ANativeWindow_setBuffersGeometry(ctx->window, width, height,
                                      WINDOW_FORMAT_RGBA_8888);

    if (!setupEgl(ctx)) {
        ANativeWindow_release(ctx->window);
        delete ctx;
        return 0;
    }

    ctx->pm = projectm_create();
    if (!ctx->pm) {
        LOGE("projectm_create failed");
        teardownEgl(ctx);
        ANativeWindow_release(ctx->window);
        delete ctx;
        return 0;
    }
    projectm_set_window_size(ctx->pm, width, height);
    projectm_set_fps(ctx->pm, 60);
    projectm_set_preset_duration(ctx->pm, 30.0);
    projectm_set_mesh_size(ctx->pm, 48, 36);

    LOGI("nativeInit ok: %dx%d ctx=%p pm=%p", width, height, ctx,
         (void*)ctx->pm);
    return reinterpret_cast<jlong>(ctx);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeRenderFrame(
        JNIEnv* /*env*/, jobject /*thiz*/, jlong ctxPtr) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->pm) return;
    // Context should already be current on this thread (set up at
    // init), but re-make-current cheaply guards against any other
    // GL caller stealing it.
    eglMakeCurrent(ctx->display, ctx->surface, ctx->surface, ctx->context);
    projectm_opengl_render_frame(ctx->pm);
    eglSwapBuffers(ctx->display, ctx->surface);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeAddPcm(
        JNIEnv* env, jobject /*thiz*/, jlong ctxPtr,
        jfloatArray samplesArray) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->pm || !samplesArray) return;
    jsize len = env->GetArrayLength(samplesArray);
    if (len <= 0) return;
    jfloat* data = env->GetFloatArrayElements(samplesArray, nullptr);
    if (!data) return;
    // Treat the input as interleaved stereo; count is per-channel frames.
    projectm_pcm_add_float(ctx->pm, data,
                            static_cast<unsigned int>(len / 2),
                            PROJECTM_STEREO);
    env->ReleaseFloatArrayElements(samplesArray, data, JNI_ABORT);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeDispose(
        JNIEnv* /*env*/, jobject /*thiz*/, jlong ctxPtr) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx) return;
    if (ctx->pm) {
        projectm_destroy(ctx->pm);
        ctx->pm = nullptr;
    }
    teardownEgl(ctx);
    if (ctx->window) {
        ANativeWindow_release(ctx->window);
        ctx->window = nullptr;
    }
    delete ctx;
    LOGI("nativeDispose ok");
}

} // extern "C"
