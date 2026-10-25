// MobileGlues - gl/drawing.cpp
// Copyright (c) 2025-2026 MobileGL-Dev
// Licensed under the GNU Lesser General Public License v2.1:
//   https://www.gnu.org/licenses/old-licenses/lgpl-2.1.txt
// SPDX-License-Identifier: LGPL-2.1-only
// End of Source File Header

#include "drawing.h"
#include "restart.h"
#include "buffer.h"
#include "framebuffer.h"
#include "envvars.h"
#include "mg.h"
#include "texture.h"
#include "../egl/context.h"

#define DEBUG 0

GLuint bufSampelerProg;
GLuint bufSampelerLoc;
std::string bufSampelerName;

extern UnorderedMap<GLuint, bool> program_map_is_sampler_buffer_emulated;

UnorderedMap<GLuint, SamplerInfo> g_samplerCacheForSamplerBuffer;

namespace {

// The unit gl/texture.cpp parks the emulated buffer texture on. Kept in step with
// MG_TEXTURE_BUFFER_EMULATION_UNIT there and with gl/buffer.cpp's glTexBuffer,
// which borrows the same one.
const GLint kBufferTextureUnit = 15;

// Everything the two program maps have to say about one program, held so the
// sampler list is not copied out of the map on every draw.
//
// It is not a cache of the lookups themselves. Both maps are re-probed on every
// call, because both carry this layer's invalidation points and neither can reach
// a file-local cache: glCreateProgram clears
// program_map_is_sampler_buffer_emulated[program] and erases the sampler entry --
// it exists for that, because GL hands the name of a deleted program straight back
// out -- and glAttachShader sets the flag. Remembering either answer let a recycled
// name keep the previous program's uniform locations, and glUseProgram cannot be
// the invalidation point instead: it is filtered when the name repeats, and a
// recycled name does repeat.
//
// What is kept is the copy below, valid only while the sampler entry it came from
// is still the entry the map holds for this program. Copied rather than pointed at
// across calls because g_samplerCacheForSamplerBuffer is process-wide with no lock,
// so a pointer into it would not survive a rehash or an erase performed on another
// thread.
struct resolved_program_t {
    GLuint program = 0;
    // The entry the copy below was taken from, and the only thing that says the
    // copy still describes this program. A mismatch costs one copy, never a wrong
    // answer; the map's entries are inserted by this function alone, always from
    // the live program, so a hit at the same address is the entry that was copied.
    const SamplerInfo* source = nullptr;
    bool emulated = false;
    GLint locWidth = -1;
    GLint locHeight = -1;
    std::vector<GLint> samplers;
};

// thread_local because gl_state is: two threads with different current contexts
// have different current programs and must not share this.
thread_local resolved_program_t g_resolved_program;

const resolved_program_t& resolve_program(GLuint program) {
    // find() rather than operator[]: this used to insert a default-constructed
    // entry for every program the application ever drew with, on the draw path,
    // and could rehash the map while doing it.
    const auto emu = program_map_is_sampler_buffer_emulated.find(program);
    if (emu == program_map_is_sampler_buffer_emulated.end() || !emu->second) {
        g_resolved_program.program = program;
        g_resolved_program.source = nullptr;
        g_resolved_program.emulated = false;
        g_resolved_program.locWidth = -1;
        g_resolved_program.locHeight = -1;
        g_resolved_program.samplers.clear();
        return g_resolved_program;
    }

    auto it = g_samplerCacheForSamplerBuffer.find(program);
    if (it != g_samplerCacheForSamplerBuffer.end() && g_resolved_program.program == program &&
        g_resolved_program.source == &it->second) {
        return g_resolved_program;
    }

    const SamplerInfo* info = nullptr;
    if (it != g_samplerCacheForSamplerBuffer.end()) {
        info = &it->second;
    } else {
        // Value-initialised: SamplerInfo has no default member initialisers, and
        // the entry is stored even when the program turns out not to carry the
        // emulation uniforms. The old code inserted the entry *before* that check
        // and returned without filling it in, so every later draw with the same
        // program read whatever the allocation happened to hold -- and reprobing
        // was skipped anyway because the key was present.
        SamplerInfo built{};
        built.locWidth = GLES.glGetUniformLocation(program, "u_BufferTexWidth");
        built.locHeight = GLES.glGetUniformLocation(program, "u_BufferTexHeight");
        if (built.locWidth == -1) {
            LOG_W("u_BufferTexWidth uniform not found in program %d", program);
        } else {
            GLint numUniforms = 0;
            GLES.glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &numUniforms);
            LOG_D("Program %d has %d active uniforms", program, numUniforms);

            for (GLint i = 0; i < numUniforms; ++i) {
                const GLsizei bufSize = 256;
                GLchar name[bufSize];
                GLsizei length = 0;
                GLint size = 0;
                GLenum type = 0;
                GLES.glGetActiveUniform(program, i, bufSize, &length, &size, &type, name);

                if (type == GL_SAMPLER_2D || type == GL_INT_SAMPLER_2D) {
                    built.samplers.push_back(GLES.glGetUniformLocation(program, name));
                }
            }
        }
        info = &(g_samplerCacheForSamplerBuffer[program] = std::move(built));
    }

    g_resolved_program.program = program;
    g_resolved_program.source = info;
    g_resolved_program.samplers.clear();

    // A program with no u_BufferTexWidth has nothing to receive, which is what the
    // early return used to say.
    if (info->locWidth == -1) {
        g_resolved_program.emulated = false;
        g_resolved_program.locWidth = -1;
        g_resolved_program.locHeight = -1;
        return g_resolved_program;
    }

    g_resolved_program.emulated = true;
    g_resolved_program.locWidth = info->locWidth;
    g_resolved_program.locHeight = info->locHeight;
    g_resolved_program.samplers = info->samplers;
    return g_resolved_program;
}

} // namespace

