<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
  <strong>Minecraft: Java Edition on iPhone and iPad.</strong><br>
  A community-built iOS and iPadOS fork of Amethyst, maintained by DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Features](#features) · [Screenshots](#screenshots) · [Requirements](#requirements) · [Installation](#installation) · [Languages](#languages) · [Credits](#credits) · [License](#license)

<details>
<summary><strong>Languages</strong></summary>

[Afrikaans](README.af.md) · [العربية](README.ar.md) · [azərbaycan](README.az.md) · [башҡорт теле](README.ba.md)<br>
[বাংলা](README.bn.md) · [বাংলা (ভারত)](README.bn-IN.md) · [català](README.ca.md) · [čeština](README.cs.md)<br>
[dansk](README.da.md) · [Deutsch](README.de.md) · [Ελληνικά](README.el.md) · [English](../../README.md)<br>
[English (United Kingdom)](README.en-GB.md) · [Pirate English](README.en-PT.md) · [English (Upside Down)](README.en-UD.md) · [español](README.es.md)<br>
[eesti](README.et.md) · [فارسی](README.fa.md) · [suomi](README.fi.md) · [Filipino](README.fil.md)<br>
[français](README.fr.md) · [עברית](README.he.md) · [हिन्दी](README.hi.md) · [magyar](README.hu.md)<br>
[Indonesia](README.id.md) · [italiano](README.it.md) · [日本語](README.ja.md) · [қазақ тілі](README.kk.md)<br>
[한국어](README.ko.md) · [Latin](README.la.md) · [LOLCAT](README.lol.md) · [lietuvių](README.lt.md)<br>
[Bahasa Melayu](README.ms.md) · [Nederlands](README.nl.md) · [norsk](README.no.md) · [polski](README.pl.md)<br>
[Pirate](README.pr.md) · [português](README.pt.md) · [português (Brasil)](README.pt-BR.md) · [română](README.ro.md)<br>
[русский](README.ru.md) · [slovenčina](README.sk.md) · [српски](README.sr.md) · [srpski (latinica)](README.sr-Latn.md)<br>
[svenska](README.sv.md) · [ไทย](README.th.md) · [Türkçe](README.tr.md) · [татар](README.tt.md)<br>
[українська](README.uk.md) · [Tiếng Việt](README.vi.md) · [简体中文](README.zh-Hans.md) · [繁體中文](README.zh-Hant.md)

</details>

</div>

---

<a id="about"></a>
## About

**Witch Launcher** is an independent, community-maintained fork of [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) that brings **Minecraft: Java Edition** to iPhone and iPad. It combines a touch-first launcher UI with a full Java runtime manager, LWJGL, and a graphics stack built around Metal, MoltenVK, and OpenGL translation layers.

Witch is built on the work of [Boardwalk](https://github.com/zhuowei/Boardwalk), the [PojavLauncher](https://github.com/PojavLauncherTeam) community, Amethyst-iOS, and Amethyst-iOS-25. It is an independent project and is not affiliated with Mojang Studios, Microsoft, or the upstream Amethyst team.

> **Current version:** 0.0.4 · See [`news.md`](../../news.md) for release notes.

---

<a id="features"></a>
## Features

### Minecraft and mods

- Runs most **Minecraft: Java Edition** versions, from early Beta releases through the latest snapshots.
- Supports **Vanilla, Fabric, Quilt, Forge, NeoForge, and OptiFine**.
- Create isolated **game profiles** with their own settings, mods, shaders, resource packs, and worlds.
- Browse and install content from **Modrinth and CurseForge** without leaving the launcher:
  - mods
  - modpacks
  - shader packs
  - resource packs
  - adventure maps and worlds
- Resolve and install mod dependencies where the source provides them.
- Import Forge/NeoForge installer JARs and install Fabric/Quilt loaders directly from the version picker.

### Graphics and performance

- Switch between multiple renderers from **Settings → Renderer & Display**:
  - **gl4es** — OpenGL 2.1 compatibility path
  - **ANGLE** — OpenGL ES through Metal or Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimental
  - **Zink** — OpenGL 4.1 through Mesa 25 and MoltenVK
  - **LTW** — OpenGL 3.3 through OpenGL ES/Metal, Minecraft 1.17+, experimental
  - **TGLMT** — OpenGL 4.6 Core through Metal, A11 Bionic or newer
- **TGLMT with Sodium and Iris support** for modern shader-based setups.
- **Frame Generation** with Motion-Adaptive GPU (MADI) and Camera 3D Reproject modes, including temporal interpolation and predictive extrapolation.
- Resolution scaling, maximum framerate, FSR 1.0 upscaling, GLSL shader caches, and per-renderer tuning.
- Performance HUD with configurable FPS, CPU, GPU, RAM, temperature, battery, clock, and frame-generation FPS widgets.
- Built-in performance recording with charts, PNG/PDF export, and sharing.

### Controls

- Fully customizable on-screen control layouts, button sizes, and transparency.
- **Keyboard and mouse** support, including a virtual mouse and adjustable pointer speed.
- **Game controller** support with configurable layouts and sensitivity.
- **Gyroscope** aiming with adjustable sensitivity and axis inversion.
- Mouse, scroll, and hotbar gestures.
- Optional behavior: tap to place blocks, hold to break blocks.
- Double-tap the hotbar to swap the held item into the off-hand.
- Slideable hotbar and adjustable long-press timing.

### Launcher and accounts

- **Microsoft**, **local/offline**, **demo**, and **Ely.by** account support.
- Manage **Java 8, 17, 21, and 25** runtimes, download them in-app, or import your own.
- Select LWJGL versions and tune JVM arguments, environment variables, and memory allocation.
- Auto RAM management for devices with limited memory.
- Themes, accent colors, blur, borders, corner radius, custom launcher fonts, and app icons.
- In-game **F3 device information**: device chip, iOS version, launcher name/version, build number, and build type.
- Optional **Witch Server**, CurseForge, and AI integrations for advanced setups.
- **52 in-app languages**, including right-to-left language packs and fun locales.

---

<a id="screenshots"></a>
## Screenshots

Screenshots from a development build of Witch Launcher 0.0.4. The interface can change between versions and themes.

| | |
|---|---|
| <img src="../../media/IMG_2690.png" width="400" alt="Witch Launcher screenshot 1"> | <img src="../../media/IMG_2691.png" width="400" alt="Witch Launcher screenshot 2"> |
| <img src="../../media/IMG_2692.png" width="400" alt="Witch Launcher screenshot 3"> | <img src="../../media/IMG_2693.png" width="400" alt="Witch Launcher screenshot 4"> |
| <img src="../../media/IMG_2694.png" width="400" alt="Witch Launcher screenshot 5"> | <img src="../../media/IMG_2695.png" width="400" alt="Witch Launcher screenshot 6"> |
| <img src="../../media/IMG_2696.png" width="400" alt="Witch Launcher screenshot 7"> | <img src="../../media/IMG_2697.png" width="400" alt="Witch Launcher screenshot 8"> |
| <img src="../../media/IMG_2698.png" width="400" alt="Witch Launcher screenshot 9"> | <img src="../../media/IMG_2699.png" width="400" alt="Witch Launcher screenshot 10"> |
| <img src="../../media/IMG_2700.png" width="400" alt="Witch Launcher screenshot 11"> | <img src="../../media/IMG_2701.png" width="400" alt="Witch Launcher screenshot 12"> |
| <img src="../../media/IMG_2702.png" width="400" alt="Witch Launcher screenshot 13"> | <img src="../../media/IMG_2703.png" width="400" alt="Witch Launcher screenshot 14"> |

---

<a id="requirements"></a>
## Requirements

| Requirement | Details |
|---|---|
| **Device** | iPhone or iPad with an arm64 processor and Metal support |
| **System** | iOS or iPadOS **14.0 or newer** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Account** | A Microsoft account that owns Minecraft for official downloads; local and demo modes are also available |
| **Storage** | Space for the launcher, Java runtimes, game versions, mods, and worlds |
| **Network** | Required for sign-in, version downloads, the content browser, and optional online services |

Witch does **not** include Minecraft game files. Game files are downloaded through the launcher after signing in to an eligible account.

### JIT notes

Minecraft: Java Edition needs JIT, and Witch cannot launch the game without it.

- **SideStore / AltStore-style installs:** enable JIT for Witch and keep the required VPN/debugger connection active. The in-app message refers to **LocalDevVPN** and `CS_DEBUGGED`.
- **StikDebug:** attach StikDebug to Witch and enable JIT. On **iOS 26/27**, StikDebug must stay attached while the game is running. `UniversalJIT26.js` is copied to the clipboard when needed.
- **TrollStore:** enable **URL Scheme** in TrollStore if Witch keeps waiting for JIT.
- **Jailbroken devices:** use your preferred JIT enabler.
- If the launcher stays on the **Waiting for JIT** screen, check the debugger connection, the VPN, and the TrollStore URL Scheme setting before relaunching.

JIT behavior depends on the iOS version and installation method. System updates can break existing JIT setups.

---

<a id="installation"></a>
## Installation

Witch must be signed for your device. This repository does not ship certificates or pre-signed IPAs.

### Use a build

1. Download a development build from the [development workflow](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), or use a signed build from a source you trust.
2. Sign and install it with **SideStore**, **AltStore**, **TrollStore**, or your preferred sideloading method.
3. Enable JIT as described above before launching the game.

TrollStore builds use additional entitlements and should not be installed with a normal sideloading signer.

### Build from source

Compiling Witch requires macOS with Xcode command-line tools, an iOS SDK 14.0 or newer, CMake, JDK 8, `ldid`, `wget`, `zip`, and Git.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Packaged builds are written to `artifacts/`.

To build a TrollStore package instead:

```bash
make package TROLLSTORE_JIT_ENT=1
```

For renderer source links and build notes, see [`note.md`](../../note.md).

---

<a id="languages"></a>
## Languages

Witch Launcher ships with **52 language packs**. Open **Settings → General → Language** and select a language, or use **Auto** to follow the device language.

| Code | Language | Code | Language |
|---|---|---|---|
| `af` | [Afrikaans](README.af.md) | `ar` | [العربية](README.ar.md) |
| `az` | [azərbaycan](README.az.md) | `ba` | [башҡорт теле](README.ba.md) |
| `bn` | [বাংলা](README.bn.md) | `bn-IN` | [বাংলা (ভারত)](README.bn-IN.md) |
| `ca` | [català](README.ca.md) | `cs` | [čeština](README.cs.md) |
| `da` | [dansk](README.da.md) | `de` | [Deutsch](README.de.md) |
| `el` | [Ελληνικά](README.el.md) | `en` | [English](../../README.md) |
| `en-GB` | [English (United Kingdom)](README.en-GB.md) | `en-PT` | [Pirate English](README.en-PT.md) |
| `en-UD` | [English (Upside Down)](README.en-UD.md) | `es` | [español](README.es.md) |
| `et` | [eesti](README.et.md) | `fa` | [فارسی](README.fa.md) |
| `fi` | [suomi](README.fi.md) | `fil` | [Filipino](README.fil.md) |
| `fr` | [français](README.fr.md) | `he` | [עברית](README.he.md) |
| `hi` | [हिन्दी](README.hi.md) | `hu` | [magyar](README.hu.md) |
| `id` | [Indonesia](README.id.md) | `it` | [italiano](README.it.md) |
| `ja` | [日本語](README.ja.md) | `kk` | [қазақ тілі](README.kk.md) |
| `ko` | [한국어](README.ko.md) | `la` | [Latin](README.la.md) |
| `lol` | [LOLCAT](README.lol.md) | `lt` | [lietuvių](README.lt.md) |
| `ms` | [Bahasa Melayu](README.ms.md) | `nl` | [Nederlands](README.nl.md) |
| `no` | [norsk](README.no.md) | `pl` | [polski](README.pl.md) |
| `pr` | [Pirate](README.pr.md) | `pt` | [português](README.pt.md) |
| `pt-BR` | [português (Brasil)](README.pt-BR.md) | `ro` | [română](README.ro.md) |
| `ru` | [русский](README.ru.md) | `sk` | [slovenčina](README.sk.md) |
| `sr` | [српски](README.sr.md) | `sr-Latn` | [srpski (latinica)](README.sr-Latn.md) |
| `sv` | [svenska](README.sv.md) | `th` | [ไทย](README.th.md) |
| `tr` | [Türkçe](README.tr.md) | `tt` | [татар](README.tt.md) |
| `uk` | [українська](README.uk.md) | `vi` | [Tiếng Việt](README.vi.md) |
| `zh-Hans` | [简体中文](README.zh-Hans.md) | `zh-Hant` | [繁體中文](README.zh-Hant.md) |

The app ships all **52 language packs**. README translations are available for **all 52 languages**, including English.

Some translations are machine-assisted and may contain awkward technical terms. Corrections are welcome.

English is the source language for this README. Localized READMEs are available from the language selector at the top of this page and in the [`docs/readme/`](./) directory.

---

<a id="notes-and-limitations"></a>
## Notes and limitations

- **JIT is mandatory.** Without a working JIT setup, Minecraft will not launch.
- **iOS 26/27 JIT is fragile.** StikDebug must remain attached, and future OS updates may change what works.
- Renderers marked **experimental** can crash or render incorrectly. Start with **Auto** if you are unsure.
- **Frame Generation** requires the MoltenVK renderer and Metal compute support. It can increase battery usage and device temperature.
- Some mods, modpacks, shaders, and worlds may require a specific Minecraft version, loader, renderer, or additional memory.
- CurseForge modpacks use `manifest.json`; if one-tap installation is not available for a pack, import the archive manually.
- Online features depend on third-party services and may be unavailable.
- Screenshots are from a development build and may not match the current release exactly.

---

<a id="project-lineage"></a>
## Project lineage

```text
Boardwalk
    │
    └── PojavLauncherTeam
        │
        └── AngelAuraMC
            │
            └── Amethyst-iOS
                │
                └── Amethyst-iOS-25 (fork by Catsruledogs)
                    │
                    └── Witch Launcher
                        └── iOS / iPadOS
```

### Related projects

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contributing

Bug reports and PRs are welcome. When reporting a problem, include:

- device model and iOS/iPadOS version
- Witch Launcher version
- renderer and Minecraft version
- mod loader and a list of installed mods
- steps to reproduce
- the relevant log or crash report

Please do not commit signing certificates, provisioning profiles, API keys, or other secrets.

---

<a id="credits"></a>
## Credits

**Witch Launcher** is maintained by **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream and community

Witch Launcher and its upstream projects are built on the work of many contributors, including:

- **@crystall1nedev** — Amethyst project manager and iOS port developer
- **@khanhduytran0** — iOS port developer
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Additional thanks to **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, the ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla, and the Minecraft community.

Special thanks to [MCHeads](https://mc-heads.net) for providing Minecraft avatar services.

The complete third-party component and license list is available in [`credits.md`](../../credits.md).

---

<a id="license"></a>
## License

Witch Launcher is distributed under the **GNU General Public License v3.0**, subject to the licenses and copyright requirements of the third-party components listed in [`credits.md`](../../credits.md).

See [`LICENSE`](../../LICENSE) for the complete license text.

---

<p align="center">
  <sub>Minecraft is a trademark of Mojang Studios. Witch Launcher is not affiliated with Mojang Studios, Microsoft, or the Amethyst project.</sub>
</p>
