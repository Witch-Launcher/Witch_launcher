# Plugin APIs

## JavaScript

JavaScript runs in a dedicated `JSContext` per plugin. The global `Witch` object exposes:

| API | Behavior |
| --- | --- |
| `Witch.pluginID` | Current plugin id. |
| `Witch.version` | Current plugin version. |
| `Witch.log(message)` | Writes a prefixed message to the launcher log. |
| `Witch.getSetting(key, fallback)` | Returns the stored setting or `fallback`. |
| `Witch.setSetting(key, value)` | Persists a JSON-serializable setting. |
| `Witch.setThemeColor(key, hex)` | Persists a theme color and reloads the theme. |
| `Witch.reloadTheme()` | Reapplies theme colors. |

There is no DOM, no network API, and no direct access to launcher view controllers. The bridge is intentionally small. JavaScript runs synchronously during launcher startup and must return promptly; it has no execution-time watchdog.

Example:

```js
const greeting = Witch.getSetting("greeting", "Hello");
Witch.log(greeting);
Witch.setThemeColor("amethyst_accent_color", "#7c5cff");
```

### Sandboxed plugins

A plugin that the launcher grades Warning or Dangerous runs inside the sandbox. The rules that change the API are:

| Rule | Effect on the API |
| --- | --- |
| Own `JSVirtualMachine` | The script cannot reach another plugin's objects |
| `eval`, `Function`, `WebKit`, `ObjC`, `PHP` and `importScripts` removed | Those globals are `undefined` inside the script |
| `Witch.setThemeColor` and `Witch.reloadTheme` refused | Theme changes are logged and ignored |
| `Witch.setSetting` still works | The write is serialized onto the main thread, so read it back later rather than immediately |
| Script runs off the main thread | The script must not assume it runs on the main thread, and it cannot block the launcher |

A sandboxed plugin with a `native` entrypoint never loads that entrypoint. The sandbox is described in [Risk analysis and sandbox](risk.md).

### The rehearsal

Before a package is installed, the launcher runs the script once inside the sandbox against a **recording bridge**: the same `Witch` object, but every call is only recorded and nothing is written to the launcher. The dangerous globals answer with a recorder instead of disappearing, so an attempt is visible. A script that never returns is abandoned after three seconds.

What the rehearsal saw is shown on the plugin screen and it feeds the risk grade, so a script that behaves well is installed without a prompt and a script that reaches for the host runtime is not.

## Native

Native entrypoints are `.dylib` files with a `witch_plugin_init` symbol:

```c
#include "WitchPluginAPI.h"

static int plugin_init(const WitchPluginHostAPI *host) {
    host->log(host->userdata, "plugin started");
    return 0;
}

__attribute__((visibility("default")))
int witch_plugin_init(const WitchPluginHostAPI *host) {
    if (!host || host->abi_version != WITCH_PLUGIN_ABI_VERSION) return 1;
    return plugin_init(host);
}
```

Every callback receives `host->userdata`. The launcher allocates one context per plugin, so callbacks resolve settings and theme updates against the correct plugin. Host calls from background threads are marshalled to the main thread. The pointer returned by `get_setting` is valid until the next `get_setting` call on the same thread; copy it before storing.

Return `0` from `witch_plugin_init` on success. A non-zero return records a runtime failure and skips the plugin; the library stays resident for the process lifetime.

### Custom root UI

ABI 2 adds `set_root_view_factory`. A native plugin can replace the launcher root with a `UIViewController` that conforms to `WitchRootHost`:

```objc
#import <UIKit/UIKit.h>

@interface ExampleRootViewController : UIViewController <WitchRootHost>
@end

static void *make_root(void *userdata) {
    return (__bridge_retained void *) [[ExampleRootViewController alloc] init];
}

static int plugin_init(const WitchPluginHostAPI *host) {
    host->set_root_view_factory(host->userdata, make_root);
    return 0;
}
```

The factory returns a retained object; the launcher takes ownership of it for the lifetime of the root. Only the first factory registered during a launch is used. If the plugin is disabled, fails to load, or the factory returns an object that does not conform to `WitchRootHost`, the launcher keeps `AmethystRootViewController`. A custom root is responsible for its own layout and must route actions through `coordinator` where the launcher expects native behavior.

Native plugins are only importable on installations that permit unsigned or developer-signed dynamic libraries. On SideStore and stock iOS, this may require a JIT/dyld bypass. JavaScript and theme plugins do not require native loading.

## Settings

Plugin settings are stored in the plugin's `state.json` and mirrored to `plugins.json` in the launcher's app folder. The launcher merges the global configuration at startup, so a user can disable a plugin or override individual settings manually.

```json
{
  "version": 1,
  "plugins": {
    "com.example.plugin": {
      "enabled": true,
      "settings": { "accent": "#8b5cf6" },
      "features": { "compact_layout": true }
    }
  }
}
```

Keys in `features` are exposed to the plugin as `feature.<name>` settings. Read them with `host->get_setting` or `Witch.getSetting`; values can be strings, numbers, booleans, or JSON objects. The manifest's `settings` array declares defaults and UI controls, while `plugins.json` holds the user's overrides.

## Theme

Theme colors are merged from enabled plugins. Static `theme.json` colors are applied first; `Witch.setThemeColor` overrides are merged afterward. If several plugins define the same key, the last plugin in sorted order wins.

Supported color keys include `amethyst_accent_color`, `amethyst_bg_color`, `amethyst_card_bg_color`, `amethyst_text_color`, `amethyst_secondary_text_color`, `amethyst_sidebar_bg_color`, `amethyst_topbar_bg_color`, `amethyst_rightpanel_bg_color`, and `amethyst_ui_border_color`.

## Java

`entrypoints.java` is recognized and logged. The Java agent and background JVM are not loaded in this build. A Java-only plugin is not considered active.

## Lifecycle

Plugins load once at launcher startup after core initialization. Changes to enablement, settings that affect startup, or newly installed code require a launcher restart. Theme-only setting changes can be applied immediately through the theme bridge.
