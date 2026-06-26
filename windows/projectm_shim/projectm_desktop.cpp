// projectm_desktop.cpp — minimal offscreen projectM renderer for the Windows
// desktop build, exposed over a C ABI for dart:ffi.
//
// projectM needs a live OpenGL context. On Android the Kotlin bridge owns an EGL
// context + SurfaceTexture; there's no equivalent on Flutter Windows, so this shim
// owns its OWN context: a hidden window + a Core-profile WGL context + an FBO.
// Each frame it feeds PCM, renders projectM into the FBO, and reads the pixels
// back to an RGBA buffer the Dart side turns into a ui.Image. CPU readback (vs
// GPU texture sharing) keeps it simple and backend-agnostic; fine at the modest
// render size the desktop screen uses.
//
// Single global instance — the visualizer is a single full-screen view.

#include <windows.h>
#include <GL/glew.h>
#include <GL/wglew.h>

#include <projectM-4/projectM.h>
#include <projectM-4/audio.h>
#include <projectM-4/render_opengl.h>

#include <string>

#define PMD_EXPORT extern "C" __declspec(dllexport)

namespace {
HWND g_hwnd = nullptr;
HDC g_hdc = nullptr;
HGLRC g_glrc = nullptr;
projectm_handle g_pm = nullptr;
GLuint g_fbo = 0, g_tex = 0, g_rbo = 0;
int g_w = 0, g_h = 0;
std::string g_err;

void set_err(const char* m) { g_err = m ? m : ""; }

bool create_context() {
  WNDCLASSA wc = {};
  wc.lpfnWndProc = DefWindowProcA;
  wc.hInstance = GetModuleHandleA(nullptr);
  wc.lpszClassName = "mstream_pmd_hidden";
  RegisterClassA(&wc);
  g_hwnd = CreateWindowA(wc.lpszClassName, "pmd", WS_OVERLAPPEDWINDOW, 0, 0, 16,
                         16, nullptr, nullptr, wc.hInstance, nullptr);
  if (!g_hwnd) { set_err("CreateWindow failed"); return false; }
  g_hdc = GetDC(g_hwnd);

  PIXELFORMATDESCRIPTOR pfd = {};
  pfd.nSize = sizeof(pfd);
  pfd.nVersion = 1;
  pfd.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
  pfd.iPixelType = PFD_TYPE_RGBA;
  pfd.cColorBits = 32;
  pfd.cDepthBits = 24;
  pfd.cStencilBits = 8;
  int pf = ChoosePixelFormat(g_hdc, &pfd);
  if (!pf || !SetPixelFormat(g_hdc, pf, &pfd)) {
    set_err("pixel format selection failed");
    return false;
  }

  // Bootstrap context so GLEW (incl. WGL extensions) can load.
  HGLRC tmp = wglCreateContext(g_hdc);
  if (!tmp) { set_err("wglCreateContext failed"); return false; }
  wglMakeCurrent(g_hdc, tmp);

  glewExperimental = GL_TRUE;
  if (glewInit() != GLEW_OK) { set_err("glewInit failed"); return false; }

  // Upgrade to a 3.3 Core-profile context if available (projectM was built for
  // the Core profile); otherwise keep the bootstrap context.
  if (wglewIsSupported("WGL_ARB_create_context") &&
      wglewIsSupported("WGL_ARB_create_context_profile")) {
    const int attribs[] = {
        WGL_CONTEXT_MAJOR_VERSION_ARB, 3, WGL_CONTEXT_MINOR_VERSION_ARB, 3,
        WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB, 0};
    HGLRC core = wglCreateContextAttribsARB(g_hdc, nullptr, attribs);
    if (core) {
      wglMakeCurrent(g_hdc, core);
      wglDeleteContext(tmp);
      g_glrc = core;
    } else {
      g_glrc = tmp;
    }
  } else {
    g_glrc = tmp;
  }
  return true;
}

bool create_fbo(int w, int h) {
  glGenFramebuffers(1, &g_fbo);
  glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
  glGenTextures(1, &g_tex);
  glBindTexture(GL_TEXTURE_2D, g_tex);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE,
               nullptr);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                         g_tex, 0);
  glGenRenderbuffers(1, &g_rbo);
  glBindRenderbuffer(GL_RENDERBUFFER, g_rbo);
  glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, w, h);
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT,
                            GL_RENDERBUFFER, g_rbo);
  return glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE;
}
}  // namespace

/// Create the GL context + projectM at [w]x[h]. 0 on success, negative on error
/// (then call pmd_last_error). Idempotent.
PMD_EXPORT int pmd_init(int w, int h) {
  if (g_pm) return 0;
  if (!create_context()) return -1;
  if (!create_fbo(w, h)) { set_err("framebuffer incomplete"); return -2; }
  g_pm = projectm_create();
  if (!g_pm) { set_err("projectm_create failed"); return -3; }
  projectm_set_window_size(g_pm, (size_t)w, (size_t)h);
  projectm_set_mesh_size(g_pm, 48, 32);
  projectm_set_fps(g_pm, 60);
  projectm_set_preset_duration(g_pm, 20.0);
  g_w = w;
  g_h = h;
  return 0;
}

/// Feed [count] mono float PCM samples (range ~[-1,1]).
PMD_EXPORT void pmd_add_pcm(const float* samples, int count) {
  if (g_pm && samples && count > 0) {
    projectm_pcm_add_float(g_pm, samples, (unsigned int)count, PROJECTM_MONO);
  }
}

/// Render one frame and read it back into [out_rgba] (w*h*4 bytes, GL bottom-up
/// row order — the Dart side flips for display). 0 on success.
PMD_EXPORT int pmd_render(unsigned char* out_rgba) {
  if (!g_pm || !out_rgba) return -1;
  wglMakeCurrent(g_hdc, g_glrc);
  glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
  glViewport(0, 0, g_w, g_h);
  projectm_opengl_render_frame(g_pm);
  glPixelStorei(GL_PACK_ALIGNMENT, 1);
  glReadPixels(0, 0, g_w, g_h, GL_RGBA, GL_UNSIGNED_BYTE, out_rgba);
  return 0;
}

/// Load a preset from in-memory `.milk` text (avoids needing a real file path for
/// bundled Flutter assets). [smooth] enables the soft-cut transition.
PMD_EXPORT void pmd_load_preset_data(const char* data, int smooth) {
  if (g_pm && data) projectm_load_preset_data(g_pm, data, smooth != 0);
}

PMD_EXPORT void pmd_destroy() {
  if (g_pm) {
    projectm_destroy(g_pm);
    g_pm = nullptr;
  }
  if (g_glrc) {
    wglMakeCurrent(nullptr, nullptr);
    wglDeleteContext(g_glrc);
    g_glrc = nullptr;
  }
  if (g_hwnd && g_hdc) ReleaseDC(g_hwnd, g_hdc);
  if (g_hwnd) {
    DestroyWindow(g_hwnd);
    g_hwnd = nullptr;
  }
}

PMD_EXPORT const char* pmd_last_error() { return g_err.c_str(); }
