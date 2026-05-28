#include "projectm_engine.h"

#include <android/log.h>

#define LOG_TAG "mstream/viz-bridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

ProjectMEngine::~ProjectMEngine() {
    if (pm_) {
        projectm_destroy(pm_);
        pm_ = nullptr;
    }
}

bool ProjectMEngine::init(int width, int height) {
    pm_ = projectm_create();
    if (!pm_) {
        LOGE("projectm_create failed");
        return false;
    }
    projectm_set_window_size(pm_, width, height);
    projectm_set_fps(pm_, 60);
    projectm_set_preset_duration(pm_, 30.0);
    projectm_set_mesh_size(pm_, 48, 36);
    LOGI("ProjectMEngine init ok pm=%p %dx%d", (void*)pm_, width, height);
    return true;
}

void ProjectMEngine::renderFrame() {
    if (!pm_) return;
    projectm_opengl_render_frame(pm_);
}

void ProjectMEngine::addPcm(const float* samples, std::size_t frameCount) {
    if (!pm_ || !samples || frameCount == 0) return;
    projectm_pcm_add_float(pm_, samples,
                            static_cast<unsigned int>(frameCount),
                            PROJECTM_STEREO);
}

void ProjectMEngine::loadPreset(const char* data, bool smoothTransition) {
    if (!pm_ || !data) return;
    projectm_load_preset_data(pm_, data, smoothTransition);
}
