/**
 * Buffer texture (GL_TEXTURE_BUFFER) emulation for OpenGL ES 3.0.
 * See texture_buffer.h for a description of the problem and the approach.
 *
 * Created by: DuyKhanhTran
 * For use under LGPL-3.0
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "GL/gl.h"
#include <GLES3/gl3.h>
#include "proc.h"
#include "egl.h"
#include "main.h"
#include "texture_buffer.h"

#define TBO_MAX_TEXTURES 8
#define TBO_MAX_BUFFERS 8

typedef struct {
    GLuint name;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
    int bytesPerTexel;
    GLuint backing2D;
    GLint texWidth;
    GLuint buffer;
    GLintptr rangeOffset;
    GLsizeiptr rangeSize;
} tbo_texture_t;

typedef struct {
    GLuint name;
    GLsizeiptr size;
    unsigned char* data;
} tbo_buffer_t;

typedef struct {
    GLuint buffer;
    bool active;
} tbo_map_t;

static tbo_texture_t tbo_textures[TBO_MAX_TEXTURES];
static tbo_buffer_t tbo_buffers[TBO_MAX_BUFFERS];
static tbo_map_t tbo_map;

static GLuint g_tbo_bound_buffer;  /* buffer bound to GL_TEXTURE_BUFFER */
static GLuint g_tbo_bound_texture; /* texture bound to GL_TEXTURE_BUFFER */
static GLenum g_tbo_bound_unit;    /* active texture unit at bind time */

void tbo_set_bound_buffer(GLuint name) {
    g_tbo_bound_buffer = name;
}

static tbo_buffer_t* tbo_find_buffer(GLuint name) {
    for(int i = 0; i < TBO_MAX_BUFFERS; i++) {
        if(tbo_buffers[i].name == name) return &tbo_buffers[i];
    }
    return NULL;
}

static tbo_buffer_t* tbo_create_buffer(GLuint name) {
    tbo_buffer_t* b = tbo_find_buffer(name);
    if(b != NULL) return b;
    for(int i = 0; i < TBO_MAX_BUFFERS; i++) {
        if(tbo_buffers[i].name == 0) {
            memset(&tbo_buffers[i], 0, sizeof(tbo_buffer_t));
            tbo_buffers[i].name = name;
            return &tbo_buffers[i];
        }
    }
    printf("LTW: TBO buffer slots exhausted\n");
    return NULL;
}

static tbo_texture_t* tbo_find_texture(GLuint name) {
    for(int i = 0; i < TBO_MAX_TEXTURES; i++) {
        if(tbo_textures[i].name == name) return &tbo_textures[i];
    }
    return NULL;
}

static tbo_texture_t* tbo_create_texture(GLuint name) {
    tbo_texture_t* t = tbo_find_texture(name);
    if(t != NULL) return t;
    for(int i = 0; i < TBO_MAX_TEXTURES; i++) {
        if(tbo_textures[i].name == 0) {
            memset(&tbo_textures[i], 0, sizeof(tbo_texture_t));
            tbo_textures[i].name = name;
            return &tbo_textures[i];
        }
    }
    printf("LTW: TBO texture slots exhausted\n");
    return NULL;
}

static GLuint tbo_target_buffer(GLenum target) {
    if(target == GL_TEXTURE_BUFFER) return g_tbo_bound_buffer;
    int idx = get_buffer_index(target);
    if(idx < 0) return 0;
    return current_context->bound_buffers[idx];
}

bool tbo_is_emulated_buffer(GLenum target) {
    if(!current_context) return false;
    GLuint buf = tbo_target_buffer(target);
    if(buf == 0) return false;
    return (target == GL_TEXTURE_BUFFER) || (tbo_find_buffer(buf) != NULL) || (buf == g_tbo_bound_buffer);
}

