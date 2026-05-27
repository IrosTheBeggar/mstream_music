# Native bridge for the projectM visualizer. Produces
# libvisualizer_bridge.so which exports JNI methods that the Kotlin
# VisualizerBridge calls — those JNI methods own the EGL context and
# call into libprojectM-4.so to render frames.
#
# libprojectM-4.so itself is prebuilt and lives in jniLibs/<abi>/. We
# IMPORT it here so CMake can link against it without rebuilding.

cmake_minimum_required(VERSION 3.10)
project(visualizer_bridge LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Locate the prebuilt libprojectM-4.so for the current ABI.
set(PROJECTM_LIB_PATH
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libprojectM-4.so)

add_library(projectM-4 SHARED IMPORTED)
set_target_properties(projectM-4 PROPERTIES
    IMPORTED_LOCATION ${PROJECTM_LIB_PATH})

# Our bridge .so.
add_library(visualizer_bridge SHARED visualizer_bridge.cpp)

target_include_directories(visualizer_bridge PRIVATE include)

target_link_libraries(visualizer_bridge
    PRIVATE
        projectM-4
        EGL
        GLESv3
        android
        log)
