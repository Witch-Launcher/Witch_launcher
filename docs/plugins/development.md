# Plugin development

## Package anatomy {#overview}
A `.plgw` is a zip archive with the manifest, a checksum list and a signature at its root; everything else is payload listed in the checksums. All paths must be relative, stay inside the package, and must not contain `..`, backslashes or absolute prefixes — symbolic links are rejected.

| File | Role |
| --- | --- |
| `witch-plugin.json` | Required manifest — identity, license, source, API version, entrypoints and optional settings and theme |
| `checksums.json` | Required. SHA-256 hash of every payload file; the launcher rejects extras outside the checksum list |
| `witch-plugin.sig` | Required. ES256 signature covering the exact bytes of `checksums.json`, with the signing key ID and public key |
| `main.js` | JavaScript entrypoint named by the `js` key in `entrypoints` |
| `libexample.dylib` | Native entrypoint named by the `native` key, exporting `witch_plugin_init` |
| `theme.json` | Theme colors, referenced by `ui.theme` or directly by `ui` |
| `icon.png` / `banner` | Optional images declared by `icon` / `banner` in the manifest |

A minimal manifest — required fields plus one `js` entrypoint — looks like this:

```
{
  "id": "com.example.hello",
  "name": "Hello Witch",
  "version": "1.0.0",
  "license": "MIT",
  "source": "https://github.com/example/hello",
  "api": 1,
  "entrypoints": { "js": "main.js" }
}
```

A theme file maps color keys to hex values. A value may also be an object with `light` and `dark` values:

```
{
  "colors": {
    "amethyst_accent_color": { "light": "#7c5cff", "dark": "#9d7bff" },
    "amethyst_bg_color": "#0b0b12",
    "amethyst_text_color": "#ffffff",
    "amethyst_secondary_text_color": "#b7b7c9"
  }
}
```

## Manifest spec {#manifest}
### Required fields
| Field | Rules |
| --- | --- |
| `id` | Lowercase letters, numbers, dot, underscore or dash; must match `^[a-z0-9][a-z0-9._-]{1,63}$` |
| `name` | Non-empty display name |
| `version` | Numeric components, for example `1.0.0` or `2.1.0-beta.1` |
| `license` | OSI/SPDX open-source identifier from the allowlist below |
| `source` | Public `http` or `https` source-code URL |
| `api` | Plugin API version. This build supports `1` |

### Optional fields
| Field | Purpose |
| --- | --- |
| `author` | Displayed in the install sheet and detail screen |
| `description` | Short summary shown in the plugin list and detail screen |
| `details` | Longer description reserved for detail views |
| `icon` | Safe relative path to a PNG or JPEG image |
| `banner` | Safe relative path to a banner image |
| `permissions` | Declared permissions, currently informational |
| `settings` | Declarative settings schema |
| `entrypoints` | Runtime entrypoints |
| `ui` | A theme path directly (e.g. `"theme.json"`), or `{ "theme": "theme.json" }` |

### License allowlist
The registry verifies only packages that declare one of these SPDX identifiers and a public HTTP(S) source URL. This is an auditability requirement, not a cryptographic guarantee.

`MIT` · `Apache-2.0` · `BSD-2-Clause` · `BSD-3-Clause` · `ISC` · `MPL-2.0` · `GPL-2.0-only` · `GPL-2.0-or-later` · `GPL-3.0-only` · `GPL-3.0-or-later` · `LGPL-2.1-only` · `LGPL-2.1-or-later` · `LGPL-3.0-only` · `LGPL-3.0-or-later` · `AGPL-3.0-only` · `AGPL-3.0-or-later` · `EPL-2.0` · `CC0-1.0` · `Unlicense` · `Zlib`

### Declarative settings
`settings` declares the plugin's own options; the launcher renders them and stores values per plugin in `state.json`. Four input types are supported:

| Type | Extra fields |
| --- | --- |
| `switch` | `default` boolean |
| `text` | `default`, optional `placeholder` |
| `slider` | `default`, `min`, `max` |
| `picker` | `default`, `options` array — strings or `{ "key", "name" }` objects |

Each item carries `key`, `type`, `label` (with `title` accepted as an alias) and optional `description`. A picker looks like:

