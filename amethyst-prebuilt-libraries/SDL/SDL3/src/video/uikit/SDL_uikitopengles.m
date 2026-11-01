/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2026 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#include "SDL_internal.h"

#if defined(SDL_VIDEO_DRIVER_UIKIT) && (defined(SDL_VIDEO_OPENGL_ES) || defined(SDL_VIDEO_OPENGL_ES2))

#include "SDL_uikitopengles.h"
#import "SDL_uikitopenglview.h"
#include "SDL_uikitmodes.h"
#include "SDL_uikitwindow.h"
#include "SDL_uikitevents.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_keyboard_c.h"
#include "../../events/SDL_mouse_c.h"
#include "../../power/uikit/SDL_syspower.h"
#include "../../SDL_hints_c.h"
#include <dlfcn.h>

@interface SDLEAGLContext : EAGLContext

// The OpenGL ES context owns a view / drawable.
@property(nonatomic, strong) SDL_uikitopenglview *sdlView;

@end

@implementation SDLEAGLContext

- (void)dealloc
{
    /* When the context is deallocated, its view should be removed from any
     * SDL window that it's attached to. */
    [self.sdlView setSDLWindow:NULL];
}

@end

@interface SDL_LauncherGLContext : NSObject
@property(nonatomic, assign) void *bundle;
@end

@implementation SDL_LauncherGLContext
@end

typedef void *(*SDL_LauncherCreateContextFn)(void *);
typedef void (*SDL_LauncherMakeCurrentFn)(void *);
typedef void (*SDL_LauncherSwapBuffersFn)(void);
static SDL_LauncherCreateContextFn SDL_Launcher_CreateContext;
static SDL_LauncherMakeCurrentFn SDL_Launcher_MakeCurrent;
static SDL_LauncherSwapBuffersFn SDL_Launcher_SwapBuffers;
static __thread void *SDL_LauncherCurrentBundle;

static bool UIKit_LauncherBridgeLoad(void)
{
    static int loaded = -1;
    if (loaded < 0) {
        SDL_Launcher_CreateContext = (SDL_LauncherCreateContextFn)dlsym(RTLD_DEFAULT, "pojavCreateContext");
        SDL_Launcher_MakeCurrent = (SDL_LauncherMakeCurrentFn)dlsym(RTLD_DEFAULT, "pojavMakeCurrent");
        SDL_Launcher_SwapBuffers = (SDL_LauncherSwapBuffersFn)dlsym(RTLD_DEFAULT, "pojavSwapBuffers");
        loaded = (SDL_Launcher_CreateContext && SDL_Launcher_MakeCurrent && SDL_Launcher_SwapBuffers) ? 1 : 0;
        if (loaded == 1) {
            NSLog(@"[SDL] launcher GL bridge active (renderer=%s)",
                  SDL_getenv("AMETHYST_RENDERER") ? SDL_getenv("AMETHYST_RENDERER") : "?");
        } else {
            NSLog(@"[SDL] launcher GL bridge unavailable, using EAGL");
        }
    }
    return loaded == 1;
}

static bool UIKit_LauncherIsContext(SDL_GLContext context)
{
    return context && [(__bridge id)context isKindOfClass:[SDL_LauncherGLContext class]];
}

static void *UIKit_GL_Library;

SDL_FunctionPointer UIKit_GL_GetProcAddress(SDL_VideoDevice *_this, const char *proc)
{
    /* Resolve through the same dispatch entry point LWJGL's GL provider uses
     * (eglGetProcAddress, then OSMesaGetProcAddress) before falling back to
     * dlsym. Resolving glGetError via dlsym while LWJGL resolves it through
     * OSMesaGetProcAddress returns two different stubs for the same function
     * and makes the game reject the backend. */
    typedef SDL_FunctionPointer (*EGLGetProcAddressFn)(const char *);
    typedef SDL_FunctionPointer (*OSMesaGetProcAddressFn)(const char *);
    SDL_FunctionPointer address = NULL;
    if (UIKit_GL_Library) {
        EGLGetProcAddressFn eglGetProcAddress = (EGLGetProcAddressFn)dlsym(UIKit_GL_Library, "eglGetProcAddress");
        if (eglGetProcAddress) {
            address = eglGetProcAddress(proc);
        }
        if (!address) {
            OSMesaGetProcAddressFn osMesaGetProcAddress = (OSMesaGetProcAddressFn)dlsym(UIKit_GL_Library, "OSMesaGetProcAddress");
            if (osMesaGetProcAddress) {
                address = osMesaGetProcAddress(proc);
            }
        }
        if (!address) {
            address = (SDL_FunctionPointer)dlsym(UIKit_GL_Library, proc);
        }
    }
    if (!address) {
        address = (SDL_FunctionPointer)dlsym(RTLD_DEFAULT, proc);
    }
    if (!address) {
        EGLGetProcAddressFn eglGetProcAddress = (EGLGetProcAddressFn)dlsym(RTLD_DEFAULT, "eglGetProcAddress");
        if (eglGetProcAddress) {
            address = eglGetProcAddress(proc);
        }
    }
    if (SDL_strcmp(proc, "glGetError") == 0) {
        NSLog(@"[SDL] glGetError resolved to %p (library %p)", (void *)address, UIKit_GL_Library);
    }
    return address;
}

