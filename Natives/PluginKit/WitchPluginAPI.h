#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WITCH_PLUGIN_ABI_VERSION 2

typedef void *(*WitchPluginRootViewFactory)(void *userdata);

typedef struct WitchPluginHostAPI {
    uint32_t abi_version;
    void *userdata;
    void (*log)(void *userdata, const char *message);
    const char *(*get_setting)(void *userdata, const char *key);
    void (*set_setting)(void *userdata, const char *key, const char *value);
    void (*set_theme_color)(void *userdata, const char *key, const char *hex);
    void (*request_ui_reload)(void *userdata);
    void (*set_root_view_factory)(void *userdata, WitchPluginRootViewFactory factory);
} WitchPluginHostAPI;

typedef int (*WitchPluginInitFn)(const WitchPluginHostAPI *host);

#ifdef __cplusplus
}
#endif
