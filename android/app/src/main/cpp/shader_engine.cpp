#include "shader_engine.h"

#include <android/log.h>
#include <cstring>
#include <regex>
#include <sstream>
#include <utility>

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

// Fullscreen-triangle vertex shader. One triangle covers the entire
// NDC viewport — saves us an index buffer compared to a quad.
const char* kVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
}
)";

// Prelude prepended to every user fragment shader. Provides the
// Shadertoy uniforms and the main() entry that delegates to the
// user's mainImage().
const char* kFragPrelude = R"(#version 300 es
precision highp float;
precision highp int;

uniform float iTime;
uniform float iTimeDelta;
uniform int   iFrame;
uniform vec3  iResolution;
uniform vec4  iMouse;
uniform sampler2D iChannel0;
uniform sampler2D iChannel1;
uniform sampler2D iChannel2;
uniform sampler2D iChannel3;
uniform float iChannelTime[4];
uniform vec3  iChannelResolution[4];
uniform vec4  iDate;
uniform float iSampleRate;
// mstream tuning knobs, pushed from the in-app panel. Size must match
// ShaderEngine::NUM_PARAMS. Shaders read iParams[i] where they'd otherwise
// hardcode a constant; defaults are supplied by the UI on load.
uniform float iParams[8];

out vec4 outColor;

void mainImage(out vec4 fragColor, in vec2 fragCoord);

void main() {
    vec4 col = vec4(0.0);
    mainImage(col, gl_FragCoord.xy);
    outColor = col;
}

// === user shader follows ===
)";

const char* kPresentVertexShader = R"(#version 300 es
precision highp float;
layout(location = 0) in vec2 aPos;
out vec2 vUv;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    vUv = (aPos + 1.0) * 0.5;
}
)";

const char* kPresentFragmentShader = R"(#version 300 es
precision highp float;
in  vec2 vUv;
out vec4 outColor;
uniform sampler2D uCurrent;
uniform sampler2D uOld;
uniform float uMixT;
void main() {
    vec4 cur = texture(uCurrent, vUv);
    if (uMixT >= 1.0) { outColor = cur; return; }
    vec4 old = texture(uOld, vUv);
    outColor = mix(old, cur, uMixT);
}
)";

GLuint compileShader(GLenum kind, const char* src) {
    GLuint s = glCreateShader(kind);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint status = GL_FALSE;
    glGetShaderiv(s, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        GLint logLen = 0;
        glGetShaderiv(s, GL_INFO_LOG_LENGTH, &logLen);
        std::string log(static_cast<std::size_t>(logLen) + 1, '\0');
        glGetShaderInfoLog(s, logLen, nullptr, log.data());
        LOGE("shader compile error (%s):\n%s",
             kind == GL_VERTEX_SHADER ? "vert" : "frag", log.c_str());
        glDeleteShader(s);
        return 0;
    }
    return s;
}

GLuint linkProgram(GLuint vs, GLuint fs) {
    GLuint p = glCreateProgram();
    glAttachShader(p, vs);
    glAttachShader(p, fs);
    glLinkProgram(p);
    GLint linked = GL_FALSE;
    glGetProgramiv(p, GL_LINK_STATUS, &linked);
    if (linked != GL_TRUE) {
        GLint logLen = 0;
        glGetProgramiv(p, GL_INFO_LOG_LENGTH, &logLen);
        std::string log(static_cast<std::size_t>(logLen) + 1, '\0');
        glGetProgramInfoLog(p, logLen, nullptr, log.data());
        LOGE("program link error:\n%s", log.c_str());
        glDeleteProgram(p);
        return 0;
    }
    return p;
}

bool createColorFbo(int w, int h, GLuint* fbo, GLuint* tex) {
    glGenTextures(1, tex);
    glBindTexture(GL_TEXTURE_2D, *tex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, w, h, 0, GL_RGBA,
                  GL_UNSIGNED_BYTE, nullptr);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    glGenFramebuffers(1, fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, *fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                            GL_TEXTURE_2D, *tex, 0);
    const GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        LOGE("FBO incomplete: 0x%x", status);
        glDeleteFramebuffers(1, fbo);
        glDeleteTextures(1, tex);
        *fbo = 0; *tex = 0;
        return false;
    }
    return true;
}

// === Multi-pass source parsing ===
//
// Recognizes lines of two forms (anywhere before the first pass body):
//
//   // === channel <target>.<index> = <source>
//   // === pass: <name> ===
//
// Anything after a pass-marker line belongs to that pass until the next
// pass-marker line or end of file. Single-pass files (no pass markers
// at all) are treated as if the entire source belongs to one image pass.

