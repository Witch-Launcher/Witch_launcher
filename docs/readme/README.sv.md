<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition på iPhone och iPad.</strong><br>
En gemenskapsbyggd iOS och iPadOS gaffel av Amethyst, underhållen av DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funktioner](#features) · [Skärmbilder](#screenshots) · [Krav](#requirements) · [Installation](#installation) · [Språk](#languages) · [Krediter](#credits) · [Licens](#license)

<details>
<summary><strong>Språk</strong></summary>

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

**Witch Launcher** är en oberoende, gemenskapsupprätthållen gaffel av [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) som för **Minecraft: Java Edition** till iPhone och iPad. Den kombinerar ett gränssnitt för start med pek-först med en fullständig Java runtime manager, LWJGL, och en grafikstapel byggd kring Metal, MoltenVK och OpenGL översättningslager.

Witch bygger på arbetet från [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS och Amethyst-iOS-25. Det är ett oberoende projekt och är inte anslutet till Mojang Studios, Microsoft eller uppströms Amethyst-teamet.

> **Aktuell version:** 0.0.4 · Se [`news.md`](../../news.md) för release notes.

---

<a id="features"></a>
## Funktioner

### Minecraft och mods

- Kör de flesta **Minecraft: Java Edition** versioner, från tidiga betaversioner till de senaste ögonblicksbilderna.
- Stöder **Vanilla, Fabric, Quilt, Forge, NeoForge och OptiFine**.
- Skapa isolerade **spelprofiler** med sina egna inställningar, mods, shaders, resurspaket och världar.
- Bläddra och installera innehåll från **Modrinth och CurseForge** utan att lämna startprogrammet:
  - mods
  - modpacks
  - shader-paket
  - resurspaket
  - äventyrskartor och världar
- Lös och installera mod-beroenden där källan tillhandahåller dem.
- Importera Forge/NeoForge installatörs-JAR och installera Fabric/Quilt-lastare direkt från versionsväljaren.

### Grafik och prestanda

- Växla mellan flera renderare från **Inställningar → Renderare och visning**:
  - **gl4es** — OpenGL 2.1 kompatibilitetssökväg
  - **ANGLE** — OpenGL ES till Metal eller Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimentell
  - **Zink** — OpenGL 4.1 till och med Mesa 25 och MoltenVK
  - **LTW** — OpenGL 3.3 till OpenGL ES/Metal, Minecraft 1.17+, experimentell
  - **TGLMT** — OpenGL 4.6 Kärna till Metal, A11 Bionic eller senare
- **TGLMT med Sodium och Iris stöd** för moderna shader-baserade inställningar.
- **Frame Generation** med Motion-Adaptive GPU (MADI) och Camera 3D Reproject-lägen, inklusive tidsinterpolation och prediktiv extrapolering.
- Upplösningsskalning, maximal bildhastighet, FSR 1.0 uppskalning, GLSL shader-cacher och inställning per renderare.
- Prestanda HUD med konfigurerbara FPS, CPU, GPU, RAM, temperatur, batteri, klocka och ramgenerations FPS-widgets.
- Inbyggd prestationsinspelning med diagram, PNG/PDF export och delning.

### Kontroller

- Fullständigt anpassningsbara kontrolllayouter på skärmen, knappstorlekar och transparens.
- Stöd för **tangentbord och mus**, inklusive en virtuell mus och justerbar pekarhastighet.
- Stöd för **Spelkontroller** med konfigurerbara layouter och känslighet.
- **Gyroskop**-siktning med justerbar känslighet och axelinvertering.
- Gester med mus, rullning och hotbar.
- Valfritt beteende: tryck för att placera block, håll ned för att bryta block.
- Dubbelklicka på aktiveringsfältet för att byta det hållna föremålet till off-handen.
- Skjutbar hotbar och justerbar långtryckstid.

### Launcher och konton

- **Microsoft**, **lokalt/offline**, **demo** och **Ely.by** kontostöd.
- Hantera **Java 8, 17, 21 och 25** körtider, ladda ner dem i appen eller importera dina egna.
- Välj LWJGL-versioner och ställ in JVM-argument, miljövariabler och minnesallokering.
- Automatisk RAM-hantering för enheter med begränsat minne.
- Teman, accentfärger, oskärpa, kanter, hörnradie, anpassade startteckensnitt och appikoner.
- In-game **F3 enhetsinformation**: enhetschip, iOS version, launcher namn/version, build nummer och build typ.
- Valfria **Witch Server**, CurseForge och AI integrationer för avancerade inställningar.
- **52 språk i appen**, inklusive språkpaket från höger till vänster och roliga språk.

---

<a id="screenshots"></a>
## Skärmdumpar

Skärmdumpar från en utvecklingsversion av Witch Launcher 0.0.4. Gränssnittet kan växla mellan versioner och teman.

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
| **Enhet** | iPhone eller iPad med en arm64-behandlare och Metal stöd |
| **System** | iOS eller iPadOS **14.0 eller nyare** |
| **JIT** | Nödvändig. Aktivera JIT till StikDebug, SideStore, TrollStore, eller en jailbroken installation |
| **Konto** | Ett Microsoft-konto som äger Minecraft för officiella nedladdningar; lokala lägen och demolägen är också tillgängliga |
| **Lagring** | Utrymme för startprogrammet, Java körtider, spelversioner, mods och världar |
| **Nätverk** | Krävs för inloggning, versionsnedladdningar, innehållswebbläsaren och valfria onlinetjänster |

Witch inkluderar **inte** Minecraft spelfiler. Spelfiler laddas ner via startprogrammet efter att ha loggat in på ett kvalificerat konto.

### JIT anteckningar

Minecraft: Java Edition behöver JIT, och Witch kan inte starta spelet utan det.

- **SideStore / AltStore-liknande installationer:** aktivera JIT för Witch och håll den nödvändiga VPN/debugger-anslutningen aktiv. Meddelandet i appen hänvisar till **LocalDevVPN** och `CS_DEBUGGED`.
- **StikDebug:** bifoga StikDebug till Witch och aktivera JIT. På **iOS 26/27** måste StikDebug stanna kvar medan spelet körs. `UniversalJIT26.js` kopieras till urklipp vid behov.
- **TrollStore:** aktivera **URL Scheme** i TrollStore om Witch fortsätter att vänta på JIT.
- **Jailbroken-enheter:** använd din föredragna JIT-aktiverare.
- Om startprogrammet stannar på skärmen **Väntar på JIT**, kontrollera felsökningsanslutningen, VPN och TrollStore URL Scheme inställningen innan du startar om.

JIT beteende beror på iOS version och installationsmetod. Systemuppdateringar kan bryta befintliga JIT-inställningar.

---

<a id="installation"></a>
## Installation

Witch måste vara signerad för din enhet. Detta förvar skickar inte certifikat eller försignerade IPA.

### Använd en build

1. Ladda ner ett utvecklingsbygge från [utvecklingsarbetsflödet](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), eller använd ett signerat bygge från en källa du litar på.
2. Signera och installera den med **SideStore**, **AltStore**, **TrollStore** eller din föredragna sidoladdningsmetod.
3. Aktivera JIT enligt beskrivningen ovan innan du startar spelet.

Bygger i TrollStore använder ytterligare rättigheter och bör inte installeras med en normal sidoladdningssignerare.

### Bygg från källan

Att kompilera Witch kräver macOS med Xcode kommandoradsverktyg, en iOS SDK 14.0 eller nyare, CMake, JDK 8, `ldid`, `wget`, `zip` och Git.

```bash
git clone --rekursiv https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Förpackade byggen skrivs till `artifacts/`.

För att bygga ett TrollStore-paket istället:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Se [`note.md`](../../note.md) för renderarkälllänkar och bygganteckningar.

---

<a id="languages"></a>
## Språk

Witch Launcher levereras med **52 språkpaket**. Öppna **Inställningar → Allmänt → Språk** och välj ett språk, eller använd **Auto** för att följa enhetens språk.

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

Appen levererar alla **52 språkpaket**. README-översättningar finns tillgängliga för **alla 52 språk**, inklusive engelska.

Vissa översättningar är maskinassisterade och kan innehålla besvärliga tekniska termer. Rättelser är välkomna.

Engelska är källspråket för denna README. Lokaliserade README:er är tillgängliga från språkväljaren högst upp på denna sida och i katalogen [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Anteckningar och begränsningar

- **JIT är obligatoriskt.** Utan en fungerande JIT-inställning kommer Minecraft inte att starta.
- **iOS 26/27 JIT är bräcklig.** StikDebug måste förbli bifogad, och framtida OS-uppdateringar kan ändra vad som fungerar.
- Renderare märkta som **experimentella** kan krascha eller rendera felaktigt. Börja med **Auto** om du är osäker.
- **Frame Generation** kräver MoltenVK renderaren och Metal datorstöd. Det kan öka batterianvändningen och enhetens temperatur.
- Vissa mods, modpacks, shaders och världar kan kräva en specifik Minecraft-version, laddare, renderare eller ytterligare minne.
- CurseForge modpacks använder `manifest.json`; om installation med en knapptryckning inte är tillgänglig för ett paket, importera arkivet manuellt.
- Onlinefunktioner är beroende av tredjepartstjänster och kan vara otillgängliga.
- Skärmdumparna är från en utvecklingsversion och kanske inte matchar den aktuella versionen exakt.

---

<a id="project-lineage"></a>
## Projekt härstamning

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

### Relaterade projekt

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Bidrar

Felrapporter och PR är välkomna. När du rapporterar ett problem, inkludera:

- enhetsmodell och iOS/iPadOS version
- Witch Launcher version
- renderare och Minecraft version
- mod loader och en lista över installerade moddar
- steg för att reproducera
- relevant logg eller kraschrapport

Vänligen begå inte signeringscertifikat, provisioneringsprofiler, API-nycklar eller andra hemligheter.

---

<a id="credits"></a>
## Krediter

**Witch Launcher** underhålls av **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Uppströms och gemenskap

Witch Launcher och dess uppströmsprojekt bygger på många bidragsgivares arbete, inklusive:

- **@crystall1nedev** — Amethyst projektledare och iOS portutvecklare
- **@khanhduytran0** — iOS portutvecklare
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Ytterligare tack till **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE-projektet, Khronos-gruppen, Mesa-projektet, PojavLauncher-teamet, Mozilla och Minecraft-gemenskapen.

Särskilt tack till [MCHeads](https://mc-heads.net) för att du tillhandahåller avatartjänster i Minecraft.

Den fullständiga listan över tredjepartskomponenter och licenser finns i [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licens

Witch Launcher distribueras under **GNU General Public License v3.0**, med förbehåll för licenserna och upphovsrättskraven för tredjepartskomponenterna listade i [`credits.md`](../../credits.md).

Se [`LICENSE`](../../LICENSE) för den fullständiga licenstexten.

---

<p align="center">
<sub>Minecraft är ett varumärke som tillhör Mojang Studios. Witch Launcher är inte anslutet till Mojang Studios, Microsoft eller projektet Amethyst.</sub>
</p>
