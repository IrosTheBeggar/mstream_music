// Engine wrapping libprojectM-4.so (Milkdrop visualizer).
//
// Lifecycle: caller must ensure the EGL context is current before
// calling init() — projectm_create reads GL state. All subsequent
// calls (renderFrame, addPcm, loadPreset) also require the context
// to be current on the same thread.

#pragma once

#include <projectM-4/projectM.h>

#include "engine.h"

class ProjectMEngine : public Engine {
public:
    ProjectMEngine() = default;
    ~ProjectMEngine() override;

    bool init(int width, int height) override;
    void renderFrame() override;
    void addPcm(const float* samples, std::size_t frameCount) override;
    void loadPreset(const char* data, bool smoothTransition) override;

private:
    projectm_handle pm_ = nullptr;
};
