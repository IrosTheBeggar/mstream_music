# Builds audio_capture.dll — WASAPI loopback capture for the desktop visualizer.
# No external dependencies (Windows SDK only), so unlike the projectM shim this
# builds as part of the Flutter Windows build and is bundled next to the exe by
# an install(TARGETS) rule in ../CMakeLists.txt. dart:ffi opens it as
# "audio_capture.dll" (see lib/native/audio_capture.dart).

add_library(audio_capture SHARED audio_capture.cpp)
target_compile_features(audio_capture PUBLIC cxx_std_17)
# Exceptions on (the std threading/containers use them); the parent's
# _HAS_EXCEPTIONS=0 only applies to targets that opt into APPLY_STANDARD_SETTINGS.
target_compile_options(audio_capture PRIVATE /EHsc)
# ole32: CoInitializeEx / CoCreateInstance / CoTaskMemFree. The WASAPI interface
# GUIDs come from __uuidof() in the SDK headers, so no extra GUID lib is needed.
target_link_libraries(audio_capture PRIVATE ole32)
