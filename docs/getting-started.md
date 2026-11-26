# Getting started

## Requirements {#overview}
| Requirement | Detail |
| --- | --- |
| Device | iPhone or iPad — arm64, Metal capable |
| OS | iOS / iPadOS **14.0 or newer**. The built-in JIT helper needs **17.4+** |
| JIT | **Mandatory.** Without just-in-time compilation the runtime does not start — see the [JIT guide](jit.md) |
| Account | A Microsoft account that owns Minecraft Java Edition. Local, demo and Ely.by accounts also supported |

> [!IMPORTANT] Witch Launcher never ships game files or a Microsoft certificate. You always got the `.ipa` / `.tipa` from GitHub releases and pick your own signing method below.

## Choosing an install method {#install}
### SideStore / AltStore — the standard way
1. Download the standard or slimmed build, the `.ipa` from the [Download](https://witch-launcher.github.io/#download) section.
2. Sideload it with SideStore or AltStore.
3. For JIT, use the attached VPN connection (the <kbd>CS_DEBUGGED</kbd> process stays alive when the VPN is attached), or launch with **StikDebug**.

### TrollStore — cleanest performance
1. Get the `.tipa` asset from releases.
2. Open it through TrollStore. Its system entitlements handle JIT by themselves — no VPN page switch required.

### Built-in StikJIT — iOS 17.4 and newer
1. Install the [LocalDevVPN companion app](https://apps.apple.com/app/id6755608044).
2. In Settings → Game → JIT, enable the pattern **Built-in StikJIT**.
3. Provide a developer-mode pairing file; Witch launches its own JIT helper with it. Details and troubleshooting live in the [JIT guide](jit.md).

### Jailbreak
1. Install the `.ipa` through your package manager of choice.
2. On a jailbroken device JIT can be enabled without the companion VPN — turn on your jail’s JIT enabler and set Settings → Game → JIT to a method it provides.

## First launch {#first-launch}
1. **Grant JIT** — if a red banner says “Waiting for JIT”, follow the method you picked above first.
2. **Pick a version** — the version manager list may show empty until a Java runtime has been downloaded. Witch downloads Java 8 / 17 / 21 / 25 automatically when a version needs it.
3. **Add an account** — Microsoft (official), local (offline), demo or Ely.by.
4. **Press Play** — the first boot downloads game assets; give it a couple of minutes.

> [!NOTE] The **slimmed** build ships without bundled runtimes to save space. If a version does not boot, check the game wasn’t copied from another launcher folder — use the in-app runtime download instead.

## Quick JIT check before you continue {#jit-check}
| Install | Method |
| --- | --- |
| SideStore / AltStore | Auto → StikDebug or debugger attach via VPN |
| TrollStore | Auto → built-in helper or TrollStore URL scheme |
| iOS 17.4+ / no jailbreak | Built-in StikJIT → pairing file + LocalDevVPN |
| Jailbroken | TrollStore or debugger of your choice |

Full method matrix, pairing-file guidance and the seven-row troubleshooting table are on the [JIT & Built-in JIT](jit.md) page.

## Next steps {#next}
- [Java runtimes](runtimes.md) — Java 8 → 25, LWJGL 3.3.3 → 3.4.1, memory notes
- [Plugin system](plugins/system.md) — signed `.plgw` extensions
- [FAQ](https://witch-launcher.github.io/docs/#/faq) — the questions we see every week
