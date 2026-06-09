// JNI bridge for the visualizer. Owns the EGL context + window
// surface; delegates the actual rendering to an Engine instance
// chosen at init time.
//
// Engines:
//   0 → ProjectMEngine (Milkdrop, default)
//   1 → ShaderEngine   (Shadertoy fragment shaders)
//
// All native methods run on the Kotlin RenderThread; the EGL context
// is made current at init and again defensively in each JNI call.
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
#include <cstdlib>
#include <memory>

#include "engine.h"
#include "projectm_engine.h"
#include "shader_engine.h"

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

constexpr jint kEngineProjectM = 0;
constexpr jint kEngineShader   = 1;

struct BridgeContext {
    EGLDisplay display = EGL_NO_DISPLAY;
    EGLContext context = EGL_NO_CONTEXT;
    EGLSurface surface = EGL_NO_SURFACE;
    ANativeWindow* window = nullptr;
    std::unique_ptr<Engine> engine;
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

    // Decouple buffer swap from display vsync. The on-screen render thread
    // already paces itself to ~60fps with Thread.sleep, and the transcode
    // path paces to the audio clock — so the default swap interval of 1
    // (which blocks each swap on vsync) double-throttles. Worse, on a
    // 90/120Hz panel a 60fps sleep target beats against vsync and delivers
    // uneven frames. Interval 0 makes the manual pacing the single clock.
    // Best-effort: a driver may clamp/ignore it, in which case the sleep
    // still caps the rate.
    eglSwapInterval(ctx->display, 0);
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

std::unique_ptr<Engine> makeEngine(jint kind) {
    switch (kind) {
        case kEngineShader:
            return std::make_unique<ShaderEngine>();
        case kEngineProjectM:
        default:
            return std::make_unique<ProjectMEngine>();
    }
}

} // namespace

extern "C" {

JNIEXPORT jlong JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeInit(
        JNIEnv* env, jobject /*thiz*/, jobject surfaceObj,
        jint width, jint height, jint engineKind) {

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

    ctx->engine = makeEngine(engineKind);
    if (!ctx->engine || !ctx->engine->init(width, height)) {
        LOGE("engine init failed (kind=%d)", engineKind);
        ctx->engine.reset();
        teardownEgl(ctx);
        ANativeWindow_release(ctx->window);
        delete ctx;
        return 0;
    }

    LOGI("nativeInit ok: %dx%d ctx=%p engine=%d", width, height, ctx,
         engineKind);
    return reinterpret_cast<jlong>(ctx);
}

// Like nativeInit, but for a MediaCodec encoder's input Surface (visualizer
// cast transcode). The codec dictates the input buffer geometry, so unlike the
// Flutter-texture path we must NOT call ANativeWindow_setBuffersGeometry (it
// fights the encoder). Everything else — EGL context/surface + engine init — is
// identical, and nativeRenderFrameAt / nativeAddPcm / nativeDispose all work on
// the returned ctx unchanged.
JNIEXPORT jlong JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeInitEncoder(
        JNIEnv* env, jobject /*thiz*/, jobject surfaceObj,
        jint width, jint height, jint engineKind) {
    auto* ctx = new BridgeContext();
    ctx->width = width;
    ctx->height = height;
    ctx->window = ANativeWindow_fromSurface(env, surfaceObj);
    if (!ctx->window) {
        LOGE("nativeInitEncoder: ANativeWindow_fromSurface null");
        delete ctx;
        return 0;
    }
    if (!setupEgl(ctx)) {
        ANativeWindow_release(ctx->window);
        delete ctx;
        return 0;
    }
    ctx->engine = makeEngine(engineKind);
    if (!ctx->engine || !ctx->engine->init(width, height)) {
        LOGE("nativeInitEncoder: engine init failed (kind=%d)", engineKind);
        ctx->engine.reset();
        teardownEgl(ctx);
        ANativeWindow_release(ctx->window);
        delete ctx;
        return 0;
    }
    LOGI("nativeInitEncoder ok: %dx%d ctx=%p engine=%d", width, height, ctx,
         engineKind);
    return reinterpret_cast<jlong>(ctx);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeRenderFrame(
        JNIEnv* /*env*/, jobject /*thiz*/, jlong ctxPtr) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->engine) return;
    // The context was made current on this dedicated render thread at
    // nativeInit and nothing else steals it: the shader-compile worker runs
    // on its own thread with its own context, and loadPreset/dispose run on
    // this same thread. So no per-frame eglMakeCurrent is needed — the
    // encoder render path (nativeRenderFrameAt) already relies on this.
    ctx->engine->renderFrame();
    eglSwapBuffers(ctx->display, ctx->surface);
}