void setupBufferTextureUniforms(GLuint program) {
    LOG_D("setupBufferTextureUniforms, program: %d", program);

    const resolved_program_t& info = resolve_program(program);
    if (!info.emulated || info.samplers.empty()) return;

    // The uniform writes stay on the draw path rather than moving to glUseProgram.
    // The size uniforms describe whatever texture is parked on the emulation unit
    // *now*, and an application is entitled to bind its buffer texture after
    // glUseProgram and before the draw -- resolving them at glUseProgram time would
    // describe the previous binding. Only the map lookups above are hoisted, and
    // those depend on the program alone.
    //
    // Every sampler in the program reads that one binding, so it is resolved once
    // for the whole loop instead of once per sampler, as are the size uniforms.
    GLuint texId = 0;
    if (!mg_driver_texture_binding_at_unit(kBufferTextureUnit, GL_TEXTURE_2D, &texId)) {
        // The tracked driver-side binding is not trustworthy right now (FSR1 leaves
        // a texture bound on a unit nothing records), so pay for the round trip.
        // Borrowing the unit has to hand it back: gl/buffer.cpp's glTexBuffer and
        // gl/texture.cpp's glBindTexture both assume the emulation unit is only
        // ever active inside a window that restores it.
        const int prev_unit = mg_driver_active_texture_unit();
        GLES.glActiveTexture(GL_TEXTURE0 + kBufferTextureUnit);
        GLint queried = 0;
        GLES.glGetIntegerv(GL_TEXTURE_BINDING_2D, &queried);
        GLES.glActiveTexture(GL_TEXTURE0 + prev_unit);
        texId = static_cast<GLuint>(queried);
    }
    if (texId == 0) return;

    const TextureObject* texObject = mgGetTexObjectByID(texId);
    // mgGetTexObjectByID answers null for a name this layer has no record of. The
    // dimensions are the whole point of these uniforms, so there is nothing useful
    // to write without it.
    if (!texObject) return;

    bool wrote_sampler = false;
    for (const GLint locSampler : info.samplers) {
        if (locSampler < 0) continue;
        GLES.glUniform1i(locSampler, kBufferTextureUnit);
        wrote_sampler = true;
    }
    if (!wrote_sampler) return;

    GLES.glUniform1i(info.locWidth, texObject->width);
    GLES.glUniform1i(info.locHeight, texObject->height);
}

// ---- Diagnostic draw trace (see mg.h) --------------------------------------
//
// Only active while AMETHYST_RENDER_LOG=1. One record per draw, kept in a ring
// so a frame's tail can be printed at swap time without buffering the whole
// frame. The unit-0 texture is read from this layer's own shadow, so noting a
// draw never touches the driver. Blits are recorded too: the present pass is a
// blit, and whether the GUI draws land before or after it is exactly the
// question the first version of this trace could not answer.
// get_framebuffer lives in gl/framebuffer.cpp and carries the per-FBO colour
// attachment records this trace reports. Global-scope declaration so the local
// definition of get_framebuffer links.
framebuffer_t& get_framebuffer(GLuint id);

namespace {
// 512 because the world draws now share the ring with the GUI's: a frame of
// terrain plus HUD is comfortably over the old 96.
constexpr unsigned kDrawTraceRing = 512;

struct mg_draw_trace_rec_t {
    GLuint program; // draw: bound program; blit: 0
    GLuint fbo;     // draw: draw fbo (this layer's shadow); blit: dst fbo
    GLuint drvFbo;  // driver-side binding at the call (write fbo; blit: read fbo)
    GLuint tex0;
    GLuint att0; // texture of the fbo's GL_COLOR_ATTACHMENT0 per this layer's shadow
    unsigned char kind; // 0 = draw, 1 = blit, 2 = passthrough draw (gl_native)
    char what;          // native draws: which entry point
    GLuint srcFbo;
    GLuint mask; // blit: GLbitfield mask
    GLuint err;  // blit: driver error after the call
    GLint count;     // native draws: vertex/index count (-1 unknown)
    GLint instances; // native draws: instance count
    GLuint mode;     // native draws: GL enum
};

static GLuint mg_draw_trace_drv_draw_fbo() {
    GLint v = 0;
    GLES.glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, &v);
    return (GLuint)v;
}

static GLuint mg_draw_trace_drv_read_fbo() {
    GLint v = 0;
    GLES.glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, &v);
    return (GLuint)v;
}

static GLuint mg_draw_trace_att0(GLuint fbo) {
    if (fbo == 0) return 0;
    framebuffer_t& fb = get_framebuffer(fbo);
    if (!fb.initialized || fb.color_attachments.empty()) return 0;
    return fb.color_attachments[0].texture;
}

thread_local mg_draw_trace_rec_t g_draw_ring[kDrawTraceRing];
thread_local unsigned g_draw_ring_pos = 0;
thread_local unsigned g_draw_ring_count = 0;
thread_local unsigned long long g_draw_frame_total = 0;
thread_local int g_draw_trace_cached = -1;

bool mg_draw_trace_on() {
    if (g_draw_trace_cached < 0) g_draw_trace_cached = IsEnvVarTrue("AMETHYST_RENDER_LOG") ? 1 : 0;
    return g_draw_trace_cached == 1;
}
} // namespace