struct ParsedShader {
    std::string commonCode;
    std::string passCode[ShaderEngine::PASS_COUNT];
    bool hasPass[ShaderEngine::PASS_COUNT] = {false, false, false, false, false};
    bool hasCommon = false;
    // [passIdx][channel] = ChannelSource enum int
    int channelSrc[ShaderEngine::PASS_COUNT][4] = {{0}};
    // Requested render size per pass; 0 = full window resolution.
    int passW[ShaderEngine::PASS_COUNT] = {0};
    int passH[ShaderEngine::PASS_COUNT] = {0};
};

int passIndexFromName(const std::string& nameLower) {
    if (nameLower == "image")    return ShaderEngine::PASS_IMAGE;
    if (nameLower == "buffera")  return ShaderEngine::PASS_BUFFER_A;
    if (nameLower == "bufferb")  return ShaderEngine::PASS_BUFFER_B;
    if (nameLower == "bufferc")  return ShaderEngine::PASS_BUFFER_C;
    if (nameLower == "bufferd")  return ShaderEngine::PASS_BUFFER_D;
    return -1; // common handled separately
}

int channelSourceFromString(const std::string& s) {
    if (s == "audio" || s == "music" || s == "musicstream" || s == "mic")
        return 1; // CHAN_AUDIO
    if (s == "buffera") return 2;
    if (s == "bufferb") return 3;
    if (s == "bufferc") return 4;
    if (s == "bufferd") return 5;
    return 0; // CHAN_NONE
}

std::string lowerAlnum(const std::string& s) {
    std::string out;
    out.reserve(s.size());
    for (char c : s) {
        if (c >= 'A' && c <= 'Z') out.push_back(c - 'A' + 'a');
        else if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) out.push_back(c);
        // strip whitespace, punctuation
    }
    return out;
}

ParsedShader parseShader(const std::string& source) {
    ParsedShader out;

    // Quick check: does the source contain `// === pass:` anywhere?
    if (source.find("=== pass:") == std::string::npos) {
        // Single-pass — treat whole source as the image pass with
        // iChannel0 wired to audio (preserves backward compatibility
        // with our existing single-file shaders).
        out.hasPass[ShaderEngine::PASS_IMAGE] = true;
        out.passCode[ShaderEngine::PASS_IMAGE] = source;
        out.channelSrc[ShaderEngine::PASS_IMAGE][0] = 1; // CHAN_AUDIO
        return out;
    }

    // Multi-pass parse: iterate lines, splitting on pass markers.
    std::istringstream stream(source);
    std::string line;
    std::string headerBuf;
    int curPass = -1;       // -1 = pre-marker zone (or common), -2 = common pass body
    std::string curBody;

    auto flushCurPass = [&]() {
        if (curPass == -2) {
            out.commonCode = curBody;
            out.hasCommon = true;
        } else if (curPass >= 0) {
            out.passCode[curPass] = curBody;
            out.hasPass[curPass] = true;
        }
        curBody.clear();
    };

    // We also want to capture channel routing lines anywhere before
    // the first pass marker (those land in the headerBuf via the
    // initial loop iteration when curPass is -1 and we're not yet in
    // a pass body).
    std::regex passMarker(R"(^\s*//\s*===\s*pass\s*:\s*([a-zA-Z]+)\s*===)");
    std::regex channelMarker(
        R"(^\s*//\s*===\s*channel\s+([a-zA-Z]+)\s*\.\s*(\d+)\s*=\s*([a-zA-Z]+))");
    // Optional per-pass render size: `// === size bufferc = 1x1`. Lets a
    // pass that writes a single constant value render at e.g. 1x1 instead
    // of a full-screen pass. Honored for buffer passes only.
    std::regex sizeMarker(
        R"(^\s*//\s*===\s*size\s+([a-zA-Z]+)\s*=\s*(\d+)\s*[xX]\s*(\d+))");

    while (std::getline(stream, line)) {
        std::smatch m;
        if (std::regex_search(line, m, passMarker)) {
            // flush whatever we were collecting
            flushCurPass();
            std::string name = lowerAlnum(m[1].str());
            if (name == "common") {
                curPass = -2;
            } else {
                int idx = passIndexFromName(name);
                curPass = (idx >= 0) ? idx : -3;  // -3 = unknown, will be discarded
                if (idx < 0) LOGE("unknown pass name in source: %s", m[1].str().c_str());
            }
            continue;
        }
        if (curPass == -1) {
            // Pre-marker zone: look for routing + size lines
            std::smatch cm;
            if (std::regex_search(line, cm, channelMarker)) {
                std::string target = lowerAlnum(cm[1].str());
                int ch = std::stoi(cm[2].str());
                std::string srcName = lowerAlnum(cm[3].str());
                int tgtIdx = passIndexFromName(target);
                int srcEnum = channelSourceFromString(srcName);
                if (tgtIdx >= 0 && ch >= 0 && ch < 4) {
                    out.channelSrc[tgtIdx][ch] = srcEnum;
                }
            } else if (std::regex_search(line, cm, sizeMarker)) {
                int tgtIdx = passIndexFromName(lowerAlnum(cm[1].str()));
                // Imported shaders are user-supplied, so parse defensively:
                // std::stoi throws on an overlong digit run (which would crash
                // the compile-worker thread), and an unbounded size would
                // allocate a huge ping-pong pair. Clamp to a sane max; anything
                // unparseable leaves the pass at its full-window default.
                int w = 0, h = 0;
                try {
                    constexpr long kMaxPassDim = 8192;
                    long pw = std::stol(cm[2].str()), ph = std::stol(cm[3].str());
                    w = static_cast<int>(pw < 1 ? 0 : (pw > kMaxPassDim ? kMaxPassDim : pw));
                    h = static_cast<int>(ph < 1 ? 0 : (ph > kMaxPassDim ? kMaxPassDim : ph));
                } catch (...) {
                    w = h = 0;  // overflow / out of range → treat as unset
                }
                if (tgtIdx >= 0 && w > 0 && h > 0) {
                    out.passW[tgtIdx] = w;
                    out.passH[tgtIdx] = h;
                }
            }
            // Other pre-marker lines are ignored (comments, etc.)
            continue;
        }
        // Accumulate into current pass body
        curBody.append(line);
        curBody.push_back('\n');
    }
    flushCurPass();

    return out;
}

} // namespace

