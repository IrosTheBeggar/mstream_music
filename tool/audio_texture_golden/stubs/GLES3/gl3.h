// Just enough GLES for audio_texture.cpp to compile off a phone. Every call
// is a no-op except glTexSubImage2D, which keeps the bytes it was handed:
// that upload is the texture, and the texture is what gets compared.
#pragma once

#include <cstring>

typedef unsigned int GLuint;
typedef int GLint;
typedef unsigned int GLenum;
typedef int GLsizei;

#define GL_TEXTURE_2D 0x0DE1
#define GL_R8 0x8229
#define GL_RED 0x1903
#define GL_UNSIGNED_BYTE 0x1401
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_LINEAR 0x2601
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_UNPACK_ALIGNMENT 0x0CF5

extern unsigned char g_uploaded[512 * 2];

inline void glGenTextures(GLsizei n, GLuint* names) {
    for (GLsizei i = 0; i < n; ++i) names[i] = 1;
}
inline void glBindTexture(GLenum, GLuint) {}
inline void glTexImage2D(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const void*) {}
inline void glTexParameteri(GLenum, GLenum, GLint) {}
inline void glDeleteTextures(GLsizei, const GLuint*) {}
inline void glPixelStorei(GLenum, GLint) {}
inline void glTexSubImage2D(GLenum, GLint, GLint, GLint, GLsizei w, GLsizei h, GLenum, GLenum,
                            const void* data) {
    std::memcpy(g_uploaded, data, static_cast<std::size_t>(w) * static_cast<std::size_t>(h));
}
