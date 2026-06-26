# windows/projectm — prebuilt projectM visualizer engine

`projectM-4.dll` is the Windows build of **libprojectM v4.1.6** (the Milkdrop
visualizer engine), and `glew32.dll` is its OpenGL-loader dependency. Both are
committed as prebuilt artifacts and bundled next to `mstream_music.exe` by
`windows/CMakeLists.txt`, where `DynamicLibrary.open("projectM-4.dll")` finds
them (see `lib/native/projectm_bindings.dart`). The install is `OPTIONAL`, so a
checkout without the DLLs still builds — `ProjectMBindings.isAvailable` just
reports false.

Mirrors the Android `jniLibs/<abi>/libprojectM-4.so` convention. Loading the DLL
and reading the version needs **no** GL context; the per-frame render bridge
(offscreen OpenGL context + FBO + presenting frames to Flutter) is separate
native work and not yet implemented on desktop.

## Rebuilding

Source: `C:\Users\paul\build\projectm` (v4.1.6 tag; `vendor/projectm-eval`
submodule initialized). GLEW: `C:\Users\paul\build\glew-2.1.0` (official 2.1.0
Windows prebuilt).

```sh
CMAKE=".../Sdk/cmake/4.1.2/bin/cmake.exe"   # any CMake >= 3.21
GLEW="C:/Users/paul/build/glew-2.1.0"

"$CMAKE" -G "Visual Studio 17 2022" -A x64 \
  -DENABLE_SYSTEM_PROJECTM_EVAL=OFF -DENABLE_SYSTEM_GLM=OFF -DENABLE_SDL_UI=OFF \
  -DBUILD_TESTING=OFF -DENABLE_PLAYLIST=OFF -DBUILD_SHARED_LIBS=ON \
  -DGLEW_INCLUDE_DIR="$GLEW/include" \
  -DGLEW_SHARED_LIBRARY_RELEASE="$GLEW/lib/Release/x64/glew32.lib" \
  -DCMAKE_LIBRARY_PATH="$GLEW/lib/Release/x64" \
  -S C:/Users/paul/build/projectm -B C:/Users/paul/build/projectm-build-windows

"$CMAKE" --build C:/Users/paul/build/projectm-build-windows --config Release --parallel
# -> src/libprojectM/Release/projectM-4.dll ; copy here, with glew32.dll.
```

`ENABLE_PLAYLIST=OFF` means no playlist lib — preset cycling uses direct
`projectm_load_preset_file`/`_data` calls. Runtime also needs the MSVC
runtime (VCRUNTIME140*, MSVCP140) — present via the VC++ redistributable.