ShaderEngine::~ShaderEngine() {
    workerShutdown_ = true;
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        queueCv_.notify_all();
    }
    if (worker_.joinable()) worker_.join();
    teardownSharedContext();

    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingResult_) { freePassSet(pendingResult_); pendingResult_ = nullptr; }
    }

    clearCurrentSet();
    releaseAllBufferTargets();
    teardownOffscreenTargets();

    if (blackTex_) glDeleteTextures(1, &blackTex_);
    if (presentProgram_) glDeleteProgram(presentProgram_);
    if (vao_) glDeleteVertexArrays(1, &vao_);
    if (vbo_) glDeleteBuffers(1, &vbo_);
    audio_.dispose();
}

void ShaderEngine::clearCurrentSet() {
    if (!currentSet_) return;
    for (int i = 0; i < PASS_COUNT; ++i) {
        if (currentSet_->hasPass[i] && currentSet_->passes[i].program) {
            glDeleteProgram(currentSet_->passes[i].program);
        }
    }
    delete currentSet_;
    currentSet_ = nullptr;
}

void ShaderEngine::freePassSet(PassSet* set) {
    if (!set) return;
    for (int i = 0; i < PASS_COUNT; ++i) {
        if (set->hasPass[i] && set->passes[i].program) {
            glDeleteProgram(set->passes[i].program);
        }
    }
    delete set;
}

bool ShaderEngine::init(int width, int height) {
    width_ = width;
    height_ = height;
    startTime_ = std::chrono::steady_clock::now();
    lastFrameTime_ = startTime_;
    transitionStart_ = startTime_;
    frameCount_ = 0;

    const float verts[] = {-1.0f,-1.0f, 3.0f,-1.0f, -1.0f,3.0f};
    glGenVertexArrays(1, &vao_);
    glGenBuffers(1, &vbo_);
    glBindVertexArray(vao_);
    glBindBuffer(GL_ARRAY_BUFFER, vbo_);
    glBufferData(GL_ARRAY_BUFFER, sizeof(verts), verts, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, nullptr);
    glBindVertexArray(0);

    if (!audio_.init()) { LOGE("audio texture init failed"); return false; }
    if (!setupOffscreenTargets()) { LOGE("offscreen setup failed"); return false; }

    // 1×1 black fallback for unbound iChannels.
    {
        const uint8_t black[4] = {0, 0, 0, 255};
        glGenTextures(1, &blackTex_);
        glBindTexture(GL_TEXTURE_2D, blackTex_);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA,
                      GL_UNSIGNED_BYTE, black);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        glBindTexture(GL_TEXTURE_2D, 0);
    }

    // Present program.
    {
        GLuint vs = compileShader(GL_VERTEX_SHADER, kPresentVertexShader);
        GLuint fs = compileShader(GL_FRAGMENT_SHADER, kPresentFragmentShader);
        if (!vs || !fs) {
            if (vs) glDeleteShader(vs);
            if (fs) glDeleteShader(fs);
            return false;
        }
        presentProgram_ = linkProgram(vs, fs);
        glDeleteShader(vs); glDeleteShader(fs);
        if (!presentProgram_) return false;
        locPresentCurrent_ = glGetUniformLocation(presentProgram_, "uCurrent");
        locPresentOld_     = glGetUniformLocation(presentProgram_, "uOld");
        locPresentMixT_    = glGetUniformLocation(presentProgram_, "uMixT");
    }

    if (!setupSharedContext()) {
        LOGE("shared EGL setup failed — sync fallback active");
    } else {
        worker_ = std::thread(&ShaderEngine::workerLoop, this);
    }

    LOGI("ShaderEngine init ok %dx%d", width, height);
    return true;
}

