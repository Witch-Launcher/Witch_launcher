/**
 * Buffer texture (GL_TEXTURE_BUFFER) emulation for OpenGL ES 3.0.
 * Minecraft 26.x stores cloud cell data in an isamplerBuffer that is fetched
 * with texelFetch(). GL_EXT_texture_buffer requires ES 3.1, which the ANGLE
 * ES 3.0 backend used on iOS does not expose, so:
 *   - shader_wrapper.c rewrites the source (isamplerBuffer -> isampler2D,
 *     texelFetch(buf, i) -> texelFetch(buf, ivec2(i, 0), 0))
 *   - this module mirrors the app-side buffer contents into a 1-pixel-tall
 *     2D integer texture that the rewritten sampler actually samples.
 */
#ifndef LTW_TEXTURE_BUFFER_H
#define LTW_TEXTURE_BUFFER_H

#include <stdbool.h>
#include "GL/gl.h"

int get_buffer_index(GLenum buffer);

bool tbo_is_emulated_buffer(GLenum target);

/* called by main.c glBindBuffer for the GL_TEXTURE_BUFFER target */
void tbo_set_bound_buffer(GLuint name);

/* called by main.c glDeleteTextures before forwarding */
void tbo_delete_textures(GLsizei n, const GLuint* textures);

/* called by main.c glBufferData/glBufferSubData/glBufferStorage */
void tbo_mirror_buffer_data(GLenum target, GLsizeiptr offset, GLsizeiptr size, const void* data, bool replace);

/* called by main.c glMapBufferRange; returns mirror pointer or NULL */
void* tbo_map_buffer(GLenum target, GLintptr offset, GLsizeiptr length);

/* called by main.c glFlushMappedBufferRange and glUnmapBuffer */
void tbo_map_sync(GLenum target);

void glBindTexture(GLenum target, GLuint texture);
void glBufferData(GLenum target, GLsizeiptr size, const void* data, GLenum usage);
void glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const void* data);
GLboolean glUnmapBuffer(GLenum target);
void glGetBufferParameteriv(GLenum target, GLenum pname, GLint* params);
void glDeleteBuffers(GLsizei n, const GLuint* buffers);
void glTexBuffer(GLenum target, GLenum internalFormat, GLuint buffer);
void glTexBufferRange(GLenum target, GLenum internalFormat, GLuint buffer, GLintptr offset, GLsizeiptr size);

#endif /* LTW_TEXTURE_BUFFER_H */