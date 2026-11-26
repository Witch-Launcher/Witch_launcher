# JIT & Built-in JIT

## Overview {#overview}
Minecraft: Java Edition runs on a JVM that compiles bytecode to native machine code while the game is playing. iOS marks writable memory as non-executable — the W^X rule — so a process may not create and run code in the same pages. Granting an exception is what every JIT method here does: some external process with the right entitlement debugs Witch and flips its memory pages executable.

Without it, nothing starts. The launcher opens, the version is picked, and the JVM halts before the first class loads — which is why the game screen opens with a *Waiting for JIT* banner until a method settles.

SideStore and AltStore installs have a standing option: keep their VPN attached and the <kbd>CS_DEBUGGED</kbd> process stays alive for the whole session. The in-app message refers to exactly that. Every other path is on this page.

## The method matrix {#methods}
**Settings → Game → JIT** holds the switch. The script is always Witch's own `UniversalJIT26.js`; only the attach mechanism changes between methods.

| Method | How it works | Requirements |
| --- | --- | --- |
| **Auto** — default | Resolves at launch, in order: TrollStore when its JIT entitlement is present, then Built-in StikJIT when a pairing file exists, then StikDebug | None — it uses whatever the install provides |
| **Built-in StikJIT** | Witch spawns its embedded `WitchJITHelper.appex`, which runs StikJIT and attaches to the running launcher over the device's RemotePairing service | iOS 17.4+, a remote pairing file, LocalDevVPN connected, Developer Mode, a `get-task-allow` install |
| **StikDebug** | Witch opens `stikdebug://enable-jit` with its bundle ID and PID; StikDebug attaches and enables JIT | StikDebug installed; on iOS 26/27 it must remain attached |
| **Wait for Debugger** | The launcher holds its waiting screen until an external debugger — `lldb` or an IDE session — attaches | A computer on the same network with `lldb` or a remote-debug capable IDE |
| **TrollStore** | Witch hands the request to TrollStore, whose system entitlements clear the memory pages | A `.tipa` install; URL Scheme enabled in TrollStore |

> [!NOTE] The **Force JIT Script** toggle only bypasses TXM detection. It does not select a different script — the developer-defined script is always `UniversalJIT26.js`.

## Auto {#auto}
1. Leave **Settings → Game → JIT → JIT Method** on **Auto**.
2. Launch the game. Witch resolves the methods top to bottom: a TrollStore entitlement wins first, then Built-in StikJIT when a pairing file has been imported, then StikDebug.
3. If the branch you expected never engages, fix that branch directly — the resolution order is a search, not a repair.

## Built-in StikJIT {#built-in-jit}
A process cannot synchronously debug itself — attaching a debugger to its own PID deadlocks. That is the whole reason for the helper: `WitchJITHelper.appex` is a separate process, so Witch hands it the launcher's PID, the remote pairing file, `UniversalJIT26.js` as base64, and the force-script flag. The helper calls `StikJIT.enableJIT` and stays attached while the script services the debug traps. On iOS 17/18 a single attach and detach is enough; on iOS 26/27 it must hold the whole session.

```
Witch.app
└── PlugIns/
    └── WitchJITHelper.appex
```