// Like nativeRenderFrame, but stamps the frame's presentation time before
// swapping. Used by the visualizer-cast transcode path, where ctx->surface is
// a MediaCodec encoder's input Surface: the encoder timestamps each output
// frame from this value, so video stays in sync with the decoded-audio clock
// that drives ptsNanos. eglPresentationTimeANDROID is an EGL_ANDROID extension,
// resolved lazily on first use.
JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeRenderFrameAt(
        JNIEnv* /*env*/, jobject /*thiz*/, jlong ctxPtr, jlong ptsNanos) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->engine) return;
    // No per-frame eglMakeCurrent here (unlike the on-screen path): the context
    // was made current at nativeInitEncoder and this is a dedicated transcode
    // thread with no other GL caller, so it stays current.
    ctx->engine->renderFrame();
    static PFNEGLPRESENTATIONTIMEANDROIDPROC sPresentationTime =
        reinterpret_cast<PFNEGLPRESENTATIONTIMEANDROIDPROC>(
            eglGetProcAddress("eglPresentationTimeANDROID"));
    if (sPresentationTime != nullptr) {
        sPresentationTime(ctx->display, ctx->surface,
                          static_cast<EGLnsecsANDROID>(ptsNanos));
    }
    eglSwapBuffers(ctx->display, ctx->surface);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeAddPcm(
        JNIEnv* env, jobject /*thiz*/, jlong ctxPtr,
        jfloatArray samplesArray) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->engine || !samplesArray) return;
    jsize len = env->GetArrayLength(samplesArray);
    if (len <= 0) return;
    // Critical (no-copy): addPcm only reads the samples and does no JNI/blocking
    // work, so we can pin the array in place instead of copying ~8 KB ~43×/s.
    auto* data = static_cast<jfloat*>(
        env->GetPrimitiveArrayCritical(samplesArray, nullptr));
    if (!data) return;
    // Interleaved stereo; frameCount is number of L/R pairs.
    ctx->engine->addPcm(data, static_cast<std::size_t>(len / 2));
    env->ReleasePrimitiveArrayCritical(samplesArray, data, JNI_ABORT);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeSetTuning(
        JNIEnv* env, jobject /*thiz*/, jlong ctxPtr,
        jfloatArray valuesArray) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->engine || !valuesArray) return;
    jsize len = env->GetArrayLength(valuesArray);
    if (len <= 0) return;
    jfloat* data = env->GetFloatArrayElements(valuesArray, nullptr);
    if (!data) return;
    // setTuning touches no GL state, so no eglMakeCurrent needed; it runs
    // on the render thread (Kotlin enqueues) so params don't race the
    // renderFrame reads.
    ctx->engine->setTuning(data, static_cast<std::size_t>(len));
    env->ReleaseFloatArrayElements(valuesArray, data, JNI_ABORT);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeLoadPresetData(
        JNIEnv* env, jobject /*thiz*/, jlong ctxPtr,
        jstring presetData, jboolean smoothTransition) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx || !ctx->engine || !presetData) return;
    const char* data = env->GetStringUTFChars(presetData, nullptr);
    if (!data) return;
    eglMakeCurrent(ctx->display, ctx->surface, ctx->surface, ctx->context);
    ctx->engine->loadPreset(data, smoothTransition);
    LOGI("loaded preset (%zu bytes)",
         static_cast<size_t>(env->GetStringUTFLength(presetData)));
    env->ReleaseStringUTFChars(presetData, data);
}

JNIEXPORT void JNICALL
Java_com_example_mstream_1music_VisualizerBridge_nativeDispose(
        JNIEnv* /*env*/, jobject /*thiz*/, jlong ctxPtr) {
    auto* ctx = reinterpret_cast<BridgeContext*>(ctxPtr);
    if (!ctx) return;
    // Engine destructor needs the GL context current to release GL
    // resources cleanly.
    eglMakeCurrent(ctx->display, ctx->surface, ctx->surface, ctx->context);
    ctx->engine.reset();
    teardownEgl(ctx);
    if (ctx->window) {
        ANativeWindow_release(ctx->window);
        ctx->window = nullptr;
    }
    delete ctx;
    LOGI("nativeDispose ok");
}

} // extern "C"