bool ShaderEngine::setupOffscreenTargets() {
    if (!createColorFbo(width_, height_, &fboCurrent_, &texCurrent_)) return false;
    if (!createColorFbo(width_, height_, &fboOld_, &texOld_)) {
        glDeleteFramebuffers(1, &fboCurrent_);
        glDeleteTextures(1, &texCurrent_);
        fboCurrent_ = 0; texCurrent_ = 0;
        return false;
    }
    glBindFramebuffer(GL_FRAMEBUFFER, fboCurrent_);
    glClearColor(0,0,0,1); glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, fboOld_);
    glClear(GL_COLOR_BUFFER_BIT);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    return true;
}

void ShaderEngine::teardownOffscreenTargets() {
    if (fboCurrent_) { glDeleteFramebuffers(1, &fboCurrent_); fboCurrent_ = 0; }
    if (texCurrent_) { glDeleteTextures(1, &texCurrent_); texCurrent_ = 0; }
    if (fboOld_)     { glDeleteFramebuffers(1, &fboOld_); fboOld_ = 0; }
    if (texOld_)     { glDeleteTextures(1, &texOld_); texOld_ = 0; }
}

bool ShaderEngine::ensureBufferTarget(int idx) {
    BufferTarget& bt = bufferTargets_[idx];

    // Render size for this buffer: the pass's declared size (e.g. a 1x1
    // audio-analysis buffer), or full window resolution by default.
    int rw = width_, rh = height_;
    if (currentSet_ && currentSet_->hasPass[idx]) {
        const Pass& p = currentSet_->passes[idx];
        if (p.renderW > 0 && p.renderH > 0) { rw = p.renderW; rh = p.renderH; }
    }

    if (bt.allocated) {
        if (bt.w == rw && bt.h == rh) return true;
        // A preset swap re-requested this slot at a different size; free
        // the old textures and reallocate to match.
        releaseBufferTarget(idx);
    }

    for (int p = 0; p < 2; ++p) {
        if (!createColorFbo(rw, rh, &bt.fbo[p], &bt.tex[p])) {
            // free anything created
            for (int q = 0; q < p; ++q) {
                glDeleteFramebuffers(1, &bt.fbo[q]);
                glDeleteTextures(1, &bt.tex[q]);
                bt.fbo[q] = 0; bt.tex[q] = 0;
            }
            return false;
        }
        // Clear to black so first frame doesn't sample undefined memory.
        glBindFramebuffer(GL_FRAMEBUFFER, bt.fbo[p]);
        glClearColor(0,0,0,1); glClear(GL_COLOR_BUFFER_BIT);
    }
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    bt.writeIdx = 0;
    bt.w = rw; bt.h = rh;
    bt.allocated = true;
    return true;
}

void ShaderEngine::releaseBufferTarget(int idx) {
    BufferTarget& bt = bufferTargets_[idx];
    if (!bt.allocated) return;
    for (int p = 0; p < 2; ++p) {
        if (bt.fbo[p]) glDeleteFramebuffers(1, &bt.fbo[p]);
        if (bt.tex[p]) glDeleteTextures(1, &bt.tex[p]);
        bt.fbo[p] = 0; bt.tex[p] = 0;
    }
    bt.allocated = false;
    bt.writeIdx = 0;
    bt.w = 0; bt.h = 0;
}

void ShaderEngine::releaseAllBufferTargets() {
    for (int i = 0; i < 4; ++i) releaseBufferTarget(i);
}