static bool tbo_format_info(GLenum internalFormat, GLenum* format, GLenum* type, int* bytesPerTexel) {
    switch(internalFormat) {
        case GL_R8:  *format = GL_RED;  *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 1; return true;
        case GL_R8I: *format = GL_RED_INTEGER; *type = GL_BYTE; *bytesPerTexel = 1; return true;
        case GL_R8UI: *format = GL_RED_INTEGER; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 1; return true;
        case GL_R16I: *format = GL_RED_INTEGER; *type = GL_SHORT; *bytesPerTexel = 2; return true;
        case GL_R16UI: *format = GL_RED_INTEGER; *type = GL_UNSIGNED_SHORT; *bytesPerTexel = 2; return true;
        case GL_R32I: *format = GL_RED_INTEGER; *type = GL_INT; *bytesPerTexel = 4; return true;
        case GL_R32UI: *format = GL_RED_INTEGER; *type = GL_UNSIGNED_INT; *bytesPerTexel = 4; return true;
        case GL_RG8: *format = GL_RG; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 2; return true;
        case GL_RG8I: *format = GL_RG_INTEGER; *type = GL_BYTE; *bytesPerTexel = 2; return true;
        case GL_RG8UI: *format = GL_RG_INTEGER; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 2; return true;
        case GL_RG16I: *format = GL_RG_INTEGER; *type = GL_SHORT; *bytesPerTexel = 4; return true;
        case GL_RG16UI: *format = GL_RG_INTEGER; *type = GL_UNSIGNED_SHORT; *bytesPerTexel = 4; return true;
        case GL_RG32I: *format = GL_RG_INTEGER; *type = GL_INT; *bytesPerTexel = 8; return true;
        case GL_RG32UI: *format = GL_RG_INTEGER; *type = GL_UNSIGNED_INT; *bytesPerTexel = 8; return true;
        case GL_RGB8: *format = GL_RGB; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 3; return true;
        case GL_RGB8I: *format = GL_RGB_INTEGER; *type = GL_BYTE; *bytesPerTexel = 3; return true;
        case GL_RGB8UI: *format = GL_RGB_INTEGER; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 3; return true;
        case GL_RGB32I: *format = GL_RGB_INTEGER; *type = GL_INT; *bytesPerTexel = 12; return true;
        case GL_RGB32UI: *format = GL_RGB_INTEGER; *type = GL_UNSIGNED_INT; *bytesPerTexel = 12; return true;
        case GL_RGBA8: *format = GL_RGBA; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 4; return true;
        case GL_RGBA8I: *format = GL_RGBA_INTEGER; *type = GL_BYTE; *bytesPerTexel = 4; return true;
        case GL_RGBA8UI: *format = GL_RGBA_INTEGER; *type = GL_UNSIGNED_BYTE; *bytesPerTexel = 4; return true;
        case GL_RGBA16I: *format = GL_RGBA_INTEGER; *type = GL_SHORT; *bytesPerTexel = 8; return true;
        case GL_RGBA16UI: *format = GL_RGBA_INTEGER; *type = GL_UNSIGNED_SHORT; *bytesPerTexel = 8; return true;
        case GL_RGBA32I: *format = GL_RGBA_INTEGER; *type = GL_INT; *bytesPerTexel = 16; return true;
        case GL_RGBA32UI: *format = GL_RGBA_INTEGER; *type = GL_UNSIGNED_INT; *bytesPerTexel = 16; return true;
        case GL_R32F: *format = GL_RED; *type = GL_FLOAT; *bytesPerTexel = 4; return true;
        case GL_RGBA32F: *format = GL_RGBA; *type = GL_FLOAT; *bytesPerTexel = 16; return true;
        default: return false;
    }
}

static GLenum tbo_scratch_unit(void) {
    static GLenum unit = 0;
    if(unit == 0) {
        GLint maxUnits = 8;
        es3_functions.glGetIntegerv(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS, &maxUnits);
        unit = GL_TEXTURE0 + (maxUnits > 1 ? maxUnits - 1 : 0);
    }
    return unit;
}

