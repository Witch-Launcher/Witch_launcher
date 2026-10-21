<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition op iPhone en iPad.</strong><br>
'n Gemeenskapsgeboude iOS en iPadOS vurk van Amethyst, onderhou deur DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Kenmerke](#features) · [Skermkiekies](#screenshots) · [Vereistes](#requirements) · [Installasie](#installation) · [Tale](#languages) · [Krediete](#credits) · [Lisensie](#license)

<details>
<summary><strong>Tale</strong></summary>

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
## Oor

**Witch Launcher** is 'n onafhanklike, gemeenskap-onderhou vurk van [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) wat **Minecraft: Java Edition** na iPhone en iPad bring. Dit kombineer 'n raak-eerste lanseerder UI met 'n volledige Java runtime bestuurder, LWJGL, en 'n grafiese stapel gebou rondom Metal, MoltenVK, en OpenGL vertaallae.

Witch is gebou op die werk van [Boardwalk](https://github.com/zhuowei/Boardwalk), die [PojavLauncher](https://github.com/PojavLauncherTeam) gemeenskap, Amethyst-iOS, en Amethyst-iOS-25. Dit is 'n onafhanklike projek en is nie geaffilieer met Mojang Studios, Microsoft of die stroomop Amethyst-span nie.

> **Huidige weergawe:** 0.0.4 · Sien [`news.md`](../../news.md) vir vrystellingnotas.

---

<a id="features"></a>
## Kenmerke

### Minecraft en mods

- Laat loop die meeste **Minecraft: Java Edition** weergawes, vanaf vroeë Beta-vrystellings tot die jongste kiekies.
- Ondersteun **Vanilla, Fabric, Quilt, Forge, NeoForge en OptiFine**.
- Skep geïsoleerde **speletjieprofiele** met hul eie instellings, mods, shaders, hulpbronpakke en wêrelde.
- Blaai deur en installeer inhoud vanaf **Modrinth en CurseForge** sonder om die lanseerder te verlaat:
  - mods
  - modpacks
  - shader pakke
  - hulpbronpakke
  - avontuurkaarte en wêrelde
- Los en installeer mod-afhanklikhede waar die bron dit verskaf.
- Voer Forge/NeoForge installeerder JAR's in en installeer Fabric/Quilt laaiers direk vanaf die weergawekieser.

### Grafika en prestasie

- Wissel tussen veelvuldige verskaffers vanaf **Instellings → Weerder en vertoon**:
  - **gl4es** — OpenGL 2.1 versoenbaarheidspad
  - **ANGLE** — OpenGL ES tot Metal of Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimenteel
  - **Zink** — OpenGL 4.1 tot en met Mesa 25 en MoltenVK
  - **LTW** — OpenGL 3.3 tot OpenGL ES/Metal, Minecraft 1.17+, eksperimenteel
  - **TGLMT** — OpenGL 4.6 Kern deur Metal, A11 Bionic of nuwer
- **TGLMT met Sodium en Iris ondersteuning** vir moderne skakering-gebaseerde opstellings.
- **Raamgenerering** met Motion-Adaptive GPU (MADI) en kamera 3D-herprojeksiemodusse, insluitend tydelike interpolasie en voorspellende ekstrapolasie.
- Resolusie-skaal, maksimum raamsnelheid, FSR 1.0 opskaling, GLSL-skakeringkas, en per-weergawe-instelling.
- Prestasie-HUD met konfigureerbare FPS, SVE, GPU, RAM, temperatuur, battery, horlosie en raamgenerasie FPS-legstukke.
- Ingeboude prestasie-opname met kaarte, PNG/PDF uitvoer en deel.

### Kontroles

- Volledig aanpasbare skermbeheeruitlegte, knoppiegroottes en deursigtigheid.
- **Sleutelbord- en muis**-ondersteuning, insluitend 'n virtuele muis en verstelbare wyserspoed.
- **Spelbeheerder**-ondersteuning met konfigureerbare uitlegte en sensitiwiteit.
- **Giroskoop** mik met verstelbare sensitiwiteit en as-inversie.
- Muis-, rol- en hotbar-gebare.
- Opsionele gedrag: tik om blokke te plaas, hou vas om blokke te breek.
- Dubbeltik op die warmbalk om die gehoude item in die hand te ruil.
- Skuifbare warmbalk en verstelbare tydsberekening vir lang druk.

### Launcher en rekeninge

- **Microsoft**, **plaaslik/vanlyn**, **demo** en **Ely.by** rekeningondersteuning.
- Bestuur **Java 8, 17, 21 en 25** looptye, laai dit in die toepassing af, of voer jou eie in.
- Kies LWJGL weergawes en stel JVM-argumente, omgewingsveranderlikes en geheuetoewysing in.
- Outo-RAM-bestuur vir toestelle met beperkte geheue.
- Temas, aksentkleure, vervaag, grense, hoekradius, pasgemaakte lanseerderlettertipes en toepassingikone.
- In-speletjie **F3 toestelinligting**: toestelskyfie, iOS weergawe, lanseerdernaam/weergawe, bounommer en boutipe.
- Opsionele **Witch Bediener**, CurseForge en AI integrasies vir gevorderde opstellings.
- **52 inprogram-tale**, insluitend regs-na-links-taalpakkette en prettige plekke.

---

<a id="screenshots"></a>
## Skermskote

Skermskote van 'n ontwikkelingsbou van Witch Launcher 0.0.4. Die koppelvlak kan tussen weergawes en temas verander.

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
## Vereistes

| Vereiste | Besonderhede |
|---|---|
| **Toestel** | iPhone of iPad met 'n arm64 verwerker en Metal ondersteuning |
| **Stelsel** | iOS of iPadOS **14.0 of nuwer** |
| **JIT** | Vereis. Aktiveer JIT deur StikDebug, SideStore, TrollStore, of 'n jailbroken-opstelling |
| **Rekening** | 'n Microsoft rekening wat Minecraft besit vir amptelike aflaaie; plaaslike en demo-modusse is ook beskikbaar |
| **Berging** | Ruimte vir die lanseerder, Java looptye, speletjieweergawes, mods en wêrelde |
| **Netwerk** | Vereis vir aanmelding, weergawe-aflaaie, die inhoudblaaier en opsionele aanlyndienste |

Witch sluit **nie** Minecraft speletjielêers in. Speletjielêers word deur die lanseerder afgelaai nadat by 'n kwalifiserende rekening aangemeld is.

### JIT notas

Minecraft: Java Edition benodig JIT, en Witch kan nie die speletjie daarsonder begin nie.

- **SideStore / AltStore-styl installasies:** aktiveer JIT vir Witch en hou die vereiste VPN/ontfouterverbinding aktief. Die inprogram-boodskap verwys na **LocalDevVPN** en `CS_DEBUGGED`.
- **StikDebug:** heg StikDebug aan Witch en aktiveer JIT. Op **iOS 26/27** moet StikDebug aangeheg bly terwyl die speletjie aan die gang is. `UniversalJIT26.js` word na die knipbord gekopieer wanneer nodig.
- **TrollStore:** aktiveer **URL Scheme** in TrollStore as Witch aanhou wag vir JIT.
- **Jailbroken-toestelle:** gebruik jou voorkeur JIT-aktiveerder.
- As die lanseerder op die **Wag vir JIT**-skerm bly, kontroleer die ontfouterverbinding, die VPN en die TrollStore URL Scheme-instelling voor herbegin.

JIT gedrag hang af van die iOS weergawe en installasie metode. Stelselopdaterings kan bestaande JIT-opstellings breek.

---

<a id="installation"></a>
## Installasie

Witch moet vir jou toestel onderteken word. Hierdie bewaarplek stuur nie sertifikate of vooraf ondertekende IPA's nie.

### Gebruik 'n bou

1. Laai 'n ontwikkelingsbou af vanaf die [ontwikkelingswerkvloei](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), of gebruik 'n getekende bou van 'n bron wat jy vertrou.
2. Teken en installeer dit met **SideStore**, **AltStore**, **TrollStore**, of jou voorkeur-sylaaimetode.
3. Aktiveer JIT soos hierbo beskryf voordat die speletjie begin word.

TrollStore geboue gebruik bykomende regte en moet nie met 'n normale sylaai-tekenaar geïnstalleer word nie.

### Bou uit bron

Om Witch saam te stel vereis macOS met Xcode opdragreëlnutsgoed, 'n iOS SDK 14.0 of nuwer, CMake, JDK 8, `ldid`, `wget`, `zip` en Git.

```bash
git kloon --rekursiewe https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Verpakte bouwerk word geskryf na `artifacts/`.

Om eerder 'n TrollStore-pakket te bou:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Sien [`note.md`](../../note.md) vir bronskakels en bounotas.

---

<a id="languages"></a>
## Tale

Witch Launcher word met **52 taalpakke** gestuur. Maak **Instellings → Algemeen → Taal** oop en kies 'n taal, of gebruik **Outo** om die toesteltaal te volg.

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

Die toepassing stuur alle **52 taalpakke**. README-vertalings is beskikbaar vir **al 52 tale**, insluitend Engels.

Sommige vertalings is masjiengesteun en kan ongemaklike tegniese terme bevat. Regstellings is welkom.

Engels is die brontaal vir hierdie README. Gelokaliseerde README's is beskikbaar vanaf die taalkieser boaan hierdie bladsy en in die [`docs/readme/`](./) gids.

---

<a id="notes-and-limitations"></a>
## Notas en beperkings

- **JIT is verpligtend.** Sonder 'n werkende JIT-opstelling sal Minecraft nie begin nie.
- **iOS 26/27 JIT is broos.** StikDebug moet aangeheg bly, en toekomstige OS-opdaterings kan verander wat werk.
- Leweraars wat as **eksperimenteel** gemerk is, kan omval of verkeerd weergee. Begin met **Outo** as jy onseker is.
- **Raamgenerering** vereis die MoltenVK-weergawe en Metal rekenaarondersteuning. Dit kan batterygebruik en toesteltemperatuur verhoog.
- Sommige mods, modpacks, shaders en wêrelde mag 'n spesifieke Minecraft weergawe, laaier, weergawe of addisionele geheue vereis.
- CurseForge modpacks gebruik `manifest.json`; as een-tik-installasie nie vir 'n pakkie beskikbaar is nie, voer die argief handmatig in.
- Aanlynkenmerke is afhanklik van derdepartydienste en kan dalk onbeskikbaar wees.
- Skermkiekies is van 'n ontwikkelingsbou en sal dalk nie presies ooreenstem met die huidige weergawe nie.

---

<a id="project-lineage"></a>
## Projek afkoms

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

### Verwante projekte

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Bydraend

Foutverslae en PR's is welkom. Wanneer 'n probleem gerapporteer word, sluit in:

- toestelmodel en iOS/iPadOS weergawe
- Witch Launcher weergawe
- renderer en Minecraft weergawe
- mod loader en 'n lys van geïnstalleerde mods
- stappe om voort te plant
- die betrokke log of ongelukverslag

Moet asseblief nie ondertekeningsertifikate, voorsieningsprofiele, API-sleutels of ander geheime verbind nie.

---

<a id="credits"></a>
## Krediete

**Witch Launcher** word onderhou deur **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Stroomop en gemeenskap

Witch Launcher en sy stroomop-projekte is gebou op die werk van baie bydraers, insluitend:

- **@crystall1nedev** — Amethyst projekbestuurder en iOS poortontwikkelaar
- **@khanhduytran0** — iOS poortontwikkelaar
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Bykomende dank aan **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, die ANGLE-projek, Khronos-groep, Mesa-projek, PojavLauncher-span, Mozilla en die Minecraft-gemeenskap.

Spesiale dank aan [MCHeads](https://mc-heads.net) vir die verskaffing van Minecraft avatardienste.

Die volledige derdeparty-komponent en lisensielys is beskikbaar in [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lisensie

Witch Launcher word versprei onder die **GNU General Public License v3.0**, onderhewig aan die lisensies en kopieregvereistes van die derdeparty-komponente gelys in [`credits.md`](../../credits.md).

Sien [`LICENSE`](../../LICENSE) vir die volledige lisensieteks.

---

<p align="center">
<sub>Minecraft is 'n handelsmerk van Mojang Studios. Witch Launcher is nie geaffilieer met Mojang Studios, Microsoft of die Amethyst-projek nie.</sub>
</p>