// The link status and the active attribute list say whether the program the
// draw will use is the shader the game compiled, or a failed link that leaves
// the draw a no-op. The Metal GUI programs are the only ones that look wrong
// while the same draw works on Vulkan, so their link logs matter more than the
// VAO state that was already checked.
static void mg_ui_program_diag(GLuint program) {
    GLint link = 0, validate = 0, infoLen = 0;
    GLES.glGetProgramiv(program, GL_LINK_STATUS, &link);
    GLES.glGetProgramiv(program, GL_VALIDATE_STATUS, &validate);
    GLES.glGetProgramiv(program, GL_INFO_LOG_LENGTH, &infoLen);
    LOG_W_FORCE("[MGUIDIAG]   link=%d validate=%d infoLen=%d", link, validate, infoLen);
    if (infoLen > 1) {
        char info[512] = {};
        GLsizei written = 0;
        GLES.glGetProgramInfoLog(program, (GLsizei)sizeof(info), &written, info);
        LOG_W_FORCE("[MGUIDIAG]   linklog: %s", info);
    }

    GLint attached = 0;
    GLES.glGetProgramiv(program, GL_ATTACHED_SHADERS, &attached);
    GLuint shaders[8] = {};
    if (attached > 8) attached = 8;
    if (attached > 0) GLES.glGetAttachedShaders(program, attached, nullptr, shaders);
    for (GLint i = 0; i < attached; ++i) {
        GLint type = 0, compiled = 0, shaderInfoLen = 0;
        GLES.glGetShaderiv(shaders[i], GL_SHADER_TYPE, &type);
        GLES.glGetShaderiv(shaders[i], GL_COMPILE_STATUS, &compiled);
        GLES.glGetShaderiv(shaders[i], GL_INFO_LOG_LENGTH, &shaderInfoLen);
        LOG_W_FORCE("[MGUIDIAG]   shader=%u type=0x%X compile=%d infoLen=%d", shaders[i], type, compiled,
                    shaderInfoLen);
        if (shaderInfoLen > 1) {
            char info[512] = {};
            GLsizei written = 0;
            GLES.glGetShaderInfoLog(shaders[i], (GLsizei)sizeof(info), &written, info);
            LOG_W_FORCE("[MGUIDIAG]   shaderlog: %s", info);
        }
    }

    GLint attribs = 0;
    GLES.glGetProgramiv(program, GL_ACTIVE_ATTRIBUTES, &attribs);
    for (GLint i = 0; i < attribs && i < 16; ++i) {
        GLchar name[128] = {};
        GLsizei nameLen = 0;
        GLint size = 0;
        GLenum type = 0;
        GLES.glGetActiveAttrib(program, (GLuint)i, (GLsizei)sizeof(name), &nameLen, &size, &type, name);
        LOG_W_FORCE("[MGUIDIAG]   attrib %s loc=%d type=0x%X size=%d", name,
                    GLES.glGetAttribLocation(program, name), type, size);
    }
}

// The pipeline state at the draw, not at swap: cull mode and winding decide
// whether the GUI quad is rasterized at all, and blend decides whether a
// transparent texel disappears. Swap-time state is set for the next frame and
// cannot answer either.
static void mg_ui_draw_state_diag() {
    const GLboolean blend = GLES.glIsEnabled(GL_BLEND);
    const GLboolean cull = GLES.glIsEnabled(GL_CULL_FACE);
    const GLboolean depth = GLES.glIsEnabled(GL_DEPTH_TEST);
    const GLboolean scissor = GLES.glIsEnabled(GL_SCISSOR_TEST);
    GLint eqRGB = 0, eqA = 0, srcRGB = 0, dstRGB = 0, srcA = 0, dstA = 0;
    GLES.glGetIntegerv(GL_BLEND_EQUATION_RGB, &eqRGB);
    GLES.glGetIntegerv(GL_BLEND_EQUATION_ALPHA, &eqA);
    GLES.glGetIntegerv(GL_BLEND_SRC_RGB, &srcRGB);
    GLES.glGetIntegerv(GL_BLEND_DST_RGB, &dstRGB);
    GLES.glGetIntegerv(GL_BLEND_SRC_ALPHA, &srcA);
    GLES.glGetIntegerv(GL_BLEND_DST_ALPHA, &dstA);
    GLint cullMode = 0, frontFace = 0, depthFunc = 0;
    GLES.glGetIntegerv(GL_CULL_FACE_MODE, &cullMode);
    GLES.glGetIntegerv(GL_FRONT_FACE, &frontFace);
    GLES.glGetIntegerv(GL_DEPTH_FUNC, &depthFunc);
    GLboolean depthMask = GL_FALSE;
    GLES.glGetBooleanv(GL_DEPTH_WRITEMASK, &depthMask);
    GLint box[4] = {}, vp[4] = {};
    GLES.glGetIntegerv(GL_SCISSOR_BOX, box);
    GLES.glGetIntegerv(GL_VIEWPORT, vp);
    GLboolean colorMask[4] = {};
    GLES.glGetBooleanv(GL_COLOR_WRITEMASK, colorMask);
    GLint sampler = 0;
    GLES.glGetIntegerv(GL_SAMPLER_BINDING, &sampler);
    LOG_W_FORCE("[MGUIDIAG]   state blend=%d eq=0x%X/0x%X src=0x%X/0x%X dst=0x%X/0x%X cull=%d mode=0x%X front=0x%X "
                "depth=%d func=0x%X mask=%d scissor=%d box=%d,%d %dx%d vp=%d,%d %dx%d colorMask=%d,%d,%d,%d "
                "sampler=%d",
                blend ? 1 : 0, eqRGB, eqA, srcRGB, dstRGB, srcA, dstA, cull ? 1 : 0, cullMode, frontFace,
                depth ? 1 : 0, depthFunc, depthMask ? 1 : 0, scissor ? 1 : 0, box[0], box[1], box[2], box[3], vp[0],
                vp[1], vp[2], vp[3], colorMask[0] ? 1 : 0, colorMask[1] ? 1 : 0, colorMask[2] ? 1 : 0,
                colorMask[3] ? 1 : 0, sampler);
}