/*
  note that SDL_GL_DestroyContext makes it current without passing the window
*/
bool UIKit_GL_MakeCurrent(SDL_VideoDevice *_this, SDL_Window *window, SDL_GLContext context)
{
    @autoreleasepool {
        if (UIKit_LauncherIsContext(context)) {
            SDL_LauncherGLContext *launchercontext = (__bridge SDL_LauncherGLContext *)context;
            SDL_Launcher_MakeCurrent(launchercontext.bundle);
            SDL_LauncherCurrentBundle = launchercontext.bundle;
            return true;
        }

        SDLEAGLContext *eaglcontext = (__bridge SDLEAGLContext *)context;

        if (![EAGLContext setCurrentContext:eaglcontext]) {
            return SDL_SetError("Could not make EAGL context current");
        }

        if (eaglcontext) {
            [eaglcontext.sdlView setSDLWindow:window];
        }
    }

    return true;
}

bool UIKit_GL_LoadLibrary(SDL_VideoDevice *_this, const char *path)
{
    (void)_this;
    if (!path || !*path) {
        return true;
    }
    void *library = dlopen(path, RTLD_LAZY | RTLD_GLOBAL);
    if (!library) {
        NSLog(@"[SDL] Could not load OpenGL library %s: %s (falling back to RTLD_DEFAULT)", path, dlerror());
        return true;
    }
    UIKit_GL_Library = library;
    NSLog(@"[SDL] OpenGL library loaded: %s (%p)", path, library);
    return true;
}

bool UIKit_GL_SwapWindow(SDL_VideoDevice *_this, SDL_Window *window)
{
    @autoreleasepool {
        SDL_GLContext current = SDL_GL_GetCurrentContext();
        if (UIKit_LauncherIsContext(current)) {
            SDL_LauncherGLContext *launchercontext = (__bridge SDL_LauncherGLContext *)current;
            if (SDL_LauncherCurrentBundle != launchercontext.bundle) {
                SDL_Launcher_MakeCurrent(launchercontext.bundle);
                SDL_LauncherCurrentBundle = launchercontext.bundle;
            }
            SDL_Launcher_SwapBuffers();
            return true;
        }

        SDLEAGLContext *context = (__bridge SDLEAGLContext *)current;

#ifdef SDL_POWER_UIKIT
        // Check once a frame to see if we should turn off the battery monitor.
        SDL_UIKit_UpdateBatteryMonitoring();
#endif

        [context.sdlView swapBuffers];

        /* You need to pump events in order for the OS to make changes visible.
         * We don't pump events here because we don't want iOS application events
         * (low memory, terminate, etc.) to happen inside low level rendering. */
    }
    return true;
}