```
{
  "key": "accent",
  "type": "picker",
  "label": "Accent color",
  "description": "Applied on the next launch.",
  "default": "#7c5cff",
  "options": [
    { "key": "#7c5cff", "name": "Amethyst" },
    { "key": "#ff5c8a", "name": "Rose" }
  ]
}
```

### Entrypoints
| Key | Behavior |
| --- | --- |
| `js` | Executed at launch in a dedicated JavaScriptCore context |
| `native` | Executed at launch where dylibs can load; ABI 2 can register a custom root view controller |
| `java` | Recognized and logged, but not executed in this build. A Java-only plugin is not considered active |
| `ui` | Reserved — theme files are applied, layout injection is not implemented |

> [!NOTE] Judging the runtime support at a glance: `js` and `native` run, `ui` is reserved for a later build, and `java` is logged only. Design plugins around JavaScript and themes for now.

## JavaScript runtime {#javascript}
JavaScript runs in a dedicated `JSContext` per plugin. There is no DOM and no network API — the global `Witch` object is the whole bridge:

| API | Behavior |
| --- | --- |
| `Witch.pluginID` | Current plugin id |
| `Witch.version` | Current plugin version |
| `Witch.log(message)` | Writes a prefixed message to the launcher log |
| `Witch.getSetting(key, fallback)` | Returns the stored setting or `fallback` |
| `Witch.setSetting(key, value)` | Persists a JSON-serializable setting |
| `Witch.setThemeColor(key, hex)` | Persists a theme color and reloads the theme |
| `Witch.reloadTheme()` | Reapplies theme colors |

```
const greeting = Witch.getSetting("greeting", "Hello");
Witch.log(greeting);
Witch.setThemeColor("amethyst_accent_color", "#7c5cff");
```

JavaScript runs synchronously during launcher startup and must return promptly; there is no execution-time watchdog, and there is no direct access to launcher view controllers.

### Settings value mirroring
Plugin settings live in the plugin's `state.json` and are mirrored to `plugins.json` in the launcher's app folder. The launcher merges the global configuration at startup, so a user can disable the plugin or override individual settings manually. Keys under `features` are exposed as `feature.<name>` settings read through `Witch.getSetting` or native `get_setting`; values can be strings, numbers, booleans or JSON objects. The manifest's `settings` array declares defaults and UI controls, while `plugins.json` holds the user's overrides.

### Theme merge rules
Theme colors merge in a fixed order. A user-set accent color in launcher settings wins over the default palette; unless a plugin theme defines the same key, the system setting remains in place — an enabled plugin that defines a color takes precedence over the system setting. Within and across plugins: static `theme.json` colors are applied first, then `Witch.setThemeColor` overrides are merged afterward, and if several plugins define the same key the last plugin in sorted order wins.

Supported color keys include `amethyst_accent_color`, `amethyst_bg_color`, `amethyst_card_bg_color`, `amethyst_text_color`, `amethyst_secondary_text_color`, `amethyst_sidebar_bg_color`, `amethyst_topbar_bg_color`, `amethyst_rightpanel_bg_color` and `amethyst_ui_border_color`.

## Native runtime {#native}
A native entrypoint is a `.dylib` exporting `witch_plugin_init`, called once at launch with the host API table. Every callback receives `host->userdata`; the launcher allocates one context per plugin so settings and theme updates resolve against the right plugin, and host calls from background threads are marshalled to the main thread.

| ABI surface | Behavior |
| --- | --- |
| `witch_plugin_init` | Required export. Check `host->abi_version` against `WITCH_PLUGIN_ABI_VERSION` and return `0` on success; any non-zero return records a runtime failure and skips the plugin — the library stays resident for the process lifetime |
| `host->userdata` | Per-plugin context passed to every callback |
| `host->log` | Writes a prefixed message to the launcher log |
| `host->get_setting` | Returns the stored setting; the pointer is valid until the next `get_setting` call on the same thread — copy it before storing |
| `host->set_root_view_factory` | ABI 2. Registers a factory that supplies the launcher's root view |

```
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

### Custom root UI (ABI 2)
ABI 2 adds `set_root_view_factory`. A native plugin can replace the launcher root with a `UIViewController` conforming to `WitchRootHost`:

```
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