// One-shot per GUI program. The loading screen's logo/text are the only draws
// that use the GUI programs but show no texture, so the shader's sampler unit,
// the VAO's attribute formats and the bound buffers are what distinguish a
// missing upload from a bad UV stream. Queried through GLES (the driver), not
// this layer's wrappers, so the answer is the state the draw will actually use.
static void mg_ui_state_diag(GLuint program) {
    if (!mg_draw_trace_on()) return;

    GLint vao = 0;
    GLES.glGetIntegerv(GL_VERTEX_ARRAY_BINDING, &vao);
    LOG_W_FORCE("[MGUIDIAG] prog=%u vao=%d appVao=%u realVao=%u", program, vao, find_bound_array(),
                find_real_array(find_bound_array()));
    mg_ui_draw_state_diag();
    mg_ui_program_diag(program);

    for (GLuint i = 0; i < 4; ++i) {
        GLint en = 0, size = 0, type = 0, stride = 0, norm = 0, buf = 0, bind = 0, rel = 0;
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_ENABLED, &en);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_SIZE, &size);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_TYPE, &type);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_STRIDE, &stride);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_NORMALIZED, &norm);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING, &buf);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_BINDING, &bind);
        GLES.glGetVertexAttribiv(i, GL_VERTEX_ATTRIB_RELATIVE_OFFSET, &rel);
        GLfloat cur[4] = {0, 0, 0, 0};
        GLES.glGetVertexAttribfv(i, GL_CURRENT_VERTEX_ATTRIB, cur);
        LOG_W_FORCE("[MGUIDIAG]   a%u en=%d size=%d type=0x%X stride=%d norm=%d buf=%d bind=%d rel=%d "
                    "cur=%.3f,%.3f,%.3f,%.3f",
                    i, en, size, type, stride, norm, buf, bind, rel, cur[0], cur[1], cur[2], cur[3]);
    }

    GLint maxBindings = 0;
    GLES.glGetIntegerv(GL_MAX_VERTEX_ATTRIB_BINDINGS, &maxBindings);
    if (maxBindings > 4) maxBindings = 4;
    for (GLint b = 0; b < maxBindings; ++b) {
        GLint buf = 0, offset = 0, stride = 0, divisor = 0;
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_BUFFER, b, &buf);
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_OFFSET, b, &offset);
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_STRIDE, b, &stride);
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_DIVISOR, b, &divisor);
        LOG_W_FORCE("[MGUIDIAG]   binding %d buf=%d off=%d stride=%d div=%d", b, buf, offset, stride, divisor);
    }

    // The GUI programs share the interleaved position/UV/colour stream. Reading
    // the first vertices of binding 0 says whether the UVs the shader will
    // consume are actually there, which the attribute queries above cannot
    // answer: with glVertexArrayAttribFormat the per-attribute stride is always
    // 0 and the binding's stride/offset carry the layout. Four vertices are
    // enough to see a whole quad; the old eight words only covered two and a
    // half, so an all-zero UV pair in vertices 2/3 was invisible.
    {
        GLint bindBuf = 0, bindOff = 0, bindStride = 0;
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_BUFFER, 0, &bindBuf);
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_OFFSET, 0, &bindOff);
        GLES.glGetIntegeri_v(GL_VERTEX_BINDING_STRIDE, 0, &bindStride);
        const GLuint real = bindBuf ? find_real_buffer(static_cast<GLuint>(bindBuf)) : 0;
        if (real && bindStride > 0 && bindStride <= 256) {
            GLint prevArray = 0;
            GLES.glGetIntegerv(GL_ARRAY_BUFFER_BINDING, &prevArray);
            GLES.glBindBuffer(GL_ARRAY_BUFFER, real);
            const GLsizeiptr mapBytes = static_cast<GLsizeiptr>(bindStride) * 4;
            void* map = GLES.glMapBufferRange(GL_ARRAY_BUFFER, bindOff, mapBytes, GL_MAP_READ_BIT);
            if (map) {
                unsigned int w[32] = {};
                const size_t copy = mapBytes < static_cast<GLsizeiptr>(sizeof(w)) ? static_cast<size_t>(mapBytes)
                                                                                   : sizeof(w);
                memcpy(w, map, copy);
                LOG_W_FORCE("[MGUIDIAG]   vbuf real=%u off=%d stride=%d bytes=%u w0=%08X w1=%08X w2=%08X w3=%08X "
                            "w4=%08X w5=%08X w6=%08X w7=%08X",
                            real, bindOff, bindStride, static_cast<unsigned>(copy), w[0], w[1], w[2], w[3], w[4], w[5],
                            w[6], w[7]);
                if (copy > 32) {
                    LOG_W_FORCE("[MGUIDIAG]   vbuf2 w8=%08X w9=%08X w10=%08X w11=%08X w12=%08X w13=%08X w14=%08X "
                                "w15=%08X w16=%08X w17=%08X w18=%08X w19=%08X w20=%08X w21=%08X w22=%08X w23=%08X",
                                w[8], w[9], w[10], w[11], w[12], w[13], w[14], w[15], w[16], w[17], w[18], w[19],
                                w[20], w[21], w[22], w[23]);
                }
                GLES.glUnmapBuffer(GL_ARRAY_BUFFER);
            } else {
                LOG_W_FORCE("[MGUIDIAG]   vbuf real=%u off=%d stride=%d map failed err=0x%X", real, bindOff, bindStride,
                            GLES.glGetError());
            }
            GLES.glBindBuffer(GL_ARRAY_BUFFER, static_cast<GLuint>(prevArray));
        } else {
            LOG_W_FORCE("[MGUIDIAG]   vbuf real=%u off=%d stride=%d unusable", real, bindOff, bindStride);
        }
    }

    GLint uniforms = 0;
    GLES.glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &uniforms);
    for (GLint i = 0; i < uniforms; ++i) {
        GLchar name[128];
        GLsizei nameLen = 0;
        GLint arraySize = 0;
        GLenum type = 0;
        GLES.glGetActiveUniform(program, (GLuint)i, sizeof(name), &nameLen, &arraySize, &type, name);
        if (type != GL_SAMPLER_2D && type != GL_INT_SAMPLER_2D && type != GL_UNSIGNED_INT_SAMPLER_2D) continue;
        const GLint loc = GLES.glGetUniformLocation(program, name);
        GLint unit = -1;
        if (loc >= 0) GLES.glGetUniformiv(program, loc, &unit);
        GLuint tex = 0;
        if (unit >= 0) mg_driver_texture_binding_at_unit(unit, GL_TEXTURE_2D, &tex);
        LOG_W_FORCE("[MGUIDIAG]   sampler %s loc=%d unit=%d tex=%u", name, loc, unit, tex);
    }
}

