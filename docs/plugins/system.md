# Plugin system

## What plugins are {#overview}
A plugin is a signed archive with the `.plgw` extension. It can add declarative settings, theme colors, JavaScript that runs at launch and — where the platform permits dynamic libraries — native code. Every package must carry a valid ECDSA P-256 signature, a complete checksum manifest, an open-source license and a public source-code URL; the launcher refuses anything that arrives without them.

| Capability | Status |
| --- | --- |
| Declarative settings | Switches, text fields, sliders and pickers rendered from the manifest. Values live in the plugin's `state.json` |
| Theme colors | A `theme.json` with per-color light / dark pairs, applied on top of the launcher palette |
| JavaScript (`js`) | Supported. A restricted JavaScriptCore bridge with the small `Witch` object — see [Plugin development](development.md) |
| Native (`native`) | Supported where the launcher can load unsigned or developer-signed dylibs. ABI 2 can register a custom root view |
| UI (`ui`) | Reserved. Theme files are applied; layout injection is not implemented |
| Java (`java`) | Registered and logged only — the entrypoint is written to the log but not executed in this build |

So today a plugin can theme the launcher, surface its own settings, log to the launch log, adjust theme colors from JavaScript, or (declared as native) run compiled code in the launcher process. It cannot yet inject screens or layout — the `ui` runtime is reserved — and it cannot run Java code.

## Install and manage {#install}
### Install from a file
1. Copy the `.plgw` file to the device.
2. Open Settings → Plugins.
3. Tap <kbd>+</kbd> and choose the package.
4. Wait for the registry verification to complete.
5. Review the verified package details.
6. Confirm the install and restart the launcher.

The launcher verifies the package signature and every checksum locally, then queries the Witch registry before installing. The registry base URL is read from **Settings → Witch base URL** (`witch.proxy_base_url`). A build the registry has not verified cannot be installed; if the registry is unreachable, the install is rejected rather than waved through.

### Install and update from a GitHub repository

Settings → Plugins has an **Available Plugins** section that is filled from a GitHub catalog. A valid repository is all that is needed: the launcher validates the repository, reads the catalog, resolves the packages and pins every download by hash.

Every package follows the same chain of trust, whether it comes from a file, a link or the catalog:

1. The download is pinned by the SHA-256 the catalog publishes.
2. The ES256 signature and the checksum manifest are verified locally.
3. The launcher works out what the plugin is going to execute and grades it.
4. The registry verifies this exact build.

A plugin without findings is installed right after it passes those checks. A plugin that needs attention or is dangerous is shown with its findings first, and the user decides — a dangerous plugin offers **Force Install** with a destructive warning.

An update replaces the installed plugin and keeps its settings and its enabled state. The catalog format and the full flow are documented in [Plugin catalog](catalog.md).

### Install from a link
A web page can hand the launcher a package with `witch://install-plugin?url=…`. The scheme accepts HTTPS; HTTP is only honored for localhost testing. A downloaded package still passes the same signature and checksum validation as a local file — the transport changes nothing about the vetting.

### Configuration in plugins.json
User-facing plugin configuration is stored in `plugins.json` in the launcher's visible app directory (`POJAV_HOME/plugins.json`) — the launch log prints the exact path. The file is created automatically and is safe to edit while the launcher is stopped.