1. **Sign with a development entitlement** — SideStore, AltStore, Xcode or any signer that keeps `get-task-allow`, and preserves `PlugIns/` when re-signing the archive.
2. **Install LocalDevVPN** — the [companion app](https://apps.apple.com/app/id6755608044) — and connect it. Witch can open `localdevvpn://enable?scheme=witch` for you and LocalDevVPN returns through `witch://`. A nearby Wi-Fi network keeps the tunnel reachable; on cellular, connect first, then enable Airplane Mode and return to Witch.
3. **Enable Developer Mode** in the system settings.
4. **Import a remote pairing file** in **Settings → Game → JIT** — see [below](#developer-mode).
5. **Select Built-in StikJIT** and launch. The first preparation downloads and mounts the Developer Disk Image, and the setup screen probes `10.7.0.1:62078` and `:49152` to show whether the tunnel is reachable.
6. **Leave it attached.** On iOS 26/27 the helper holds the connection for the entire session.

Selecting Built-in StikJIT directly never falls back in silence: an incomplete setup stops the launch with an explicit error and a shortcut to the screen that fixes it.

> [!IMPORTANT] Built-in StikJIT is unavailable inside LiveContainer, which cannot create the required helper extension — use StikDebug there. If a signer stripped `PlugIns/`, the method is reported unavailable and Auto falls back to StikDebug; reinstall a build that keeps its extensions.

### Scope and licensing
The feature is deliberately JIT-only and sideload-only — it is not App Store-safe. The `NSExtension` surface it uses is private, so an iOS update can change what works. StikJIT is MPL-2.0, and the helper pattern follows Husk's Built-in StikJIT integration (GPL-2.0-or-later); the full list lives on the [credits](https://witch-launcher.github.io/docs/#/credits) page.

For builders: the helper ships as a prebuilt arm64 slice under `third_party/stikjit` and is staged by `make jit-helper` (then `make package`). The Makefile skips the helper and framework when retagging Mach-O files to the iOS 14 baseline — both are iOS 17.4+ — and signs them before the main binary.

## StikDebug {#stikdebug}
1. Install **StikDebug** on the device.
2. Set the method to **StikDebug** — or leave **Auto** on an install without TrollStore entitlements or a pairing file.
3. Launch: Witch opens `stikdebug://enable-jit` carrying Witch's bundle ID and PID. When a script must move by hand, `UniversalJIT26.js` is copied to the clipboard.
4. Keep StikDebug attached while playing — on iOS 26/27 for the entire session, not just the first frame.

## Wait for Debugger {#wait-debugger}
1. Set the method to **Wait for Debugger** and launch — the waiting screen takes over.
2. Attach from a computer: `lldb` with a remote `process connect`, or the debugger built into your IDE, over the network.
3. When the attach completes, JIT engages and the boot proceeds. Detaching afterwards is safe on iOS 17/18; keep it attached on iOS 26/27.

## TrollStore {#trollstore}
1. Install the `.tipa` build through TrollStore — not a sideloading signer.
2. Leave the method on **Auto**: the JIT entitlement resolves itself at launch and no VPN page-switch is required.
3. If the launcher still waits, open Witch's entry in TrollStore and enable **URL Scheme**, then relaunch.

## Developer Mode, the pairing file and the DDI {#developer-mode}
### Creating a pairing file
A remote pairing file is made from a trusted computer: with Xcode or `idevicesetup`, or through an AltStore source that already holds one. The [StikDebug pairing guide](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md) walks the manual path step by step. Import the result in **Settings → Game → JIT** — or copy it into Witch's `Documents` folder over Finder or the Files app, since file sharing is enabled.

### Validation rules
The file is validated on import. `public_key` and `private_key` must be 32-byte `Data` values and `identifier` a non-empty string — anything else is rejected with the reason shown. The two common rejections: the file is a provisioning profile rather than a remote pairing plist, or the keys were truncated by a copy that re-encoded the plist.

Witch keeps its validated copy at `Documents/StikJIT/pairingFile.plist`. During an operation the pairing data travels to the helper as `Data` in the extension request, is written to the helper's private `Library/StikJIT` directory, and is deleted when the request ends. It is never logged.

### Developer Disk Image
The helper owns the DDI cache in its `Library/StikJIT` directory. The first preparation downloads and mounts the three-file personalized image, or the five-file cryptex image on iOS 26.4+. A successful mount lasts until the device reboots. **Reset Developer Disk Image** removes the cached files, and the next preparation downloads them again — the standard remedy after an iOS update.

## Troubleshooting {#troubleshooting}
| Symptom | Check |
| --- | --- |
| “Built-in StikJIT is unavailable” | Confirm iOS 17.4+, the helper still present in `PlugIns/`, and that you are not inside LiveContainer. Reinstall Witch if a re-sign stripped the extension. |
| “The pairing file was not provided” | Import the pairing file again in **Settings → Game → JIT**; make sure it is a remote pairing plist, not a provisioning profile. |
| “Unreachable” / timeout | Connect LocalDevVPN and try Wi-Fi first. On cellular, connect the VPN, then enable Airplane Mode and return to Witch. |
| Works once, then the connection resets | A newer pairing replaced the old one — each pairing retires the last. Pair the device again. |
| Stale DDI after an iOS update | Use **Reset Developer Disk Image**, then run **Prepare JIT** again. |
| JIT stops mid-game | The helper extension was killed. Reopen Witch and do not detach the debugger by hand. |
| Game crashes at startup | The mirror JIT path never received a live script. Check `Documents/JITReport-latest.txt`, keep the helper attached and use the bundled runtime. |

> [!NOTE] JIT on iOS 26/27 is fragile by design: the debugger must stay attached for the whole game session, and an OS update can change what works at any time. On iOS 17/18 the attach and detach alone are enough.

> [!NOTE] Stuck on *Waiting for JIT*? Walk the checklist before relaunching — debugger connection active (StikDebug attached or the session attached), LocalDevVPN connected and its tunnel probe green, TrollStore URL Scheme enabled — then launch again.