void mg_draw_trace_note() {
    if (!mg_draw_trace_on()) return;
    mg_draw_trace_rec_t& rec = g_draw_ring[g_draw_ring_pos];
    rec.program = gl_state->current_program;
    rec.fbo = gl_state->current_draw_fbo;
    rec.drvFbo = mg_draw_trace_drv_draw_fbo();
    GLuint tex0 = 0;
    if (!mg_driver_texture_binding_at_unit(0, GL_TEXTURE_2D, &tex0)) tex0 = 0;
    rec.tex0 = tex0;
    rec.att0 = mg_draw_trace_att0(rec.fbo);
    rec.kind = 0;
    rec.what = 0;
    rec.srcFbo = 0;
    rec.count = rec.instances = 0;
    rec.mode = 0;

    // FBO 4 is the GUI's. Log the first draw of each program that reaches it
    // once, while the state is the state that draw is about to use.
    if (rec.fbo == 4) {
        static GLuint loggedPrograms[8] = {};
        static int loggedCount = 0;
        bool seen = false;
        for (int i = 0; i < loggedCount; ++i) {
            if (loggedPrograms[i] == rec.program) {
                seen = true;
                break;
            }
        }
        if (!seen && loggedCount < 8) {
            loggedPrograms[loggedCount++] = rec.program;
            mg_ui_state_diag(rec.program);
        }
    }

    g_draw_ring_pos = (g_draw_ring_pos + 1) % kDrawTraceRing;
    if (g_draw_ring_count < kDrawTraceRing) ++g_draw_ring_count;
    ++g_draw_frame_total;
}

// Notes a draw that reaches the driver through a gl_native.cpp passthrough
// (glDrawArrays and its instanced/indirect forms, glDrawElementsIndirect).
// Nothing is emulated for those, but they are where the world's geometry goes,
// so without them in the ring the GUI's position relative to the terrain --
// before it, after it, on top of it -- cannot be seen.
void mg_draw_trace_note_native(unsigned int count, unsigned int instances, unsigned int mode, char what) {
    if (!mg_draw_trace_on()) return;
    mg_draw_trace_rec_t& rec = g_draw_ring[g_draw_ring_pos];
    rec.program = gl_state->current_program;
    rec.fbo = gl_state->current_draw_fbo;
    rec.drvFbo = mg_draw_trace_drv_draw_fbo();
    GLuint tex0 = 0;
    if (!mg_driver_texture_binding_at_unit(0, GL_TEXTURE_2D, &tex0)) tex0 = 0;
    rec.tex0 = tex0;
    rec.att0 = mg_draw_trace_att0(rec.fbo);
    rec.kind = 2;
    rec.what = what;
    rec.srcFbo = 0;
    rec.mask = 0;
    rec.err = 0;
    rec.count = (GLint)count;
    rec.instances = (GLint)instances;
    rec.mode = mode;
    g_draw_ring_pos = (g_draw_ring_pos + 1) % kDrawTraceRing;
    if (g_draw_ring_count < kDrawTraceRing) ++g_draw_ring_count;
    ++g_draw_frame_total;
}

void mg_draw_trace_note_blit(unsigned int srcFbo, unsigned int dstFbo, unsigned int mask) {
    if (!mg_draw_trace_on()) return;
    mg_draw_trace_rec_t& rec = g_draw_ring[g_draw_ring_pos];
    rec.kind = 1;
    rec.what = 0;
    rec.srcFbo = srcFbo;
    rec.fbo = dstFbo;
    rec.program = 0;
    rec.tex0 = 0;
    rec.drvFbo = mg_draw_trace_drv_read_fbo();
    rec.count = rec.instances = 0;
    rec.mode = 0;
    rec.mask = mask;
    rec.err = 0; // filled a moment later via mg_draw_trace_note_blit_error
    // att0 of the src: the texture being copied toward the window. A mismatch
    // against the draws just before it is the present-reading-a-different-
    // texture case.
    rec.att0 = mg_draw_trace_att0(srcFbo);
    g_draw_ring_pos = (g_draw_ring_pos + 1) % kDrawTraceRing;
    if (g_draw_ring_count < kDrawTraceRing) ++g_draw_ring_count;
    ++g_draw_frame_total;
}

// Called by glBlitFramebuffer after the driver call so the dumped record carries
// the real error rather than a placeholder.
void mg_draw_trace_note_blit_error(unsigned int err) {
    if (!mg_draw_trace_on()) return;
    // The ring position was already advanced; the blit record is the previous
    // slot (or the very last one when the ring is full-ish).
    unsigned idx = (g_draw_ring_pos + kDrawTraceRing - 1) % kDrawTraceRing;
    if (g_draw_ring[idx].kind == 1) g_draw_ring[idx].err = err;
}

void mg_draw_trace_dump(int swap_index) {
    if (!mg_draw_trace_on()) return;
    const unsigned total = (unsigned)g_draw_frame_total;
    const unsigned count = g_draw_ring_count;
    LOG_W_FORCE("[MGDRAW] frame before swap #%d: draws=%u (tail %u)", swap_index, total, count)
    // Oldest first: the ring wraps, so the oldest of `count` entries is
    // pos-count for a full ring and 0 otherwise.
    const unsigned start = (count == kDrawTraceRing) ? g_draw_ring_pos : 0;
    for (unsigned i = 0; i < count; ++i) {
        const mg_draw_trace_rec_t& r = g_draw_ring[(start + i) % kDrawTraceRing];
        if (r.kind == 1) {
            LOG_W_FORCE("[MGDRAW]   %u: BLIT src=%u att0=%u drv=%u -> dst=%u mask=0x%x err=0x%x", i, r.srcFbo, r.att0,
                        r.drvFbo, r.fbo, r.mask, r.err)
        } else if (r.kind == 2) {
            LOG_W_FORCE("[MGDRAW]   %u: NATIVE(%c) prog=%u fbo=%u drv=%u tex0=%u att0=%u n=%d i=%d m=0x%x", i, r.what,
                        r.program, r.fbo, r.drvFbo, r.tex0, r.att0, r.count, r.instances, r.mode)
        } else {
            LOG_W_FORCE("[MGDRAW]   %u: prog=%u fbo=%u drv=%u tex0=%u att0=%u", i, r.program, r.fbo, r.drvFbo, r.tex0,
                        r.att0)
        }
    }
    mg_draw_trace_dump_fbo_tables(swap_index);
    g_draw_ring_pos = 0;
    g_draw_ring_count = 0;
    g_draw_frame_total = 0;
}