bool ShaderEngine::setupSharedContext() {
    EGLDisplay display = eglGetCurrentDisplay();
    EGLContext mainCtx = eglGetCurrentContext();
    if (display == EGL_NO_DISPLAY || mainCtx == EGL_NO_CONTEXT) {
        LOGE("no current EGL — cannot share");
        return false;
    }
    const EGLint cfgAttrs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE,    EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8, EGL_GREEN_SIZE, 8, EGL_BLUE_SIZE, 8, EGL_ALPHA_SIZE, 8,
        EGL_NONE,
    };
    EGLConfig cfg;
    EGLint n = 0;
    if (!eglChooseConfig(display, cfgAttrs, &cfg, 1, &n) || n < 1) {
        LOGE("worker eglChooseConfig failed");
        return false;
    }
    const EGLint pbAttrs[] = { EGL_WIDTH, 1, EGL_HEIGHT, 1, EGL_NONE };
    workerSurface_ = eglCreatePbufferSurface(display, cfg, pbAttrs);
    if (workerSurface_ == EGL_NO_SURFACE) return false;
    const EGLint ctxAttrs[] = { EGL_CONTEXT_CLIENT_VERSION, 3, EGL_NONE };
    workerCtx_ = eglCreateContext(display, cfg, mainCtx, ctxAttrs);
    if (workerCtx_ == EGL_NO_CONTEXT) {
        eglDestroySurface(display, workerSurface_);
        workerSurface_ = EGL_NO_SURFACE;
        return false;
    }
    workerDisplay_ = display;
    return true;
}

void ShaderEngine::teardownSharedContext() {
    if (workerDisplay_ == EGL_NO_DISPLAY) return;
    if (workerCtx_ != EGL_NO_CONTEXT) eglDestroyContext(workerDisplay_, workerCtx_);
    if (workerSurface_ != EGL_NO_SURFACE) eglDestroySurface(workerDisplay_, workerSurface_);
    workerCtx_ = EGL_NO_CONTEXT;
    workerSurface_ = EGL_NO_SURFACE;
    workerDisplay_ = EGL_NO_DISPLAY;
}

ShaderEngine::UniformLocs ShaderEngine::queryUniformLocations(GLuint program) {
    UniformLocs u;
    u.time              = glGetUniformLocation(program, "iTime");
    u.timeDelta         = glGetUniformLocation(program, "iTimeDelta");
    u.frame             = glGetUniformLocation(program, "iFrame");
    u.resolution        = glGetUniformLocation(program, "iResolution");
    u.mouse             = glGetUniformLocation(program, "iMouse");
    u.channel[0]        = glGetUniformLocation(program, "iChannel0");
    u.channel[1]        = glGetUniformLocation(program, "iChannel1");
    u.channel[2]        = glGetUniformLocation(program, "iChannel2");
    u.channel[3]        = glGetUniformLocation(program, "iChannel3");
    u.channelTime       = glGetUniformLocation(program, "iChannelTime[0]");
    u.channelResolution = glGetUniformLocation(program, "iChannelResolution[0]");
    u.date              = glGetUniformLocation(program, "iDate");
    u.sampleRate        = glGetUniformLocation(program, "iSampleRate");
    u.params            = glGetUniformLocation(program, "iParams[0]");
    return u;
}

GLuint ShaderEngine::compileSingleProgram(const std::string& fragSource) {
    GLuint vs = compileShader(GL_VERTEX_SHADER, kVertexShader);
    if (!vs) return 0;
    std::string full(kFragPrelude);
    full.append(fragSource);
    GLuint fs = compileShader(GL_FRAGMENT_SHADER, full.c_str());
    if (!fs) { glDeleteShader(vs); return 0; }
    GLuint p = linkProgram(vs, fs);
    glDeleteShader(vs); glDeleteShader(fs);
    return p;
}

ShaderEngine::PassSet* ShaderEngine::compilePassSet(const std::string& source) {
    ParsedShader parsed = parseShader(source);
    auto* set = new PassSet();
    int totalCompiled = 0;
    for (int i = 0; i < PASS_COUNT; ++i) {
        if (!parsed.hasPass[i]) continue;
        std::string passSrc;
        if (parsed.hasCommon) passSrc = parsed.commonCode + "\n";
        passSrc += parsed.passCode[i];
        GLuint prog = compileSingleProgram(passSrc);
        if (!prog) {
            LOGE("pass %d compile failed", i);
            // Free everything and bail
            freePassSet(set);
            return nullptr;
        }
        Pass& pp = set->passes[i];
        pp.program = prog;
        pp.locs = queryUniformLocations(prog);
        for (int c = 0; c < 4; ++c) {
            pp.channelSrc[c] = static_cast<ChannelSource>(parsed.channelSrc[i][c]);
        }
        // Image always renders full res (the present pass samples it 1:1);
        // only buffer passes honor a declared size.
        if (i != PASS_IMAGE) {
            pp.renderW = parsed.passW[i];
            pp.renderH = parsed.passH[i];
        }
        set->hasPass[i] = true;
        ++totalCompiled;
    }
    if (totalCompiled == 0 || !set->hasPass[PASS_IMAGE]) {
        LOGE("PassSet has no image pass — refusing to install");
        freePassSet(set);
        return nullptr;
    }
    LOGI("PassSet compiled: %d passes", totalCompiled);
    return set;
}

