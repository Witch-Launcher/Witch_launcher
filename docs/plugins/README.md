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
4. Review the name, version, author, license, and source URL.
5. Confirm the install.
6. Restart the launcher.

The launcher verifies the package signature and every checksum before installing. Registry verification runs after installation and updates the status badge.

## Plugin states

| State | Meaning |
| --- | --- |
| Unverified | Signature and checksums are valid, but the build is not verified by the registry. |
| Verified | The registry verified this exact checksum set and package hash. |
| Revoked | The registry revoked this build. The launcher disables it. |
| Invalid | The registry rejected the build, or the package no longer matches the verified checksums. |

A valid self-signed package is installable. It is shown as unverified and signed by a developer key until the publisher key is explicitly trusted or the build is registry-verified.

## Safe mode

Safe mode skips every plugin at launch. It is enabled manually by creating `SAFE_MODE` in the launcher's hidden data directory, or automatically after repeated runtime failures.

Runtime loading uses a marker per plugin. If a plugin fails while loading, the launcher increments its crash count. At two failures the launcher enters safe mode.

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