void prepareForDraw() {
    LOG_D("prepareForDraw...")
    mg_draw_trace_note();
    if (hardware->emulate_texture_buffer) {
        setupBufferTextureUniforms(gl_state->current_program);
    }
}

void glDrawElementsInstanced(GLenum mode, GLsizei count, GLenum type, const void* indices, GLsizei primcount) {
    LOG()
    LOG_D("glDrawElementsInstanced, mode: %d, count: %d, type: %d, indices: %p, primcount: %d", mode, count, type,
          indices, primcount)
    prepareForDraw();
    if (mg_restart_needs_rewrite(type) && mg_draw_elements_restart(mode, count, type, indices, 0, primcount)) return;
    const bool restart_fixed = mg_restart_needs_driver_fixed(type);
    if (restart_fixed) GLES.glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    GLES.glDrawElementsInstanced(mode, count, type, indices, primcount);
    if (restart_fixed) GLES.glDisable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    CHECK_GL_ERROR
}

void glDrawElements(GLenum mode, GLsizei count, GLenum type, const void* indices) {
    LOG()
    LOG_D("glDrawElements, mode: %d, count: %d, type: %d, indices: %p", mode, count, type, indices)
    prepareForDraw();
    if (mg_restart_needs_rewrite(type) && mg_draw_elements_restart(mode, count, type, indices, 0, -1)) return;
    const bool restart_fixed = mg_restart_needs_driver_fixed(type);
    if (restart_fixed) GLES.glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    GLES.glDrawElements(mode, count, type, indices);
    if (restart_fixed) GLES.glDisable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    CHECK_GL_ERROR
}

void glBindImageTexture(GLuint unit, GLuint texture, GLint level, GLboolean layered, GLint layer, GLenum access,
                        GLenum format) {
    LOG()
    LOG_D("glBindImageTexture, unit: %d, texture: %d, level: %d, layered: %d, layer: %d, access: %d, format: %d", unit,
          texture, level, layered, layer, access, format)
    GLES.glBindImageTexture(unit, texture, level, layered, layer, access, format);
    CHECK_GL_ERROR
}

void glUniform1i(GLint location, GLint v0) {
    LOG()
    LOG_D("glUniform1i, location: %d, v0: %d", location, v0)
    GLES.glUniform1i(location, v0);
    CHECK_GL_ERROR
}

void glDispatchCompute(GLuint num_groups_x, GLuint num_groups_y, GLuint num_groups_z) {
    LOG()
    LOG_D("glDispatchCompute, num_groups_x: %d, num_groups_y: %d, num_groups_z: %d", num_groups_x, num_groups_y,
          num_groups_z)
    GLES.glDispatchCompute(num_groups_x, num_groups_y, num_groups_z);
    CHECK_GL_ERROR
}

void glMemoryBarrier(GLbitfield barriers) {
    LOG()
    LOG_D("glMemoryBarrier, barriers: %d", barriers)
    GLES.glMemoryBarrier(barriers);
    CHECK_GL_ERROR
}

namespace {

// Scratch index buffer for the base-vertex emulation below, and the context that
// owns it. Modeled on gl/restart.cpp's g_restart_ibo, including the invalidation:
// thread_local because g_current_ctx is, so two threads with different current
// contexts keep their own name instead of trading one back and forth.
thread_local GLuint g_basevertex_ibo = 0;
thread_local unsigned long long g_basevertex_owner_ctx_id = 0;

// Drop the cached name when the current context is not the one that created it.
//
// Deliberately no glDeleteBuffers: if the owning context is gone the buffer went
// with it, and if it is merely not current then this name refers to a buffer
// belonging to whichever context *is* current -- the glBufferData below would
// overwrite that buffer's contents.
void basevertex_check_context() {
    const unsigned long long cur = g_current_ctx ? g_current_ctx->id : 0;
    if (cur == g_basevertex_owner_ctx_id) return;
    g_basevertex_ibo = 0;
    g_basevertex_owner_ctx_id = cur;
}

// Staging for the rebased index stream. Elements are GLuint so the storage is
// always aligned for the widest index type it has to hold; the length is in whole
// GLuints, rounded up. Grown and never shrunk, so a steady stream of draws
// allocates nothing -- this used to be a malloc and a free per call.
thread_local std::vector<GLuint> g_basevertex_staging;

void* basevertex_staging(size_t bytes) {
    // Grown only. A plain resize() to the exact length shrinks after a small draw
    // and then value-initialises the difference on the next large one -- a memset
    // of the whole tail that the caller's memcpy overwrites immediately. Only the
    // first `bytes` bytes are ever read, so what is past them is out of range in
    // the same way it is in gl/multidraw.cpp and gl/restart.cpp.
    const size_t need = (bytes + sizeof(GLuint) - 1) / sizeof(GLuint);
    if (g_basevertex_staging.size() < need) g_basevertex_staging.resize(need);
    return g_basevertex_staging.data();
}

} // namespace

