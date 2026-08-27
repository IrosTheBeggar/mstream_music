# Builds projectm_desktop.dll — the offscreen WGL + projectM render shim for the
# Windows desktop visualizer. Standalone (NOT part of the Flutter Windows build):
# build it here, then copy the resulting DLL into windows/projectm/ to be bundled.
#
# Paths to the prebuilt projectM + GLEW match windows/projectm/README.md. Override
# with -DPROJECTM_BUILD_DIR / -DGLEW_DIR / -DPROJECTM_HEADERS if they differ.

cmake_minimum_required(VERSION 3.15)
project(projectm_desktop LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(PROJECTM_SRC "C:/Users/paul/build/projectm" CACHE PATH "projectM source dir")
set(PROJECTM_BUILD_DIR "C:/Users/paul/build/projectm-build-windows" CACHE PATH "projectM build dir")
set(GLEW_DIR "C:/Users/paul/build/glew-2.1.0" CACHE PATH "GLEW prebuilt dir")

add_library(projectm_desktop SHARED projectm_desktop.cpp)

target_include_directories(projectm_desktop PRIVATE
    # Source API headers (projectM.h, audio.h, render_opengl.h, ...) plus the
    # build dir's GENERATED, platform-correct projectM_export.h + version.h
    # (declspec on MSVC — the Android-vendored copy uses GCC __attribute__).
    "${PROJECTM_SRC}/src/api/include"
    "${PROJECTM_BUILD_DIR}/src/api/include"
    "${GLEW_DIR}/include")

target_link_libraries(projectm_desktop PRIVATE
    "${PROJECTM_BUILD_DIR}/src/libprojectM/Release/projectM-4.lib"
    "${GLEW_DIR}/lib/Release/x64/glew32.lib"
    opengl32 gdi32 user32)
