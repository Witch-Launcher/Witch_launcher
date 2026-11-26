# Java runtimes

## Overview {#overview}
Runtimes reach the device through the in-app manager: **Settings → Game → Java runtimes**, or the same screen offered on first launch. A multi-thread downloader fetches each release asset over several connections; every row carries its own download, update and delete, and a finished install applies immediately — the version manager reads the path when a game next launches, no restart required.

The artifacts are built and published by the [Witch-Launcher/JDK-Java_iOS](https://github.com/Witch-Launcher/JDK-Java_iOS) repository under a rolling tag, `runtimes-latest`, which is force-moved on every build. A `runtimes.json` manifest lists each file — version, URL and size — with one release asset per artifact rather than one large archive. The launcher reads that manifest on demand; its URL lives in the `witch.runtime_manifest` preference, so a mirror can take its place.

```
{
  "jre8":     { "version": "1.8.0_472", "url": "https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/runtimes-latest/jre8-ios-aarch64.tar.xz" },
  "jre17":    { "version": "17.0.20",   "url": "…" },
  "jre21":    { "version": "21.0.8",    "url": "…" },
  "jre25":    { "version": "25.0.4",    "url": "…" },
  "lwjgl333": { "version": "3.3.3",     "url": "…" },
  "lwjgl336": { "version": "3.3.6",     "url": "…" },
  "lwjgl341": { "version": "3.4.1",     "url": "…" }
}
```

> [!IMPORTANT] The **slimmed** build ships without bundled runtimes to save space. There the in-app download is not optional — a fresh install downloads Java and LWJGL before any version boots.

## Versions and LWJGL {#matrix}
Minecraft declares the Java level it needs and Witch resolves a downloaded runtime to match; the manager also shows where each one sits. Java 8, Java 25, LWJGL 3.3.3 and LWJGL 3.4.1 carry an **important** badge in the list — download those first when storage is tight.

| Java | Minecraft support | Note |
| --- | --- | --- |
| **Java 8** | Beta releases through 1.16 | Important badge — the baseline for legacy and modded setups |
| **Java 17** | 1.17 – 1.20.4 |  |
| **Java 21** | 1.20.5 – 1.21 |  |
| **Java 25** | Current snapshots and newer releases | Important badge |

The LWJGL line is picked per [game profile](getting-started.md), next to the renderer and JVM settings:

| LWJGL | Typical use |
| --- | --- |
| **3.3.3** | Older versions and most modded stacks — important badge |
| **3.3.6** | Intermediate releases |
| **3.4.1** | Modern versions and current snapshots — important badge |

## Custom and manual import {#import}
The same manager imports an archive you built yourself. Keep the release layout the manifest publishes: the `release` file at the root, a `.witch-mirror-mapping` entry, and a patched `lib/server/libjvm.dylib` — archives arrive as `.tar.xz`, so no re-compression is needed. An imported runtime is managed like any downloaded one: its row in Settings can be updated or deleted on its own, without touching the rest.

Runtimes live in the launcher's own library directory and are shared between profiles; a profile isolates its own settings, so each one points at the Java level and LWJGL line it prefers. Files are never copied out of another launcher's folder — hand-copied game folders break the version manager in ways that look like a runtime bug.

## Memory and JVM options {#memory}
- **Auto RAM** — the default. The launcher sizes the heap against the device's own memory budget, the right starting point everywhere and the only sane one on devices with limited memory.
- **JVM arguments** — edited per profile for modpacks that ask for specific flags.
- **Environment variables** — the editor for runtime-level settings the renderer stack reads.

Raise allocation only when a modpack proves it: the JVM shares the device with the GPU driver, the translation layers and iOS itself, and an over-committed heap kills the session faster than a small one.

## Troubleshooting {#troubleshooting}
- A row stalls or fails mid-download — check the network, prefer unmetered Wi-Fi, and retry the download from the same row; assets run large.
- Manifest unreachable — point `witch.runtime_manifest` at a mirror serving `runtimes.json`, then reopen the manager.
- Version list still empty after a download — the archive probably lost its layout; re-import with `release` and `lib/server/libjvm.dylib` in place.
- JVM dies at startup with a missing library — switch the profile to the LWJGL line it expects; crossing lines breaks older versions first.

> [!NOTE] Installs apply without a restart. If a downloaded runtime seems invisible, close and reopen the version manager before reinstalling anything.