void glDrawElementsBaseVertex(GLenum mode, GLsizei count, GLenum type, const void* indices, GLint basevertex) {
    LOG()
    LOG_D("glDrawElementsBaseVertex, mode: %d, count: %d, type: %d, indices: %p, basevertex: %d", mode, count, type,
          indices, basevertex);
    prepareForDraw();
    // The rewrite applies the base vertex itself, so it covers both the emulated
    // and the driver-supported branch below.
    if (mg_restart_needs_rewrite(type) && mg_draw_elements_restart(mode, count, type, indices, basevertex, -1)) return;
    const bool restart_fixed = mg_restart_needs_driver_fixed(type);
    if (restart_fixed) GLES.glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    struct RestartGuard {
        bool on;
        ~RestartGuard() {
            if (on) GLES.glDisable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
        }
    } restart_guard{restart_fixed};
    if (hardware->es_version < 320 && !g_gles_caps.GL_EXT_draw_elements_base_vertex &&
        !g_gles_caps.GL_OES_draw_elements_base_vertex) {
        // TODO: use indirect drawing for GLES 3.1
        LOG_D("Emulating glDrawElementsBaseVertex")
        if (basevertex == 0) {
            GLES.glDrawElements(mode, count, type, indices);
            return;
        }
        if (count <= 0) return;

        size_t indexSize;
        switch (type) {
        case GL_UNSIGNED_INT:
            indexSize = sizeof(GLuint);
            break;
        case GL_UNSIGNED_SHORT:
            indexSize = sizeof(GLushort);
            break;
        case GL_UNSIGNED_BYTE:
            indexSize = sizeof(GLubyte);
            break;
        default:
            return;
        }

        const size_t bytes = static_cast<size_t>(count) * indexSize;

        // The tracked binding rather than a driver round trip. It is the driver's
        // name, so it goes straight back to GLES.glBindBuffer, and it is asked for
        // before the temporary bind below, which is the only window in which this
        // function makes the two disagree. gl/gl.cpp's depth-clear triangle is the
        // one path in the layer that leaves the driver on a vertex array the
        // tracked state does not follow, and the element array binding is vertex
        // array state; see the note on the accessor in gl/buffer.cpp.
        const GLuint prevElementBuffer = mg_driver_bound_buffer(GL_ELEMENT_ARRAY_BUFFER);

        void* tempIndices = basevertex_staging(bytes);

        if (prevElementBuffer != 0) {
            // Redundant on paper -- that buffer is already bound -- but it is what
            // guarantees the map below reads the buffer this call resolved, the
            // same way gl/restart.cpp and gl/multidraw.cpp do it.
            GLES.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, prevElementBuffer);
            // Read-only, and it has to stay a map: gl/buffer.cpp tracks a buffer's
            // size but never its contents, so there is no shadow copy of the index
            // data to rebase from.
            void* srcData =
                GLES.glMapBufferRange(GL_ELEMENT_ARRAY_BUFFER,
                                      static_cast<GLintptr>(reinterpret_cast<uintptr_t>(indices)),
                                      static_cast<GLsizeiptr>(bytes), GL_MAP_READ_BIT);
            if (!srcData) {
                // An immutable or persistently mapped index buffer cannot be read
                // back, and there is no driver base vertex on this path to fall
                // back to. Drop the draw rather than place the geometry at the
                // wrong vertices.
                return;
            }
            memcpy(tempIndices, srcData, bytes);
            GLES.glUnmapBuffer(GL_ELEMENT_ARRAY_BUFFER);
        } else {
            if (!indices) return;
            memcpy(tempIndices, indices, bytes);
        }

        switch (type) {
        case GL_UNSIGNED_INT:
            for (GLsizei j = 0; j < count; ++j) {
                ((GLuint*)tempIndices)[j] += basevertex;
            }
            break;
        case GL_UNSIGNED_SHORT:
            for (GLsizei j = 0; j < count; ++j) {
                ((GLushort*)tempIndices)[j] += basevertex;
            }
            break;
        case GL_UNSIGNED_BYTE:
            for (GLsizei j = 0; j < count; ++j) {
                ((GLubyte*)tempIndices)[j] += basevertex;
            }
            break;
        }

        // One persistent scratch buffer instead of a glGenBuffers/glDeleteBuffers
        // pair per draw call.
        basevertex_check_context();
        if (!g_basevertex_ibo) GLES.glGenBuffers(1, &g_basevertex_ibo);
        GLES.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, g_basevertex_ibo);
        GLES.glBufferData(GL_ELEMENT_ARRAY_BUFFER, static_cast<GLsizeiptr>(bytes), tempIndices, GL_STREAM_DRAW);

        GLES.glDrawElements(mode, count, type, nullptr);

        GLES.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, prevElementBuffer);

        CHECK_GL_ERROR
    } else {
        GLES.glDrawElementsBaseVertex(mode, count, type, indices, basevertex);
    }
    CHECK_GL_ERROR
}

#define DR_WARN_ONCE(...)                                                                                              \
    do {                                                                                                               \
        static bool mg_dr_warned = false;                                                                              \
        if (!mg_dr_warned) {                                                                                           \
            mg_dr_warned = true;                                                                                       \
            LOG_W_FORCE(__VA_ARGS__)                                                                                   \
        }                                                                                                              \
    } while (0)

// ---------------------------------------------------------------------------
// The rest of the indexed draw family
//
// These were pass-throughs in gl/gl_native.cpp, so GL_PRIMITIVE_RESTART with a
// custom index went straight to a driver that has no such feature and every
// restart in the batch was drawn as ordinary geometry -- strips joined end to
// end. They are indexed draws like the three above and owe the same treatment:
// rewrite the stream when the chosen value is not the fixed one, and otherwise
// switch the driver's fixed-index restart on for the duration.
// ---------------------------------------------------------------------------

// Brackets a draw with GLES' fixed-index restart. Scoped so an early return
// cannot leave it enabled behind the application's back.
namespace {
struct restart_guard_t {
    bool on;
    explicit restart_guard_t(GLenum type) : on(mg_restart_needs_driver_fixed(type)) {
        if (on) GLES.glEnable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    }
    ~restart_guard_t() {
        if (on) GLES.glDisable(GL_PRIMITIVE_RESTART_FIXED_INDEX);
    }
    restart_guard_t(const restart_guard_t&) = delete;
    restart_guard_t& operator=(const restart_guard_t&) = delete;
};
} // namespace

