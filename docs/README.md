# Witch Launcher — Repository Overview

The iOS and iPadOS launcher that brings **Minecraft: Java Edition** to iPhone and iPad.
This repository is a community fork of Amethyst-iOS, maintained by DuyAnh662 (Za_d626).

```
Boardwalk
    └── PojavLauncherTeam
          └── AngelAuraMC
                └── Amethyst-iOS
                      └── Amethyst-iOS-25 (fork by Catsruledogs)
                            └── Witch Launcher
```

## What lives here {#overview}

| Path | Role |
| --- | --- |
| `Natives/` | Core Objective-C / C / C++ app — launchers, renderers, JIT hooks, touch input |
| `UI/` | UIKit layer: root controllers, screens, managers |
| `JavaApp/` | The Java side — `net.kdt.pojavlaunch` bootstrap, AWT patches, text-to-speech |
| `JavaApp/libs/` | Prebuilt JVM / AWT / LWJGL jars used on device |
| `amethyst-prebuilt-libraries/` | Prebuilt renderer payloads: SDL3, ANGLE, MoltenVK, Zink, gl4es, TGLMT, LTW |
| `depends/` | Java dependency sources for the runtime builds |
| `lwgjl/` | LWJGL 3.3.3 / 3.3.6 / 3.4.1 trees |
| `scripts/` | Build helpers, including `scripts/plugins/pack_plugin.py` |
| `examples/plugins/` | Reference `.plgw` plugins: hello, aurora-ui, pe-controls, theme-studio |
| `keys/` | Registry signing key material (private keys never ship in a package) |
| `third_party/stikjit/` | Prebuilt arm64 StikJIT helper slice |
| `tools/WitchJITHelper/` | Swift app extension that performs the built-in JIT attach |
| `docs/` | This documentation set — see the sidebar for the full order |

## Feature surface {#features}

**Versions and loaders** — every release from `Beta_a1.2` to current snapshots; Vanilla, Fabric,
Quilt, Forge, NeoForge and OptiFine; each one isolated in its own profile with its own mods,
worlds and packs.

**Renderers** — six paths over Metal:

| Renderer | API level | Notes |
| --- | --- | --- |
| gl4es | GL 2.1 | The safe default for the oldest machines |
| ANGLE / MetalANGLE | GLES 2/3 | Upstream ANGLE on Metal |
| MobileGlues | GL 4.0 | Modern core profile for 1.17+ |
| Zink | GL 4.1 | Mesa 25 over MoltenVK |
| LTW | GL 3.3 | Experimental path for 1.17+ |
| **TGLMT** | **GL 4.6 Core** | OpenGL 4.6 implemented over Metal — Sodium + Iris shaders |

**Runtimes** — Java 8, 17, 21 and 25 plus LWJGL 3.3.3 → 3.4.1, fetched in-app by a
multi-threaded downloader. The release manifest lives in the separate
`Witch-Launcher/JDK-Java_iOS` repository under the rolling `runtimes-latest` tag.

**Accounts** — Microsoft, local (offline), demo and Ely.by. Local play needs no account.

**Plugins** — signed `.plgw` packages that add declarative settings, theme colors, JavaScript
and — where the platform permits dynamic libraries — native code. See the Plugins pages.

## Build {#build}

```sh
# native app + bundled runtimes
make -j"$(sysctl -n hw.ncpu)" package

# TrollStore build with the JIT entitlement
make package TROLLSTORE_JIT_ENT=1

# fetch the Java runtimes instead of compiling them
make jre-download
```

Artifacts land in `artifacts/`. Signing needs a real Apple team id — the launcher is
sideload-only by design.

## Where to read next {#next}

- **Plugins** — package anatomy, manifest spec, the JavaScript and native APIs, the security
  model, the registry API and the publishing workflow
- **Built-in JIT** — how `WitchJITHelper.appex` attaches and what each install method needs
- **JDK runtime release** — how the runtimes are built and published

## License {#license}

GNU General Public License v3.0. Third-party components keep their own licenses — the full
list lives in `credits.md` at the repository root.

Minecraft is a trademark of Mojang Studios. Witch Launcher is not affiliated with Mojang
Studios or Microsoft and ships no game files.