void ShaderEngine::workerLoop() {
    if (!eglMakeCurrent(workerDisplay_, workerSurface_, workerSurface_, workerCtx_)) {
        LOGE("worker eglMakeCurrent failed");
        return;
    }
    LOGI("shader compile worker ready (multipass)");
    while (true) {
        std::string source;
        {
            std::unique_lock<std::mutex> lock(queueMutex_);
            queueCv_.wait(lock, [this] { return workerShutdown_.load() || hasPendingSource_; });
            if (workerShutdown_.load()) break;
            source = std::move(pendingSource_);
            hasPendingSource_ = false;
        }
        PassSet* set = compilePassSet(source);
        if (!set) continue;
        glFlush();
        PassSet* orphan = nullptr;
        {
            std::lock_guard<std::mutex> lock(resultMutex_);
            orphan = pendingResult_;
            pendingResult_ = set;
        }
        if (orphan) freePassSet(orphan);
    }
    eglMakeCurrent(workerDisplay_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    LOGI("shader compile worker exited");
}

void ShaderEngine::adoptPendingPassSetIfAny() {
    PassSet* adopt = nullptr;
    {
        std::lock_guard<std::mutex> lock(resultMutex_);
        if (pendingResult_) {
            adopt = pendingResult_;
            pendingResult_ = nullptr;
        }
    }
    if (!adopt) return;

    // Snapshot current frame for crossfade BEFORE we swap shaders.
    if (currentSet_ && fboCurrent_ && fboOld_) {
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fboCurrent_);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fboOld_);
        glBlitFramebuffer(0,0,width_,height_, 0,0,width_,height_,
                           GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
    }

    // Release the previous PassSet (programs are GL-shared so this is safe).
    clearCurrentSet();
    currentSet_ = adopt;

    // Pre-allocate the buffer targets this PassSet needs. Lazy-alloc
    // would also work but we do it now so the first frame doesn't
    // pay the cost.
    for (int i = 0; i < 4; ++i) {
        if (currentSet_->hasPass[i]) ensureBufferTarget(i);
    }

    // Push the per-program constant uniforms once, now, instead of every frame.
    primeConstantUniforms(currentSet_);

    transitionStart_ = std::chrono::steady_clock::now();
    transitioning_ = (fboOld_ != 0);

    int n = 0;
    for (int i = 0; i < PASS_COUNT; ++i) if (currentSet_->hasPass[i]) ++n;
    LOGI("adopted PassSet (%d passes)", n);
}

GLuint ShaderEngine::channelTextureFor(ChannelSource src, int currentPassIdx,
                                         GLuint audioTex) const {
    switch (src) {
        case CHAN_AUDIO: return audioTex;
        case CHAN_BUFFER_A:
        case CHAN_BUFFER_B:
        case CHAN_BUFFER_C:
        case CHAN_BUFFER_D: {
            const int bufIdx = static_cast<int>(src) - static_cast<int>(CHAN_BUFFER_A);
            const BufferTarget& bt = bufferTargets_[bufIdx];
            if (!bt.allocated) return blackTex_;
            // Read from the slot we WON'T be writing this frame. If
            // we're sampling our own buffer (self-feedback), that's
            // the previous frame's contents. If we're sampling another
            // buffer that runs before us in render order, it's that
            // buffer's just-written texture.
            if (currentPassIdx == bufIdx) {
                // self-feedback: read the side that's currently the
                // "previous" frame (not the current write slot).
                return bt.tex[bt.writeIdx ^ 1];
            } else {
                // Reading another buffer: it was just written this
                // frame to its current write slot, so read from it.
                return bt.tex[bt.writeIdx];
            }
        }
        case CHAN_NONE:
        default:
            return blackTex_;
    }
}