void glDrawRangeElements(GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type, const void* indices) {
    LOG()
    LOG_D("glDrawRangeElements, mode: %d, start: %u, end: %u, count: %d, type: %d", mode, start, end, count, type)
    prepareForDraw();
    // The rewritten stream is 32-bit with 0xFFFFFFFF sentinels, so start/end no
    // longer describe it. They are only a promise about the index range, and
    // dropping the promise is allowed; drawing the wrong primitives is not.
    if (mg_restart_needs_rewrite(type) && mg_draw_elements_restart(mode, count, type, indices, 0, -1)) return;
    restart_guard_t guard(type);
    GLES.glDrawRangeElements(mode, start, end, count, type, indices);
    CHECK_GL_ERROR
}

void glDrawRangeElementsBaseVertex(GLenum mode, GLuint start, GLuint end, GLsizei count, GLenum type,
                                   const void* indices, GLint basevertex) {
    LOG()
    LOG_D("glDrawRangeElementsBaseVertex, mode: %d, count: %d, type: %d, basevertex: %d", mode, count, type, basevertex)
    prepareForDraw();
    if (mg_restart_needs_rewrite(type) && mg_draw_elements_restart(mode, count, type, indices, basevertex, -1)) return;
    restart_guard_t guard(type);
    if (GLES.glDrawRangeElementsBaseVertex) {
        GLES.glDrawRangeElementsBaseVertex(mode, start, end, count, type, indices, basevertex);
    } else {
        // glDrawElementsBaseVertex above already emulates the base vertex when
        // the driver cannot; the range is the only thing lost.
        glDrawElementsBaseVertex(mode, count, type, indices, basevertex);
    }
    CHECK_GL_ERROR
}

void glDrawElementsInstancedBaseVertex(GLenum mode, GLsizei count, GLenum type, const void* indices,
                                       GLsizei instancecount, GLint basevertex) {
    LOG()
    LOG_D("glDrawElementsInstancedBaseVertex, mode: %d, count: %d, type: %d, instancecount: %d, basevertex: %d", mode,
          count, type, instancecount, basevertex)
    prepareForDraw();
    if (mg_restart_needs_rewrite(type) &&
        mg_draw_elements_restart(mode, count, type, indices, basevertex, instancecount))
        return;
    restart_guard_t guard(type);
    if (GLES.glDrawElementsInstancedBaseVertex) {
        GLES.glDrawElementsInstancedBaseVertex(mode, count, type, indices, instancecount, basevertex);
    } else if (basevertex == 0) {
        GLES.glDrawElementsInstanced(mode, count, type, indices, instancecount);
    } else {
        DR_WARN_ONCE("glDrawElementsInstancedBaseVertex: no base vertex support on this context, drawing without it");
        GLES.glDrawElementsInstanced(mode, count, type, indices, instancecount);
    }
    CHECK_GL_ERROR
}

// ---------------------------------------------------------------------------
// The base instance family (GL 4.2 / ARB_base_instance)
//
// GLES has no base instance in core, and no extension for it on the drivers
// this layer targets, so these three were stubs in gl/gl_stub.cpp: called, they
// drew nothing at all. That is the worst of the available options -- a mesh that
// silently never appears is harder to diagnose than one in the wrong place, and
// baseinstance is 0 in the overwhelming majority of calls, where these commands
// are exactly the ones GLES already implements.
//
// So they forward, and a non-zero base instance is reported once and then
// ignored. The instanced attribute fetch then starts at element 0 instead of
// baseinstance, which is wrong for that case only, and stays visible.
// ---------------------------------------------------------------------------

void glDrawArraysInstancedBaseInstance(GLenum mode, GLint first, GLsizei count, GLsizei instancecount,
                                       GLuint baseinstance) {
    LOG()
    LOG_D("glDrawArraysInstancedBaseInstance, mode: %d, first: %d, count: %d, instancecount: %d, baseinstance: %u",
          mode, first, count, instancecount, baseinstance)
    if (baseinstance != 0) {
        DR_WARN_ONCE("glDrawArraysInstancedBaseInstance: baseinstance %u ignored, GLES has no base instance",
                     baseinstance);
    }
    prepareForDraw();
    GLES.glDrawArraysInstanced(mode, first, count, instancecount);
    CHECK_GL_ERROR
}

void glDrawElementsInstancedBaseInstance(GLenum mode, GLsizei count, GLenum type, const void* indices,
                                         GLsizei instancecount, GLuint baseinstance) {
    LOG()
    LOG_D("glDrawElementsInstancedBaseInstance, mode: %d, count: %d, type: %d, instancecount: %d, baseinstance: %u",
          mode, count, type, instancecount, baseinstance)
    if (baseinstance != 0) {
        DR_WARN_ONCE("glDrawElementsInstancedBaseInstance: baseinstance %u ignored, GLES has no base instance",
                     baseinstance);
    }
    glDrawElementsInstanced(mode, count, type, indices, instancecount);
}

void glDrawElementsInstancedBaseVertexBaseInstance(GLenum mode, GLsizei count, GLenum type, const void* indices,
                                                   GLsizei instancecount, GLint basevertex, GLuint baseinstance) {
    LOG()
    LOG_D("glDrawElementsInstancedBaseVertexBaseInstance, mode: %d, count: %d, basevertex: %d, baseinstance: %u", mode,
          count, basevertex, baseinstance)
    if (baseinstance != 0) {
        DR_WARN_ONCE(
            "glDrawElementsInstancedBaseVertexBaseInstance: baseinstance %u ignored, GLES has no base instance",
            baseinstance);
    }
    glDrawElementsInstancedBaseVertex(mode, count, type, indices, instancecount, basevertex);
}