static void tbo_upload(tbo_texture_t* t) {
    if(!current_context || !t || !t->backing2D) return;
    tbo_buffer_t* b = tbo_find_buffer(t->buffer);
    if(!b || !b->data || b->size <= 0) return;

    GLsizeiptr span = t->rangeSize > 0 ? t->rangeSize : b->size;
    GLintptr offset = t->rangeOffset > 0 ? t->rangeOffset : 0;
    if(offset + span > b->size) span = b->size - offset;
    if(span <= 0) return;

    GLsizei needW = (GLsizei)((span + t->bytesPerTexel - 1) / t->bytesPerTexel);
    if(needW < 1) needW = 1;
    GLint maxSize = current_context->maxTextureSize > 0 ? current_context->maxTextureSize : 4096;
    if(needW > maxSize) needW = maxSize;

    GLint oldUnit = 0, oldTex = 0;
    es3_functions.glGetIntegerv(GL_ACTIVE_TEXTURE, &oldUnit);
    es3_functions.glActiveTexture(tbo_scratch_unit());
    es3_functions.glGetIntegerv(GL_TEXTURE_BINDING_2D, &oldTex);
    es3_functions.glBindTexture(GL_TEXTURE_2D, t->backing2D);
    if(t->texWidth < needW) {
        es3_functions.glTexImage2D(GL_TEXTURE_2D, 0, t->internalFormat, needW, 1, 0, t->format, t->type, b->data + offset);
        t->texWidth = needW;
    } else {
        es3_functions.glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, needW, 1, t->format, t->type, b->data + offset);
    }
    es3_functions.glBindTexture(GL_TEXTURE_2D, (GLuint)oldTex);
    es3_functions.glActiveTexture((GLenum)oldUnit);
}

static void tbo_upload_for_buffer(GLuint buffer) {
    for(int i = 0; i < TBO_MAX_TEXTURES; i++) {
        if(tbo_textures[i].name != 0 && tbo_textures[i].buffer == buffer) {
            tbo_upload(&tbo_textures[i]);
        }
    }
}

void tbo_mirror_buffer_data(GLenum target, GLsizeiptr offset, GLsizeiptr size, const void* data, bool replace) {
    if(!current_context || size < 0) return;
    GLuint buf = tbo_target_buffer(target);
    if(buf == 0) return;
    tbo_buffer_t* b = tbo_create_buffer(buf);
    if(!b) return;
    if(replace) {
        unsigned char* n = realloc(b->data, (size_t)size);
        if(!n && size > 0) return;
        b->data = n;
        b->size = size;
        if(data != NULL && size > 0) memcpy(b->data, data, (size_t)size);
        else if(size > 0) memset(b->data, 0, (size_t)size);
    } else {
        if(offset + size > b->size) {
            GLsizeiptr grow = offset + size;
            unsigned char* n = realloc(b->data, (size_t)grow);
            if(!n) return;
            memset(n + b->size, 0, (size_t)(grow - b->size));
            b->data = n;
            b->size = grow;
        }
        if(data != NULL && size > 0) memcpy(b->data + offset, data, (size_t)size);
    }
    tbo_upload_for_buffer(buf);
}

void* tbo_map_buffer(GLenum target, GLintptr offset, GLsizeiptr length) {
    if(!current_context || length <= 0) return NULL;
    GLuint buf = tbo_target_buffer(target);
    if(buf == 0 || !tbo_is_emulated_buffer(target)) return NULL;
    tbo_buffer_t* b = tbo_create_buffer(buf);
    if(!b) return NULL;
    if(offset + length > b->size) {
        GLsizeiptr grow = offset + length;
        unsigned char* n = realloc(b->data, (size_t)grow);
        if(!n) return NULL;
        memset(n + b->size, 0, (size_t)(grow - b->size));
        b->data = n;
        b->size = grow;
    }
    tbo_map.buffer = buf;
    tbo_map.active = true;
    return b->data + offset;
}

void tbo_map_sync(GLenum target) {
    if(!tbo_map.active) return;
    GLuint buf = tbo_target_buffer(target);
    if(buf == 0 || buf != tbo_map.buffer) return;
    tbo_map.active = false;
    tbo_upload_for_buffer(buf);
}