void ShaderEngine::renderPass(int idx, const Pass& p, GLuint targetFbo,
                                int targetW, int targetH,
                                float elapsed, float delta, GLuint audioTex) {
    glBindFramebuffer(GL_FRAMEBUFFER, targetFbo);
    glViewport(0, 0, targetW, targetH);
    glUseProgram(p.program);

    // Per-frame uniforms only. iMouse, iDate, iSampleRate, iChannelResolution,
    // the iChannel sampler-unit bindings, and iParams are constant for the
    // program's lifetime (or change only on setTuning) and are uploaded once
    // in primeConstantUniforms()/applyParamsToCurrentSet().
    if (p.locs.time       >= 0) glUniform1f(p.locs.time, elapsed);
    if (p.locs.timeDelta  >= 0) glUniform1f(p.locs.timeDelta, delta);
    if (p.locs.frame      >= 0) glUniform1i(p.locs.frame, frameCount_);
    if (p.locs.resolution >= 0) glUniform3f(p.locs.resolution,
        static_cast<float>(targetW),
        static_cast<float>(targetH),
        static_cast<float>(targetW) / static_cast<float>(targetH));
    if (p.locs.channelTime >= 0) {
        const float t[4] = {elapsed,elapsed,elapsed,elapsed};
        glUniform1fv(p.locs.channelTime, 4, t);
    }

    // Bind iChannel0..3 textures. The sampler→unit mapping (sampler = unit c)
    // was set once at prime time, so we only rebind the texture each frame
    // (it changes as buffers ping-pong).
    for (int c = 0; c < 4; ++c) {
        if (p.locs.channel[c] < 0) continue;
        GLuint tex;
        if (p.channelSrc[c] == CHAN_AUDIO) {
            tex = audioTex;
        } else {
            tex = channelTextureFor(p.channelSrc[c], idx, audioTex);
        }
        glActiveTexture(GL_TEXTURE0 + c);
        glBindTexture(GL_TEXTURE_2D, tex);
    }

    glBindVertexArray(vao_);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glBindVertexArray(0);
}

void ShaderEngine::primeConstantUniforms(PassSet* set) {
    if (!set) return;
    // All four input channels report the engine's render size, matching the
    // previous per-frame behavior. (Constant-size analysis buffers don't read
    // iChannelResolution, so the approximation is harmless.)
    const float chRes[12] = {
        static_cast<float>(width_), static_cast<float>(height_), 1,
        static_cast<float>(width_), static_cast<float>(height_), 1,
        static_cast<float>(width_), static_cast<float>(height_), 1,
        static_cast<float>(width_), static_cast<float>(height_), 1,
    };
    for (int i = 0; i < PASS_COUNT; ++i) {
        if (!set->hasPass[i]) continue;
        const Pass& p = set->passes[i];
        glUseProgram(p.program);
        if (p.locs.sampleRate >= 0) glUniform1f(p.locs.sampleRate, 44100.0f);
        if (p.locs.mouse >= 0) glUniform4f(p.locs.mouse, 0, 0, 0, 0);
        if (p.locs.date  >= 0) glUniform4f(p.locs.date, 0, 0, 0, 0);
        if (p.locs.channelResolution >= 0)
            glUniform3fv(p.locs.channelResolution, 4, chRes);
        for (int c = 0; c < 4; ++c) {
            if (p.locs.channel[c] >= 0) glUniform1i(p.locs.channel[c], c);
        }
        if (p.locs.params >= 0) glUniform1fv(p.locs.params, NUM_PARAMS, params_);
    }
    paramsDirty_ = false;
}

void ShaderEngine::applyParamsToCurrentSet() {
    if (!currentSet_) return;
    for (int i = 0; i < PASS_COUNT; ++i) {
        if (!currentSet_->hasPass[i]) continue;
        const Pass& p = currentSet_->passes[i];
        if (p.locs.params < 0) continue;
        glUseProgram(p.program);
        glUniform1fv(p.locs.params, NUM_PARAMS, params_);
    }
}

