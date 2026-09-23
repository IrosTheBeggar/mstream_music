// audio_texture.cpp logs one failure path through this; off a phone it has
// nowhere to go.
#pragma once

#define ANDROID_LOG_ERROR 6

inline int __android_log_print(int, const char*, const char*, ...) { return 0; }