SDL_GLContext UIKit_GL_CreateContext(SDL_VideoDevice *_this, SDL_Window *window)
{
    @autoreleasepool {
        if (UIKit_LauncherBridgeLoad()) {
            void *bundle = SDL_Launcher_CreateContext(NULL);
            if (!bundle) {
                SDL_SetError("Launcher GL context creation failed");
                return NULL;
            }

            SDL_LauncherGLContext *launchercontext = [[SDL_LauncherGLContext alloc] init];
            launchercontext.bundle = bundle;
            SDL_LauncherCurrentBundle = bundle;
            return (SDL_GLContext)CFBridgingRetain(launchercontext);
        }

        SDLEAGLContext *context = nil;
        SDL_uikitopenglview *view;
        SDL_UIKitWindowData *data = (__bridge SDL_UIKitWindowData *)window->internal;
        CGRect frame = UIKit_ComputeViewFrame(window, data.uiwindow.screen);
        EAGLSharegroup *sharegroup = nil;
        CGFloat scale = 1.0;
        int samples = 0;
        int major = _this->gl_config.major_version;
        int minor = _this->gl_config.minor_version;

        /* The EAGLRenderingAPI enum values currently map 1:1 to major GLES
         * versions. */
        EAGLRenderingAPI api = major;

        // iOS currently doesn't support GLES >3.0.
        if (major > 3 || (major == 3 && minor > 0)) {
            SDL_SetError("OpenGL ES %d.%d context could not be created", major, minor);
            return NULL;
        }

        if (_this->gl_config.multisamplebuffers > 0) {
            samples = _this->gl_config.multisamplesamples;
        }

        if (_this->gl_config.share_with_current_context) {
            EAGLContext *currContext = (__bridge EAGLContext *)SDL_GL_GetCurrentContext();
            sharegroup = currContext.sharegroup;
        }

        if (window->flags & SDL_WINDOW_HIGH_PIXEL_DENSITY) {
            /* Set the scale to the natural scale factor of the screen - the
             * backing dimensions of the OpenGL view will match the pixel
             * dimensions of the screen rather than the dimensions in points. */
            scale = data.uiwindow.screen.nativeScale;
        }

        context = [[SDLEAGLContext alloc] initWithAPI:api sharegroup:sharegroup];
        if (!context) {
            SDL_SetError("OpenGL ES %d context could not be created", _this->gl_config.major_version);
            return NULL;
        }

        int srgb = _this->gl_config.framebuffer_srgb_capable;
        const char *srgbhint = SDL_GetHint(SDL_HINT_OPENGL_FORCE_SRGB_FRAMEBUFFER);
        if (srgbhint && *srgbhint) {
            srgb = SDL_GetStringBoolean(srgbhint, false) ? 1 : 0;  // there is no "skip" here, since initWithFrame expects it, so we'll treat it as false.
        }

        // construct our view, passing in SDL's OpenGL configuration data
        view = [[SDL_uikitopenglview alloc] initWithFrame:frame
                                                    scale:scale
                                            retainBacking:_this->gl_config.retained_backing
                                                    rBits:_this->gl_config.red_size
                                                    gBits:_this->gl_config.green_size
                                                    bBits:_this->gl_config.blue_size
                                                    aBits:_this->gl_config.alpha_size
                                                depthBits:_this->gl_config.depth_size
                                              stencilBits:_this->gl_config.stencil_size
                                                     sRGB:srgb
                                             multisamples:samples
                                                  context:context];

        if (!view) {
            return NULL;
        }

        SDL_PropertiesID props = SDL_GetWindowProperties(window);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_UIKIT_OPENGL_FRAMEBUFFER_NUMBER, view.drawableFramebuffer);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_UIKIT_OPENGL_RENDERBUFFER_NUMBER, view.drawableRenderbuffer);
        SDL_SetNumberProperty(props, SDL_PROP_WINDOW_UIKIT_OPENGL_RESOLVE_FRAMEBUFFER_NUMBER, view.msaaResolveFramebuffer);

        // The context owns the view / drawable.
        context.sdlView = view;

        if (!UIKit_GL_MakeCurrent(_this, window, (__bridge SDL_GLContext)context)) {
            UIKit_GL_DestroyContext(_this, (SDL_GLContext)CFBridgingRetain(context));
            return NULL;
        }

        /* We return a +1'd context. The window's internal owns the view (via
         * MakeCurrent.) */
        return (SDL_GLContext)CFBridgingRetain(context);
    }
}

bool UIKit_GL_DestroyContext(SDL_VideoDevice *_this, SDL_GLContext context)
{
    @autoreleasepool {
        if (UIKit_LauncherIsContext(context)) {
            SDL_LauncherGLContext *launchercontext = (__bridge SDL_LauncherGLContext *)context;
            SDL_Launcher_MakeCurrent(NULL);
            if (SDL_LauncherCurrentBundle == launchercontext.bundle) {
                SDL_LauncherCurrentBundle = NULL;
            }
            launchercontext.bundle = NULL;
            CFRelease(context);
            return true;
        }

        /* The context was retained in SDL_GL_CreateContext, so we release it
         * here. The context's view will be detached from its window when the
         * context is deallocated. */
        CFRelease(context);
    }
    return true;
}

void UIKit_GL_RestoreCurrentContext(void)
{
    @autoreleasepool {
        if (UIKit_LauncherIsContext(SDL_GL_GetCurrentContext())) {
            return;
        }
        /* Some iOS system functionality (such as Dictation on the on-screen
         keyboard) uses its own OpenGL ES context but doesn't restore the
         previous one when it's done. This is a workaround to make sure the
         expected SDL-created OpenGL ES context is active after the OS is
         finished running its own code for the frame. If this isn't done, the
         app may crash or have other nasty symptoms when Dictation is used.
         */
        EAGLContext *context = (__bridge EAGLContext *)SDL_GL_GetCurrentContext();
        if (context != NULL && [EAGLContext currentContext] != context) {
            [EAGLContext setCurrentContext:context];
        }
    }
}

#endif // SDL_VIDEO_DRIVER_UIKIT