void ShaderEngine::renderFrame() {
    adoptPendingPassSetIfAny();

    auto now = std::chrono::steady_clock::now();
    const float elapsed = std::chrono::duration<float>(now - startTime_).count();
    const float delta   = std::chrono::duration<float>(now - lastFrameTime_).count();
    lastFrameTime_ = now;

    if (!currentSet_) {
        // Nothing loaded — keep fboCurrent_ as black, run present anyway.
        glBindFramebuffer(GL_FRAMEBUFFER, fboCurrent_);
        glClearColor(0,0,0,1); glClear(GL_COLOR_BUFFER_BIT);
    } else {
        // Tuning changed since last frame? Re-push iParams to the programs
        // once, here, rather than re-uploading it in every renderPass.
        if (paramsDirty_) {
            applyParamsToCurrentSet();
            paramsDirty_ = false;
        }

        const GLuint audioTex = audio_.upload();

        // Render every buffer pass that exists, in fixed order A..D.
        for (int i = 0; i < 4; ++i) {
            if (!currentSet_->hasPass[i]) continue;
            BufferTarget& bt = bufferTargets_[i];
            if (!bt.allocated) continue;
            renderPass(i, currentSet_->passes[i], bt.fbo[bt.writeIdx],
                       bt.w, bt.h, elapsed, delta, audioTex);
        }

        // Image pass renders into fboCurrent_ (always full window res).
        if (currentSet_->hasPass[PASS_IMAGE]) {
            renderPass(PASS_IMAGE, currentSet_->passes[PASS_IMAGE], fboCurrent_,
                       width_, height_, elapsed, delta, audioTex);
        }

        // After all passes done this frame, swap each buffer's
        // ping-pong index — next frame's reads see the texture we
        // just wrote to.
        for (int i = 0; i < 4; ++i) {
            if (currentSet_->hasPass[i] && bufferTargets_[i].allocated) {
                bufferTargets_[i].writeIdx ^= 1;
            }
        }
    }

    // === Present: fboCurrent_ → window, with optional crossfade ===
    float mixT = 1.0f;
    if (transitioning_) {
        const float t = std::chrono::duration<float>(now - transitionStart_).count()
                          / kTransitionDuration;
        if (t >= 1.0f) { transitioning_ = false; mixT = 1.0f; }
        else mixT = t * t * (3.0f - 2.0f * t);
    }

    if (!transitioning_) {
        // Common case (no crossfade in flight): fboCurrent_ and the window
        // are the same size, so a straight blit copies it to the screen.
        // Cheaper than binding the present program + samplers and drawing a
        // textured triangle just to sample one texture 1:1 every frame —
        // and the old path bound *both* present textures + set uniforms even
        // though the shader only sampled `current` when not transitioning.
        glBindFramebuffer(GL_READ_FRAMEBUFFER, fboCurrent_);
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        glBlitFramebuffer(0, 0, width_, height_, 0, 0, width_, height_,
                          GL_COLOR_BUFFER_BIT, GL_NEAREST);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    } else {
        // Crossfade in progress: blend the held previous frame (texOld_)
        // with the new shader's current frame (texCurrent_).
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, width_, height_);
        glUseProgram(presentProgram_);
        if (locPresentCurrent_ >= 0) {
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, texCurrent_);
            glUniform1i(locPresentCurrent_, 0);
        }
        if (locPresentOld_ >= 0) {
            glActiveTexture(GL_TEXTURE1);
            glBindTexture(GL_TEXTURE_2D, texOld_);
            glUniform1i(locPresentOld_, 1);
        }
        if (locPresentMixT_ >= 0) glUniform1f(locPresentMixT_, mixT);
        glBindVertexArray(vao_);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glBindVertexArray(0);
    }

    ++frameCount_;
}

void ShaderEngine::addPcm(const float* samples, std::size_t frameCount) {
    audio_.addPcm(samples, frameCount);
}

void ShaderEngine::setTuning(const float* values, std::size_t count) {
    if (!values) return;
    // Layout: [0]=minDb, [1]=maxDb, [2]=smoothing, [3..]=iParams[0..].
    // Runs on the render thread (the bridge applies the latest value
    // before renderFrame), so params_ writes don't race renderPass reads.
    if (count >= 3) audio_.setParams(values[0], values[1], values[2]);
    for (int i = 0; i < NUM_PARAMS; ++i) {
        const std::size_t idx = static_cast<std::size_t>(i) + 3;
        params_[i] = (idx < count) ? values[idx] : 0.0f;
    }
    // Pushed to the programs by the next renderFrame (not here — this may run
    // before the current set exists, and we want a single GL touch point).
    paramsDirty_ = true;
}

void ShaderEngine::loadPreset(const char* data, bool /*smoothTransition*/) {
    if (!data) return;
    if (!worker_.joinable()) {
        // Sync fallback if the worker couldn't be set up.
        PassSet* set = compilePassSet(std::string(data));
        if (!set) return;
        // Snapshot for crossfade, then install.
        if (currentSet_ && fboCurrent_ && fboOld_) {
            glBindFramebuffer(GL_READ_FRAMEBUFFER, fboCurrent_);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, fboOld_);
            glBlitFramebuffer(0,0,width_,height_, 0,0,width_,height_,
                               GL_COLOR_BUFFER_BIT, GL_NEAREST);
            glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
            glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        }
        clearCurrentSet();
        currentSet_ = set;
        for (int i = 0; i < 4; ++i) {
            if (currentSet_->hasPass[i]) ensureBufferTarget(i);
        }
        primeConstantUniforms(currentSet_);
        transitionStart_ = std::chrono::steady_clock::now();
        transitioning_ = (fboOld_ != 0);
        return;
    }
    // Async: queue source, worker compiles into a PassSet and posts back.
    {
        std::lock_guard<std::mutex> lock(queueMutex_);
        pendingSource_ = data;
        hasPendingSource_ = true;
    }
    queueCv_.notify_one();
}
