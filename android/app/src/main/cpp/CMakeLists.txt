# Native bridge for the projectM visualizer. Produces
# libvisualizer_bridge.so which exports JNI methods that the Kotlin
# VisualizerBridge calls — those JNI methods own the EGL context and
# delegate per-frame work to an Engine instance (ProjectMEngine or
# ShaderEngine).
#
# libprojectM-4.so itself is prebuilt and lives in jniLibs/<abi>/. We
# IMPORT it here so CMake can link against it without rebuilding.
# Shader engine has no external deps beyond GLES/EGL.

cmake_minimum_required(VERSION 3.10)
project(visualizer_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 99)

# Locate the prebuilt libprojectM-4.so for the current ABI.
set(PROJECTM_LIB_PATH
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libprojectM-4.so)

add_library(projectM-4 SHARED IMPORTED)
set_target_properties(projectM-4 PROPERTIES
    IMPORTED_LOCATION ${PROJECTM_LIB_PATH})

# Vendored KissFFT (BSD-3-Clause) — compiled as part of the bridge so
# we don't ship a separate .so. -DFIXED_POINT=0 -DKISS_FFT_USE_SINGLE
# selects the float32 build.
add_library(visualizer_bridge SHARED
    visualizer_bridge.cpp
    projectm_engine.cpp
    shader_engine.cpp
    audio_texture.cpp
    kissfft/kiss_fft.c
    kissfft/kiss_fftr.c)

target_include_directories(visualizer_bridge PRIVATE
    include
    kissfft)

# KissFFT uses `kiss_fft_scalar` typedef'd to float by default. We
# silence its log macros (which would otherwise pull in fprintf).
target_compile_definitions(visualizer_bridge PRIVATE
    kiss_fft_scalar=float)

target_link_libraries(visualizer_bridge
    PRIVATE
        projectM-4
        EGL
        GLESv3
        android
        log)