static void tbo_attach(GLuint buffer, GLenum internalFormat, GLintptr rangeOffset, GLsizeiptr rangeSize) {
    if(!current_context) return;
    GLuint texName = g_tbo_bound_texture;
    if(texName == 0) { printf("LTW: glTexBuffer without a bound GL_TEXTURE_BUFFER texture\n"); return; }
    GLenum format, type;
    int bytesPerTexel;
    if(!tbo_format_info(internalFormat, &format, &type, &bytesPerTexel)) {
        printf("LTW: glTexBuffer unsupported internal format 0x%x\n", internalFormat);
        return;
    }
    tbo_buffer_t* b = tbo_create_buffer(buffer);
    if(!b) return;
    tbo_texture_t* t = tbo_find_texture(texName);
    bool isNew = false;
    if(t == NULL) {
        t = tbo_create_texture(texName);
        isNew = true;
    }
    if(t == NULL) return;
    t->internalFormat = internalFormat;
    t->format = format;
    t->type = type;
    t->bytesPerTexel = bytesPerTexel;
    t->buffer = buffer;
    t->rangeOffset = rangeOffset;
    t->rangeSize = rangeSize;
    if(isNew || t->backing2D == 0) {
        GLuint newBacking = 0;
        es3_functions.glGenTextures(1, &newBacking);
        if(newBacking == 0) { printf("LTW: TBO backing texture allocation failed\n"); return; }
        t->backing2D = newBacking;
        GLint oldUnit = 0, oldTex = 0;
        es3_functions.glGetIntegerv(GL_ACTIVE_TEXTURE, &oldUnit);
        es3_functions.glActiveTexture(tbo_scratch_unit());
        es3_functions.glGetIntegerv(GL_TEXTURE_BINDING_2D, &oldTex);
        es3_functions.glBindTexture(GL_TEXTURE_2D, t->backing2D);
        es3_functions.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        es3_functions.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        es3_functions.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        es3_functions.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        es3_functions.glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, 1, 1, 0, format, type, NULL);
        t->texWidth = 1;
        es3_functions.glBindTexture(GL_TEXTURE_2D, (GLuint)oldTex);
        es3_functions.glActiveTexture((GLenum)oldUnit);
        /* keep the unit the app last bound this texture to sampling the new
         * backing object */
        if(texName == g_tbo_bound_texture && g_tbo_bound_unit != 0) {
            es3_functions.glActiveTexture(g_tbo_bound_unit);
            es3_functions.glBindTexture(GL_TEXTURE_2D, t->backing2D);
            es3_functions.glActiveTexture((GLenum)oldUnit);
        }
    }
    tbo_upload(t);
}

void glBindTexture(GLenum target, GLuint texture) {
    if(!current_context) return;
    if(target == GL_TEXTURE_BUFFER) {
        g_tbo_bound_texture = texture;
        GLint activeUnit = 0;
        es3_functions.glGetIntegerv(GL_ACTIVE_TEXTURE, &activeUnit);
        g_tbo_bound_unit = (GLenum)activeUnit;
        tbo_texture_t* t = texture != 0 ? tbo_find_texture(texture) : NULL;
        GLuint backing = (t != NULL && t->backing2D != 0) ? t->backing2D : 0;
        es3_functions.glBindTexture(GL_TEXTURE_2D, backing);
        return;
    }
    es3_functions.glBindTexture(target, texture);
}

void glBufferData(GLenum target, GLsizeiptr size, const void* data, GLenum usage) {
    if(!current_context) return;
    bool tboData = tbo_is_emulated_buffer(target);
    if(tboData && target != GL_TEXTURE_BUFFER) {
        /* also keep the real buffer in sync so other targets still work */
        es3_functions.glBufferData(target, size, data, usage);
    }
    if(tboData) {
        tbo_mirror_buffer_data(target, 0, size, data, true);
        return;
    }
    es3_functions.glBufferData(target, size, data, usage);
}

