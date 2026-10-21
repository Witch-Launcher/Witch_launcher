<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition på iPhone og iPad.</strong><br>
En fællesskabsbygget iOS og iPadOS gaffel af Amethyst, vedligeholdt af DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funktioner](#features) · [Skærmbilleder](#screenshots) · [Krav](#requirements) · [Installation](#installation) · [Sprog](#languages) · [Kreditter](#credits) · [Licens](#license)

<details>
<summary><strong>Sprog</strong></summary>

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
## Om

**Witch Launcher** er en uafhængig, fællesskabsvedligeholdt forgrening af [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), der bringer **Minecraft: Java Edition** til iPhone og iPad. Den kombinerer en touch-first launcher UI med en fuld Java runtime manager, LWJGL, og en grafikstak bygget op omkring Metal, MoltenVK og OpenGL oversættelseslag.

Witch er bygget på arbejdet fra [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) fællesskabet, Amethyst-iOS og Amethyst-iOS-25. Det er et selvstændigt projekt og er ikke tilknyttet Mojang Studios, Microsoft eller upstream Amethyst-teamet.

> **Nuværende version:** 0.0.4 · Se [`news.md`](../../news.md) for release notes.

---

<a id="features"></a>
## Funktioner

### Minecraft og mods

- Kører de fleste **Minecraft: Java Edition** versioner, fra tidlige betaudgivelser til de seneste snapshots.
- Understøtter **Vanilla, Fabric, Quilt, Forge, NeoForge og OptiFine**.
- Opret isolerede **spilprofiler** med deres egne indstillinger, mods, shaders, ressourcepakker og verdener.
- Gennemse og installer indhold fra **Modrinth og CurseForge** uden at forlade startprogrammet:
  - mods
  - modpakker
  - shader pakker
  - ressourcepakker
  - eventyrkort og verdener
- Løs og installer mod-afhængigheder, hvor kilden giver dem.
- Importer Forge/NeoForge installatør JAR'er og installer Fabric/Quilt læssere direkte fra versionsvælgeren.

### Grafik og ydeevne

- Skift mellem flere renderere fra **Indstillinger → Renderer og visning**:
  - **gl4es** — OpenGL 2.1 kompatibilitetssti
  - **ANGLE** — OpenGL ES til Metal eller Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimentel
  - **Zink** — OpenGL 4.1 til og med Mesa 25 og MoltenVK
  - **LTW** — OpenGL 3.3 til og med OpenGL ES/Metal, Minecraft 1.17+, eksperimentel
  - **TGLMT** — OpenGL 4.6 Core til Metal, A11 Bionic eller nyere
- **TGLMT med Sodium og Iris understøttelse** til moderne shader-baserede opsætninger.
- **Frame Generation** med Motion-Adaptive GPU (MADI) og Camera 3D Reproject modes, inklusive tidsmæssig interpolation og forudsigelig ekstrapolation.
- Opløsningsskalering, maksimal billedhastighed, FSR 1.0 opskalering, GLSL shader caches og justering pr. renderer.
- Ydeevne HUD med konfigurerbare FPS, CPU, GPU, RAM, temperatur, batteri, ur og frame-generation FPS-widgets.
- Indbygget præstationsoptagelse med diagrammer, PNG/PDF eksport og deling.

### Kontrolelementer

- Fuldt tilpasselige skærmlayouts, knapstørrelser og gennemsigtighed.
- **Tastatur og mus**-understøttelse, inklusive en virtuel mus og justerbar markørhastighed.
- **Spilcontroller**-understøttelse med konfigurerbare layouts og følsomhed.
- **Gyroskop** sigte med justerbar følsomhed og aksevending.
- Bevægelser med mus, rul og hotbar.
- Valgfri adfærd: Tryk for at placere blokke, hold for at bryde blokke.
- Dobbelttryk på hotbaren for at skifte det tilbageholdte element til off-hand.
- Skydbar hotbar og justerbar langtryks-timing.

### Launcher og konti

- **Microsoft**, **lokal/offline**, **demo** og **Ely.by** kontosupport.
- Administrer **Java 8, 17, 21 og 25** kørselstider, download dem i appen, eller importer dine egne.
- Vælg LWJGL-versioner og juster JVM-argumenter, miljøvariabler og hukommelsesallokering.
- Automatisk RAM-styring til enheder med begrænset hukommelse.
- Temaer, accentfarver, sløring, kanter, hjørneradius, brugerdefinerede launcher-skrifttyper og appikoner.
- In-game **F3 enhedsoplysninger**: enhedschip, iOS version, launcher navn/version, build nummer og build type.
- Valgfri **Witch Server**, CurseForge og AI integrationer til avancerede opsætninger.
- **52 sprog i appen**, inklusive sprogpakker fra højre mod venstre og sjove lokaliteter.

---

<a id="screenshots"></a>
## Skærmbilleder

Skærmbilleder fra en udviklingsbygning af Witch Launcher 0.0.4. Grænsefladen kan skifte mellem versioner og temaer.

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
## Krav

| Krav | Detaljer |
|---|---|
| **Enhed** | iPhone eller iPad med en arm64 processor og Metal support |
| **System** | iOS eller iPadOS **14.0 eller nyere** |
| **JIT** | Påkrævet. Aktiver JIT til StikDebug, SideStore, TrollStore eller en jailbroken opsætning |
| **Konto** | En Microsoft-konto, der ejer Minecraft til officielle downloads; lokale og demo-tilstande er også tilgængelige |
| **Opbevaring** | Plads til launcheren, Java køretider, spilversioner, mods og verdener |
| **Netværk** | Påkrævet for login, versionsdownloads, indholdsbrowseren og valgfri onlinetjenester |

Witch inkluderer **ikke** Minecraft spilfiler. Spilfiler downloades via startprogrammet, når du er logget ind på en kvalificeret konto.

### JIT noter

Minecraft: Java Edition har brug for JIT, og Witch kan ikke starte spillet uden.

- **SideStore / AltStore-lignende installationer:** aktiver JIT for Witch og hold den nødvendige VPN/debuggerforbindelse aktiv. Beskeden i appen henviser til **LocalDevVPN** og `CS_DEBUGGED`.
- **StikDebug:** vedhæft StikDebug til Witch og aktiver JIT. På **iOS 26/27** skal StikDebug forblive tilknyttet, mens spillet kører. `UniversalJIT26.js` kopieres til udklipsholderen efter behov.
- **TrollStore:** aktiver **URL Scheme** i TrollStore, hvis Witch bliver ved med at vente på JIT.
- **Jailbroken-enheder:** Brug din foretrukne JIT-aktivering.
- Hvis startprogrammet forbliver på skærmen **Venter på JIT**, skal du kontrollere fejlretningsforbindelsen, VPN og TrollStore URL Scheme-indstillingen før genstart.

JIT adfærd afhænger af iOS version og installationsmetode. Systemopdateringer kan bryde eksisterende JIT opsætninger.

---

<a id="installation"></a>
## Installation

Witch skal være signeret for din enhed. Dette lager sender ikke certifikater eller præ-signerede IPA'er.

### Brug en build

1. Download en udviklingsbuild fra [udviklingsarbejdsgangen](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), eller brug en signeret build fra en kilde, du har tillid til.
2. Signer og installer den med **SideStore**, **AltStore**, **TrollStore** eller din foretrukne sideindlæsningsmetode.
3. Aktiver JIT som beskrevet ovenfor, før du starter spillet.

TrollStore builds bruger yderligere rettigheder og bør ikke installeres med en normal sideloading signer.

### Byg fra kilden

Kompilering af Witch kræver macOS med Xcode kommandolinjeværktøjer, en iOS SDK 14.0 eller nyere, CMake, JDK 8, `ldid`, `wget`, `zip` og Git.

```bash
git clone --rekursiv https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Pakkede builds skrives til `artifacts/`.

For at bygge en TrollStore-pakke i stedet:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Se [`note.md`](../../note.md) for links til gengiverkilde og build-noter.

---

<a id="languages"></a>
## Sprog

Witch Launcher leveres med **52 sprogpakker**. Åbn **Indstillinger → Generelt → Sprog**, og vælg et sprog, eller brug **Auto** til at følge enhedens sprog.

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

Appen sender alle **52 sprogpakker**. README-oversættelser er tilgængelige for **alle 52 sprog**, inklusive engelsk.

Nogle oversættelser er maskinstøttede og kan indeholde akavede tekniske termer. Rettelser modtages gerne.

Engelsk er kildesproget for denne README. Lokaliserede README'er er tilgængelige fra sprogvælgeren øverst på denne side og i biblioteket [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Noter og begrænsninger

- **JIT er obligatorisk.** Uden en fungerende JIT-opsætning vil Minecraft ikke starte.
- **iOS 26/27 JIT er skrøbelig.** StikDebug skal forblive vedhæftet, og fremtidige OS-opdateringer kan ændre, hvad der virker.
- Renderere markeret med **eksperimentel** kan gå ned eller gengives forkert. Start med **Auto**, hvis du er usikker.
- **Rammegenerering** kræver MoltenVK rendereren og Metal computerunderstøttelse. Det kan øge batteriforbruget og enhedens temperatur.
- Nogle mods, modpacks, shaders og verdener kræver muligvis en specifik Minecraft version, loader, renderer eller ekstra hukommelse.
- CurseForge modpacks bruger `manifest.json`; hvis installation med et enkelt tryk ikke er tilgængelig for en pakke, skal du importere arkivet manuelt.
- Onlinefunktioner afhænger af tredjepartstjenester og kan være utilgængelige.
- Skærmbilleder er fra en udviklingsbygning og matcher muligvis ikke den aktuelle udgivelse nøjagtigt.

---

<a id="project-lineage"></a>
## Projekt slægt

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

### Relaterede projekter

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Bidrager

Fejlrapporter og PR er velkomne. Når du rapporterer et problem, skal du inkludere:

- enhedsmodel og iOS/iPadOS version
- Witch Launcher version
- renderer og Minecraft version
- mod loader og en liste over installerede mods
- trin til at reproducere
- den relevante log eller nedbrudsrapport

Undlad venligst at underskrive certifikater, klargøringsprofiler, API nøgler eller andre hemmeligheder.

---

<a id="credits"></a>
## Credits

**Witch Launcher** vedligeholdes af **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream og fællesskab

Witch Launcher og dets upstream-projekter er bygget på arbejdet fra mange bidragydere, herunder:

- **@crystall1nedev** — Amethyst projektleder og iOS portudvikler
- **@khanhduytran0** — iOS portudvikler
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Yderligere tak til **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE-projektet, Khronos-gruppen, Mesa-projektet, PojavLauncher-teamet, Mozilla og Minecraft-fællesskabet.

Særlig tak til [MCHeads](https://mc-heads.net) for at levere Minecraft avatartjenester.

Den komplette tredjepartskomponent og licensliste er tilgængelig i [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licens

Witch Launcher distribueres under **GNU General Public License v3.0**, underlagt licenserne og ophavsretskravene for tredjepartskomponenterne anført i [`credits.md`](../../credits.md).

Se [`LICENSE`](../../LICENSE) for den komplette licenstekst.

---

<p align="center">
<sub>Minecraft er et varemærke tilhørende Mojang Studios. Witch Launcher er ikke tilknyttet Mojang Studios, Microsoft eller Amethyst-projektet.</sub>
</p>