The factory returns a retained object; the launcher takes ownership for the lifetime of the root. Only the first factory registered during a launch is used. If the plugin is disabled, fails to load, or the factory returns an object that does not conform to `WitchRootHost`, the launcher keeps `AmethystRootViewController`. A custom root is responsible for its own layout and must route actions through `coordinator` where the launcher expects native behavior.

> [!NOTE] Native plugins only import on installations that permit unsigned or developer-signed dynamic libraries — on SideStore and stock iOS this may require a JIT / dyld bypass. JavaScript and theme plugins never need native loading.

## Packing and publishing {#publishing}
### Create a key
Packages are signed with ECDSA P-256 and SHA-256 (ES256). Generate a key pair and keep the private key offline; the command prints the base64 public key and the derived key ID.

```
python3 scripts/plugins/pack_plugin.py \
  --generate-key ./keys/example-private.pem \
  --key-id dev-example
```

### Pack the package
The source directory must contain `witch-plugin.json` at its root, and every referenced entrypoint, icon, banner and theme file must exist. The packer writes deterministic checksums and signs `checksums.json`:

```
python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/example-private.pem \
  --key-id dev-example \
  --out ./hello-1.0.0.plgw
```

It prints `artifact_sha256` (SHA-256 of the final `.plgw`), `checksums_sha256` (SHA-256 of the signed `checksums.json`), and the `public_key` and `key_id` needed for submission.

### Verify locally
A self-signed or externally signed package can be checked without the registry:

```
python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

### Submit to the registry
Submit both hashes, the public key and the key ID to the registry worker:

```
curl -X POST https://witch-worker.vvvuduyanh2012.workers.dev/v1/plugins/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "pluginId": "com.witch.example.hello",
    "version": "1.0.0",
    "name": "Hello Witch",
    "license": "MIT",
    "sourceUrl": "https://github.com/example/witch-hello-plugin",
    "artifactSha256": "b536...",
    "checksumsSha256": "efda...",
    "publicKey": "BGRZ...",
    "publisherKeyId": "dev-example"
  }'
```

Required fields: `pluginId`, `version`, `name`, `license`, `sourceUrl`, `artifactSha256`, `checksumsSha256`, `publicKey`, `publisherKeyId`. The server computes no hashes — it stores the publisher-supplied values for review, so before verification confirm the source URL is public and matches the submitted build, the license is allowlisted, the hashes, public key and key ID match the package, and no native behavior is undocumented. Submissions stay `pending` until an administrator verifies or rejects them, and a verified version cannot be overwritten by a later submission — publish a new version instead.

### Registry API summary
| Route | Behavior |
| --- | --- |
| `GET /v1/plugins/verify` | Checks id, version, checksum and artifact hashes, key ID. Returns `verified`, `unverified`, `pending`, `rejected`, `revoked`, `invalid` or `unavailable` |
| `GET /v1/plugins/list` | Returns only verified, non-revoked rows |
| `POST /v1/plugins/submit` | Registers a pending build for review |

The launcher reads the registry base from **Settings → Witch base URL** (`witch.proxy_base_url`); verification is skipped when that setting is empty. If Supabase is not configured on the server, `verify` returns `unavailable`, `list` returns an empty list, and submission routes error out.

### Admin review and deployment
Admin route `GET /admin/plugins?status=pending` and the per-version `/verify`, `/reject` and `/revoke` actions require the `X-Admin-Key` header — `PLUGIN_ADMIN_KEY`, falling back to `ADMIN_PAGE_KEY`; with neither configured the routes return `503` rather than run unauthenticated. Revoked builds are disabled by the launcher on the next verification pass.

Self-hosting the registry: apply `worker/supabase/migrations/007_plugin_registry.sql` to the Supabase project (it creates the `plugin_submissions` and append-only `plugin_audit_log` tables, both with row-level security), set `PLUGIN_ADMIN_KEY` via `wrangler secret put` or the hosting dashboard, and deploy the entry points you use — the Cloudflare Worker (`worker/src/worker.js`) or the Express server (`worker/src/index.js` with `worker/src/routes/plugins.js`). Public registry routes are exempt from bearer and HMAC authentication but remain subject to global rate limiting.