void glBufferSubData(GLenum target, GLintptr offset, GLsizeiptr size, const void* data) {
    if(!current_context) return;
    bool tboData = tbo_is_emulated_buffer(target);
    if(tboData && target != GL_TEXTURE_BUFFER) {
        es3_functions.glBufferSubData(target, offset, size, data);
    }
    if(tboData) {
        tbo_mirror_buffer_data(target, offset, size, data, false);
        return;
    }
    es3_functions.glBufferSubData(target, offset, size, data);
}

GLboolean glUnmapBuffer(GLenum target) {
    if(!current_context) return GL_FALSE;
    if(tbo_map.active) {
        GLuint buf = tbo_target_buffer(target);
        if(buf != 0 && buf == tbo_map.buffer && tbo_is_emulated_buffer(target)) {
            tbo_map_sync(target);
            return GL_TRUE;
        }
    }
    return es3_functions.glUnmapBuffer(target);
}

void glGetBufferParameteriv(GLenum target, GLenum pname, GLint* params) {
    if(!current_context || params == NULL) return;
    GLuint buf = tbo_target_buffer(target);
    if(buf != 0 && pname == GL_BUFFER_SIZE) {
        tbo_buffer_t* b = tbo_find_buffer(buf);
        if(b != NULL) { *params = (GLint)b->size; return; }
    }
    es3_functions.glGetBufferParameteriv(target, pname, params);
}

void tbo_delete_textures(GLsizei n, const GLuint* textures) {
    for(GLsizei i = 0; i < n; i++) {
        tbo_texture_t* t = tbo_find_texture(textures[i]);
        if(t != NULL) {
            if(t->backing2D != 0) es3_functions.glDeleteTextures(1, &t->backing2D);
            memset(t, 0, sizeof(tbo_texture_t));
        }
        if(g_tbo_bound_texture == textures[i]) g_tbo_bound_texture = 0;
    }
}

void glDeleteBuffers(GLsizei n, const GLuint* buffers) {
    if(!current_context) return;
    for(GLsizei i = 0; i < n; i++) {
        tbo_buffer_t* b = tbo_find_buffer(buffers[i]);
        if(b != NULL) {
            free(b->data);
            memset(b, 0, sizeof(tbo_buffer_t));
        }
        if(g_tbo_bound_buffer == buffers[i]) g_tbo_bound_buffer = 0;
        if(tbo_map.active && tbo_map.buffer == buffers[i]) tbo_map.active = false;
    }
    es3_functions.glDeleteBuffers(n, buffers);
}

void glTexBuffer(GLenum target, GLenum internalFormat, GLuint buffer) {
    if(!current_context) return;
    if(target == GL_TEXTURE_BUFFER) {
        if(current_context->es32) {
            es3_functions.glTexBuffer(target, internalFormat, buffer);
        } else if(current_context->buffer_texture_ext) {
            es3_functions.glTexBufferEXT(target, internalFormat, buffer);
        } else {
            tbo_attach(buffer, internalFormat, 0, 0);
        }
        return;
    }
    if(current_context->es32) {
        es3_functions.glTexBuffer(target, internalFormat, buffer);
    } else if(current_context->buffer_texture_ext) {
        es3_functions.glTexBufferEXT(target, internalFormat, buffer);
    }
}

void glTexBufferRange(GLenum target, GLenum internalFormat, GLuint buffer, GLintptr offset, GLsizeiptr size) {
    if(!current_context) return;
    if(target == GL_TEXTURE_BUFFER) {
        if(current_context->es32) {
            es3_functions.glTexBufferRange(target, internalFormat, buffer, offset, size);
        } else if(current_context->buffer_texture_ext) {
            es3_functions.glTexBufferRangeEXT(target, internalFormat, buffer, offset, size);
        } else {
            tbo_attach(buffer, internalFormat, offset, size);
        }
        return;
    }
    if(current_context->es32) {
        es3_functions.glTexBufferRange(target, internalFormat, buffer, offset, size);
    } else if(current_context->buffer_texture_ext) {
        es3_functions.glTexBufferRangeEXT(target, internalFormat, buffer, offset, size);
    }
}