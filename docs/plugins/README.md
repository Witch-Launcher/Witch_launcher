# Witch Plugins

Witch plugins are signed `.plgw` packages that extend the launcher with declarative settings, theme colors, JavaScript, and optionally native code. Every package must include a valid ECDSA P-256 signature and a complete checksum manifest. The package must also declare an open-source license and a public source-code URL.

## Package layout

```text
hello-1.0.0.plgw
├── witch-plugin.json
├── checksums.json
├── witch-plugin.sig
├── main.js
└── theme.json
```

The package root must contain `witch-plugin.json`, `checksums.json`, and `witch-plugin.sig`. All other files must be listed in `checksums.json`.

## Install flow

1. Copy the `.plgw` file to the device.
2. Open `Settings > Plugins`.
3. Tap `+` and choose the package.
4. Wait for the registry verification to complete.
5. Review the verified package details.
6. Confirm the install and restart the launcher.

The launcher verifies the package signature and every checksum locally, then queries the Witch registry before installing. Only registry-verified builds can be installed. If the registry is unavailable or the build is not verified, the install is rejected.

## Plugin states

| State | Meaning |
| --- | --- |
| Unverified | Signature and checksums are valid, but the build is not verified by the registry. |
| Verified | The registry verified this exact checksum set and package hash. |
| Revoked | The registry revoked this build. The launcher disables it. |
| Invalid | The registry rejected the build, or the package no longer matches the verified checksums. |

Only builds verified by the Witch registry are installable. A self-signed package can be inspected locally, but it must be submitted and verified by the registry before the launcher will install it.

## Safe mode

Safe mode skips every plugin at launch. It is enabled manually by creating `SAFE_MODE` in the launcher's hidden data directory, or automatically after repeated runtime failures.

Runtime loading uses a marker per plugin. If a plugin fails while loading, the launcher increments its crash count. At two failures the launcher enters safe mode.

## Plugin configuration

The launcher stores user-facing plugin configuration in `plugins.json` in the launcher's visible app directory (`POJAV_HOME/plugins.json`). The launch log prints the exact path. The file is created automatically and is safe to edit while the launcher is stopped.

```json
{
  "version": 1,
  "plugins": {
    "com.example.hello": {
      "enabled": true,
      "settings": {
        "accent": "#7c5cff"
      },
      "features": {
        "experimental-ui": false
      }
    }
  }
}
```

- `enabled` controls whether the plugin loads at launch.
- `settings` overrides the plugin's normal settings.
- `features` exposes `feature.<name>` values through the plugin settings API, for example `Witch.getSetting("feature.experimental-ui", true)` or native `get_setting("feature.experimental-ui")`.

If a plugin misbehaves but the launcher does not detect the failure, set `enabled` to `false` in this file and restart. An invalid JSON file is left untouched and reported in the launch log; the launcher falls back to each plugin's internal state.

## Runtime support

| Entrypoint | Status |
| --- | --- |
| `js` | Supported with a restricted JavaScriptCore bridge. |
| `native` | Supported when the launcher can load unsigned or developer-signed dylibs. Can register a custom `WitchRootHost` root through ABI 2. |
| `ui` | Reserved. Theme files are applied; layout injection is not implemented. |
| `java` | Registered and logged, but not executed in this build. |

Native plugins are the highest-risk extension type. They run in the launcher process and cannot be safely sandboxed. Install only code you trust and can rebuild from its published source.

## Tooling

```sh
python3 scripts/plugins/pack_plugin.py --generate-key ./keys/private.pem --key-id dev-example
python3 scripts/plugins/pack_plugin.py --source examples/plugins/hello --private-key ./keys/private.pem --key-id dev-example --out ./hello-1.0.0.plgw
python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

See [manifest.md](manifest.md), [security.md](security.md), [api.md](api.md), [publishing.md](publishing.md), and [server.md](server.md).
