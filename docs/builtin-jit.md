# Built-in StikJIT

Witch can enable JIT without a second app. The launcher embeds
`WitchJITHelper.appex`, a small Swift app extension that runs
[StikJIT](https://github.com/StikDebug/StikJIT) and attaches to the running
Witch process over the device's RemotePairing service.

This document covers the integration, setup, build and troubleshooting. The
feature is intentionally scoped to **JIT only**; memory entitlements and the
full LocalDevVPN settings screen are separate future work.

## Why a helper extension?

A process cannot synchronously debug itself: attaching a debugger from the app
to its own PID deadlocks. The helper is a separate process, so Witch sends it:

- its PID,
- the remote pairing file,
- `UniversalJIT26.js` (base64),
- the force-script flag.

The helper calls `StikJIT.enableJIT` and stays attached while the script
services `brk #0xf00d` / `#0x6a`. On iOS 26/27 the debugger must stay attached
for the whole game session; on iOS 17/18 the attach/detach alone is enough.

## Requirements

- iOS 17.4 or later for the helper (the launcher still supports iOS 14).
- An installation with `get-task-allow` (SideStore, AltStore, Xcode or a
  development certificate).
- A remote pairing file made with the
  [StikDebug pairing guide](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md).
  Import it in **Settings → Game → JIT**.
- [LocalDevVPN](https://apps.apple.com/us/app/localdevvpn/id6755608044) connected
  and a nearby Wi-Fi network. Without Wi-Fi, enable cellular data, connect
  LocalDevVPN, then enable Airplane Mode before returning to Witch.
- Developer Mode enabled.

Built-in StikJIT is unavailable inside LiveContainer because LiveContainer
cannot create the required helper extension. Use StikDebug there.

## JIT methods

**Settings → Game → JIT → JIT Method**:

| Method | Behavior |
|---|---|
| **Auto** (default) | TrollStore when its JIT entitlement is present, then Built-in StikJIT when a pairing file exists, then StikDebug. |
| **Built-in StikJIT** | Starts the embedded helper. If setup is incomplete, the launch fails with an explicit error and a shortcut to this screen; it never silently falls back. |
| **StikDebug** | Opens `stikdebug://enable-jit` with Witch's bundle ID and PID. On TXM devices the script is sent inline. |
| **Wait for Debugger** | Shows the existing waiting screen until an external debugger attaches. |
| **TrollStore** | Resolved automatically when the TrollStore JIT entitlement is present; asks TrollStore for JIT. |

The developer-defined script is always Witch's `UniversalJIT26.js`. The
**Force JIT Script** toggle only bypasses TXM detection; it does not select a
different script.

## Pairing file

The helper reads a copy stored at:

```
Documents/StikJIT/pairingFile.plist
```

The file is validated when imported: `public_key` and `private_key` must be
32-byte `Data` values and `identifier` must be a non-empty string. Pairing data
is sent to the helper as `Data` in the extension request, written to the
helper's private `Library/StikJIT` directory for the operation, and deleted
when the request ends. It is never logged.

The launcher enables Finder/Files sharing (`UIFileSharingEnabled`), so a
pairing file can also be copied into Documents manually.

## Developer Disk Image

The helper owns the DDI cache in its `Library/StikJIT` directory. The first
preparation downloads and mounts the three-file personalized DDI, or the
five-file cryptex DDI on iOS 26.4+. A successful mount lasts until the device
reboots. **Reset Developer Disk Image** removes the cached files; the next
preparation downloads them again.

## LocalDevVPN

Built-in StikJIT reaches this device through LocalDevVPN's loopback
(`10.7.0.1`). Witch only integrates the URL scheme; it does not embed the VPN
or request a Network Extension entitlement.

- Connect button: `localdevvpn://enable?scheme=witch`
- LocalDevVPN returns to `witch://` after connecting.
- If LocalDevVPN is not installed, Witch opens its App Store page.
- The setup screen probes `10.7.0.1:62078` and `:49152` to show whether the
  tunnel is reachable without reading any VPN status API.

## Build

StikJIT is checked in as a prebuilt `ios-arm64` slice under
`third_party/stikjit`. The helper is generated with XcodeGen and built with
`xcodebuild`; the main app remains a CMake/Makefile build.

```sh
make jit-helper     # stages Witch.app/PlugIns/WitchJITHelper.appex + StikJIT.framework
make package        # or make payload / make deploy
```

The Makefile:

- skips `WitchJITHelper.appex` and `StikJIT.framework` when retagging Mach-O
  files to the app's iOS 14 baseline (both are iOS 17.4+),
- signs the framework and app extension before the main binary,
- validates that both are present before packaging.

Sideloaders must preserve app extensions when re-signing the IPA. If an
installation cannot keep `PlugIns/`, use StikDebug instead.

A free Apple ID may need a separate App ID for `com.witch.zad626.JITHelper`.
If the signer cannot register or keep the extension, Built-in StikJIT is
reported unavailable and Auto falls back to StikDebug; the rest of the launcher
still works.

## Troubleshooting

| Symptom | Check |
|---|---|
| “Built-in StikJIT is unavailable” | iOS 17.4+, helper present in `PlugIns/`, not LiveContainer. Reinstall Witch if the extension was stripped. |
| “The pairing file was not provided” | Import the pairing file again; make sure it is a remote pairing plist, not a provisioning profile. |
| “Unreachable” / timeout | Connect LocalDevVPN; try Wi-Fi first; on cellular, connect the VPN then enable Airplane Mode before returning. |
| Works once, then connection reset | The device no longer accepts the old pairing (each pairing replaces the last). Pair again. |
| Stale DDI after an iOS update | **Reset Developer Disk Image**, then **Prepare JIT** again. |
| JIT stops mid-game | The helper extension was killed. Reopen Witch; do not detach the debugger manually. |
| Game crashes at startup | The mirror JIT path did not get a live script. Check `Documents/JITReport-latest.txt`; keep the helper attached and use the bundled runtime. |

## Limitations and licensing

- Built-in StikJIT is a sideload feature; it is not App Store-safe.
- The `NSExtension` API and the `com.apple.ar.viewer` extension point are
  private. iOS changes can break them.
- StikJIT is MPL-2.0. StikDebug's script and idevice retain their own licenses.
- The helper pattern is based on Husk's Built-in StikJIT integration
  (GPL-2.0-or-later); see the project credits.