```
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
- `features` exposes `feature.<name>` values through the plugin settings API, for example `Witch.getSetting("feature.experimental-ui", true)`.

An invalid JSON file is left untouched and reported in the launch log; the launcher falls back to each plugin's internal state.

> [!NOTE] If a plugin misbehaves but the launcher does not detect the failure, set `enabled` to `false` in `plugins.json` and restart. Safe mode is the blunter tool: it skips every plugin at launch.

### Safe mode
Safe mode prevents all plugin entrypoints from loading. It is enabled manually by creating `SAFE_MODE` in the launcher's hidden data directory (the legacy `POJAV_HOME/SAFE_MODE` path is also checked), or automatically after repeated runtime failures — each failing load increments the plugin's crash count, and two failures put the launcher into safe mode.

## Verification states {#verification}
Two decisions are kept separate: whether a package is cryptographically valid — signature and checksums — and whether the publisher and this exact build are trusted. The registry answers the second. Every installed plugin is re-checked shortly after launch; an unreachable registry keeps the last known state, while a revoked or rejected result disables the plugin.

| State | Meaning | What the launcher does |
| --- | --- | --- |
| Unverified | Signature and checksums are valid, but the build is not verified by the registry | Surfaces a `developerSigned` warning. Tapping **Trust this developer key** pins the key ID and public key locally; pinned keys are accepted without a warning |
| Verified | The registry verified this exact checksum set and package hash | Installs cleanly. The verdict is tied to the package hash — a verified result for a different hash is treated as **Invalid** |
| Revoked | The registry revoked this build | Disables the plugin at the next verification pass |
| Invalid | The registry rejected the build, or the package no longer matches the verified checksums | Rejects the install, or disables an installed plugin. Before every load the launcher re-verifies signature, signing key pin, checksums, file set and size limits — a stale verified badge cannot bypass local tampering |

> [!IMPORTANT] A package being cryptographically valid and it being trustworthy are different things. Verifying with the public key embedded in the package proves only that the checksum list was signed by the matching private key — not who owns it. Ownership comes from key pinning or registry verification. A self-signed package can be inspected locally, but it must be submitted and verified by the registry before the launcher will install it.

## Behaviour risk and the sandbox {#risk}

Cryptographic validity says a package is intact. It says nothing about what the package does. Before a plugin runs, the launcher reads its manifest and its payload, works out what would be executed and grades the result.

| Risk | Badge | Behavior |
| --- | --- | --- |
| Safe | Green | Installed right away after the verification |
| Warning | Yellow | Installed after the user reviewed the findings |
| Dangerous | Red | Installed only after the user confirmed with **Force Install** |

A plugin that is not safe runs inside the launcher sandbox: native code is blocked, the script runs in its own JavaScriptCore virtual machine with the host escape hatches removed, theme changes are refused and the script is evaluated off the main thread so it cannot freeze the launcher. The sandbox can be lifted from the plugin screen, with a confirmation.

The launcher does not only read the package, it runs it. After the signature and the checksums are verified, the package is rehearsed inside the sandbox for at most three seconds: the script is executed against a recording bridge and the attempts the sandbox refuses are folded into the grade. A native payload is never executed — its capabilities are read from the binary instead.

The full rule set is documented in [Risk analysis and sandbox](risk.md).

## Security posture {#security}
What the launcher checks, and when:

| Check | Behavior |
| --- | --- |
| ES256 signature | Every package is signed with ECDSA P-256 and SHA-256. The signature in `witch-plugin.sig` covers the exact bytes of `checksums.json`; the private key never ships in the package |
| Checksum manifest | `checksums.json` must map every payload file to its SHA-256 hash. Extra files are rejected at install except `checksums.json` and `witch-plugin.sig`; symbolic links and non-regular files are rejected |
| Resource limits | Packages over 32 MB, with more than 2,048 entries, or expanding beyond 128 MB are rejected. Per-plugin `state.json` is capped at 1 MB |
| Key pinning | **Trust this developer key** pins a key ID and public key in local preferences, so future packages from that publisher carry no warning |
| Registry re-checks | Installed plugins are re-checked shortly after launch. An unreachable registry keeps the last known state; a revoked or rejected result disables the plugin |
| Safe-mode crash counters | Each failed load is marked per plugin and increments its crash count. Two failures enable safe mode automatically |
| Catalog hash pinning | A package downloaded from the GitHub catalog must match the SHA-256 the catalog publishes, and the repository must be public and not archived |
| Risk analysis | Every package is read before it is installed. The findings and the list of things the launcher would run are shown to the user |
| Sandbox | A plugin that is graded Warning or Dangerous runs with native code blocked, in an isolated JavaScriptCore machine, off the main thread |

> [!IMPORTANT] Native plugins are the highest-risk extension type. They run in the launcher process and cannot be safely sandboxed, and a native crash can terminate the launcher before recovery code runs. Loaded dylibs stay resident for the rest of the process. The sandbox blocks native code for every plugin that is not graded Safe, so lifting the sandbox is the one action that re-exposes the launcher to the plugin's binary. Install only code you trust and can rebuild from its published source.

### Recommendations
- Build from source and compare the package hash.
- Pin publisher keys only after reviewing the source.
- Prefer JavaScript and theme plugins over native plugins.
- Revoke or uninstall plugins that fail registry verification.
