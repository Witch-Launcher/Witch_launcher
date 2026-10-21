<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition op iPhone en iPad.</strong><br>
Een door de gemeenschap gebouwde iOS- en iPadOS-vork van Amethyst, onderhouden door DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Functies](#features) · [Screenshots](#screenshots) · [Vereisten](#requirements) · [Installatie](#installation) · [Talen](#languages) · [Credits](#credits) · [Licentie](#license)

<details>
<summary><strong>Talen</strong></summary>

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
## Over

**Witch Launcher** is een onafhankelijke, door de gemeenschap onderhouden afsplitsing van [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) die **Minecraft: Java Edition** naar iPhone en iPad brengt. Het combineert een touch-first launcher-UI met een volledige Java runtime manager, LWJGL, en een grafische stapel opgebouwd rond Metal, MoltenVK en OpenGL vertaallagen.

Witch is gebouwd op het werk van [Boardwalk](https://github.com/zhuowei/Boardwalk), de [PojavLauncher](https://github.com/PojavLauncherTeam) gemeenschap, Amethyst-iOS en Amethyst-iOS-25. Het is een onafhankelijk project en is niet aangesloten bij Mojang Studios, Microsoft of het upstream Amethyst-team.

> **Huidige versie:** 0.0.4 · Zie [`news.md`](../../news.md) voor release-opmerkingen.

---

<a id="features"></a>
## Kenmerken

### Minecraft en modificaties

- Draait de meeste **Minecraft: Java Edition**-versies, van vroege bètaversies tot de nieuwste snapshots.
- Ondersteunt **Vanille, Fabric, Quilt, Forge, NeoForge en OptiFine**.
- Maak geïsoleerde **gameprofielen** met hun eigen instellingen, mods, shaders, resourcepakketten en werelden.
- Blader en installeer inhoud van **Modrinth en CurseForge** zonder het opstartprogramma te verlaten:
  - mods
  - modpacks
  - shader-pakketten
  - resourcepakketten
  - avonturenkaarten en werelden
- Los mod-afhankelijkheden op en installeer deze waar de bron deze biedt.
- Importeer JAR's van het installatieprogramma Forge/NeoForge en installeer de laders van Fabric/Quilt rechtstreeks vanuit de versiekiezer.

### Grafisch en prestatie

- Schakel tussen meerdere renderers via **Instellingen → Renderer en weergave**:
  - **gl4es** — OpenGL 2.1 compatibiliteitspad
  - **ANGLE** — OpenGL ES tot en met Metal of Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimenteel
  - **Zink** — OpenGL 4.1 tot en met Mesa 25 en MoltenVK
  - **LTW** — OpenGL 3.3 tot en met OpenGL ES/Metal, Minecraft 1.17+, experimenteel
  - **TGLMT** — OpenGL 4.6 Core tot en met Metal, A11 Bionic of nieuwer
- **TGLMT met Sodium- en Iris-ondersteuning** voor moderne, op shader gebaseerde instellingen.
- **Framegeneratie** met Motion-Adaptive GPU (MADI) en Camera 3D Reproject-modi, inclusief temporele interpolatie en voorspellende extrapolatie.
- Resolutieschaling, maximale framerate, FSR 1.0-opschaling, GLSL-shadercaches en afstemming per renderer.
- Prestatie-HUD met configureerbare FPS-, CPU-, GPU-, RAM-, temperatuur-, batterij-, klok- en FPS-widgets voor framegeneratie.
- Ingebouwde prestatieregistratie met grafieken, PNG/PDF exporteren en delen.

### Controles

- Volledig aanpasbare bedieningslay-outs, knopgroottes en transparantie op het scherm.
- Ondersteuning voor **toetsenbord en muis**, inclusief een virtuele muis en instelbare aanwijzersnelheid.
- Ondersteuning voor **Gamecontroller** met configureerbare lay-outs en gevoeligheid.
- **Gyroscoop** richten met instelbare gevoeligheid en asinversie.
- Muis-, scroll- en hotbar-gebaren.
- Optioneel gedrag: tik om blokken te plaatsen, houd ingedrukt om blokken te breken.
- Dubbeltik op de hotbar om het vastgehouden item in de hand te wisselen.
- Verschuifbare hotbar en instelbare timing voor lang indrukken.

### Launcher en accounts

- **Microsoft**, **lokaal/offline**, **demo** en **Ely.by** accountondersteuning.
- Beheer de runtimes van **Java 8, 17, 21 en 25**, download ze in de app of importeer uw eigen runtimes.
- Selecteer LWJGL-versies en stem JVM-argumenten, omgevingsvariabelen en geheugentoewijzing af.
- Automatisch RAM-beheer voor apparaten met beperkt geheugen.
- Thema's, accentkleuren, vervaging, randen, hoekradius, aangepaste launcher-lettertypen en app-pictogrammen.
- In-game **F3 apparaatinformatie**: apparaatchip, iOS-versie, naam/versie van het opstartprogramma, buildnummer en buildtype.
- Optionele **Witch Server**-, CurseForge- en AI-integraties voor geavanceerde instellingen.
- **52 in-app-talen**, inclusief taalpakketten van rechts naar links en leuke landinstellingen.

---

<a id="screenshots"></a>
## Schermafbeeldingen

Schermafbeeldingen van een ontwikkelingsbuild van Witch Launcher 0.0.4. De interface kan wisselen tussen versies en thema's.

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
## Vereisten

| Vereiste | Details |
|---|---|
| **Apparaat** | iPhone of iPad met een arm64-processor en Metal-ondersteuning |
| **Systeem** | iOS of iPadOS **14.0 of nieuwer** |
| **JIT** | Vereist. Schakel JIT in via StikDebug, SideStore, TrollStore of een gejailbreakte installatie |
| **Account** | Een Microsoft-account dat eigenaar is van Minecraft voor officiële downloads; lokale en demomodi zijn ook beschikbaar |
| **Opslag** | Ruimte voor de launcher, Java runtimes, gameversies, mods en werelden |
| **Netwerk** | Vereist voor inloggen, versiedownloads, de inhoudsbrowser en optionele online services |

Witch omvat **geen** Minecraft-spelbestanden. Spelbestanden worden gedownload via het opstartprogramma nadat u zich heeft aangemeld bij een in aanmerking komend account.

### JIT-aantekeningen

Minecraft: Java Edition heeft JIT nodig, en Witch kan het spel niet starten zonder.

- **Installaties in SideStore / AltStore-stijl:** schakel JIT in voor Witch en houd de vereiste VPN/debugger-verbinding actief. Het in-app-bericht verwijst naar **LocalDevVPN** en `CS_DEBUGGED`.
- **StikDebug:** koppel StikDebug aan Witch en schakel JIT in. Op **iOS 26/27** moet StikDebug aangesloten blijven terwijl het spel actief is. `UniversalJIT26.js` wordt indien nodig naar het klembord gekopieerd.
- **TrollStore:** schakel **URL Scheme** in TrollStore in als Witch blijft wachten op JIT.
- **Gejailbreakte apparaten:** gebruik uw favoriete JIT-enabler.
- Als het opstartprogramma op het scherm **Wachten op JIT** blijft staan, controleer dan de debuggerverbinding, de VPN en de TrollStore URL Scheme-instelling voordat u opnieuw start.

Het gedrag van JIT is afhankelijk van de iOS-versie en installatiemethode. Systeemupdates kunnen bestaande JIT-instellingen verbreken.

---

<a id="installation"></a>
## Installatie

Witch moet voor uw apparaat zijn ondertekend. Deze repository verzendt geen certificaten of vooraf ondertekende IPA's.

### Gebruik een constructie

1. Download een ontwikkelingsbuild uit de [ontwikkelingsworkflow](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), of gebruik een ondertekende build van een bron die u vertrouwt.
2. Onderteken en installeer het met **SideStore**, **AltStore**, **TrollStore** of de sideloading-methode van uw voorkeur.
3. Schakel JIT in zoals hierboven beschreven voordat u het spel start.

TrollStore-builds gebruiken aanvullende rechten en mogen niet worden geïnstalleerd met een normale sideloading-ondertekenaar.

### Bouw vanuit de bron

Voor het compileren van Witch zijn macOS met Xcode opdrachtregelprogramma's, een iOS SDK 14.0 of nieuwer, CMake, JDK 8, `ldid`, `wget`, `zip` en Git vereist.

```bash
git kloon --recursieve https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Verpakte builds worden geschreven naar `artifacts/`.

Om in plaats daarvan een TrollStore-pakket te bouwen:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Zie [`note.md`](../../note.md) voor bronlinks naar de renderer en build-opmerkingen.

---

<a id="languages"></a>
## Talen

Witch Launcher wordt geleverd met **52 taalpakketten**. Open **Instellingen → Algemeen → Taal** en selecteer een taal, of gebruik **Auto** om de apparaattaal te volgen.

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

De app verzendt alle **52 taalpakketten**. README-vertalingen zijn beschikbaar voor **alle 52 talen**, inclusief Engels.

Sommige vertalingen worden machinaal ondersteund en kunnen lastige technische termen bevatten. Correcties zijn welkom.

Engels is de brontaal voor deze README. Gelokaliseerde README's zijn beschikbaar via de taalkiezer bovenaan deze pagina en in de directory [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Opmerkingen en beperkingen

- **JIT is verplicht.** Zonder een werkende JIT-installatie wordt Minecraft niet gestart.
- **iOS 26/27 JIT is kwetsbaar.** StikDebug moet verbonden blijven, en toekomstige OS-updates kunnen veranderen wat werkt.
- Renderers die als **experimenteel** zijn gemarkeerd, kunnen crashen of onjuist worden weergegeven. Begin met **Auto** als u het niet zeker weet.
- **Framegeneratie** vereist de MoltenVK-renderer en Metal-computerondersteuning. Het kan het batterijgebruik en de apparaattemperatuur verhogen.
- Voor sommige mods, modpacks, shaders en werelden is mogelijk een specifieke Minecraft-versie, loader, renderer of extra geheugen vereist.
- CurseForge modpacks gebruiken `manifest.json`; als installatie met één tik niet beschikbaar is voor een pakket, importeer het archief dan handmatig.
- Onlinefuncties zijn afhankelijk van services van derden en zijn mogelijk niet beschikbaar.
- Schermafbeeldingen zijn afkomstig van een ontwikkelingsbuild en komen mogelijk niet exact overeen met de huidige release.

---

<a id="project-lineage"></a>
## Projectlijn

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

### Gerelateerde projecten

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Bijdragen

Bugrapporten en PR's zijn welkom. Wanneer u een probleem rapporteert, vermeld dan:

- apparaatmodel en iOS/iPadOS-versie
- Witch Launcher-versie
- renderer en Minecraft-versie
- mod loader en een lijst met geïnstalleerde mods
- stappen om te reproduceren
- het relevante log- of crashrapport

Leg geen handtekeningcertificaten, inrichtingsprofielen, API-sleutels of andere geheimen vast.

---

<a id="credits"></a>
## Kredieten

**Witch Launcher** wordt onderhouden door **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Stroomopwaarts en gemeenschap

Witch Launcher en zijn upstream-projecten zijn gebaseerd op het werk van vele bijdragers, waaronder:

- **@crystall1nedev** — Amethyst projectmanager en iOS poortontwikkelaar
- **@khanhduytran0** — iOS poortontwikkelaar
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Verdere dank aan **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, het ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla en de Minecraft gemeenschap.

Speciale dank aan [MCHeads](https://mc-heads.net) voor het leveren van Minecraft avatardiensten.

De volledige lijst met componenten en licenties van derden is beschikbaar in [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licentie

Witch Launcher wordt gedistribueerd onder de **GNU General Public License v3.0**, onderworpen aan de licenties en auteursrechtvereisten van de componenten van derden vermeld in [`credits.md`](../../credits.md).

Zie [`LICENSE`](../../LICENSE) voor de volledige licentietekst.

---

<p align="center">
<sub>Minecraft is een handelsmerk van Mojang Studios. Witch Launcher is niet aangesloten bij Mojang Studios, Microsoft of het Amethyst-project.</sub>
</p>
