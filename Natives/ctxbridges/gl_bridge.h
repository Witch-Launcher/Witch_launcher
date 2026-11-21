#pragma once

#include <EGL/egl.h>

typedef struct {
    PFNEGLBINDAPIPROC eglBindAPI;
    PFNEGLCHOOSECONFIGPROC eglChooseConfig;
    PFNEGLCREATECONTEXTPROC eglCreateContext;
    PFNEGLCREATEWINDOWSURFACEPROC eglCreateWindowSurface;
    PFNEGLDESTROYCONTEXTPROC eglDestroyContext;
    PFNEGLDESTROYSURFACEPROC eglDestroySurface;
    PFNEGLGETCONFIGATTRIBPROC eglGetConfigAttrib;
    PFNEGLCREATEPBUFFERSURFACEPROC eglCreatePbufferSurface;
    PFNEGLGETCONFIGSPROC eglGetConfigs;
    PFNEGLGETCURRENTCONTEXTPROC eglGetCurrentContext;
    PFNEGLGETCURRENTSURFACEPROC eglGetCurrentSurface;
    PFNEGLGETDISPLAYPROC eglGetDisplay;
    PFNEGLGETERRORPROC eglGetError;
    PFNEGLGETPLATFORMDISPLAYPROC eglGetPlatformDisplay;
    PFNEGLINITIALIZEPROC eglInitialize;
    PFNEGLMAKECURRENTPROC eglMakeCurrent;
    PFNEGLQUERYSTRINGPROC eglQueryString;
    PFNEGLQUERYSURFACEPROC eglQuerySurface;
    PFNEGLRELEASETHREADPROC eglReleaseThread;
    PFNEGLSWAPBUFFERSPROC eglSwapBuffers;
    PFNEGLSWAPINTERVALPROC eglSwapInterval;
    PFNEGLTERMINATEPROC eglTerminate;
    void* (*eglGetProcAddress)(const char*);
} egl_library;

typedef struct {
    //struct ANativeWindow *nativeSurface;
    EGLConfig  config;
    EGLint     format;
    EGLContext context;
    EGLSurface surface;
} gl_render_window_t;

void set_gl_bridge_tbl();

// Metal EGL image that owns the GL4ES context. Published by pojavInitOpenGL
// as soon as libEGL_angle_metal is loaded — libgl4es's constructor resolves
// its egl* entry points through it during the renderer preload, before
// gl_init()/dlsym_EGL() would otherwise set it.
extern void* g_gl4esEglHandle;

// Must run before any Metal ANGLE entry point (eglInitialize compiles ANGLE's
// default shader library, where the iOS <18 setMathMode: crash happens).
void PLInstallMetalMathModeCompat(void);
