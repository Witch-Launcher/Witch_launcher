<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition på iPhone og iPad.</strong><br>
En fellesskapsbygd iOS og iPadOS gaffel av Amethyst, vedlikeholdt av DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funksjoner](#features) · [Skjermbilder](#screenshots) · [Krav](#requirements) · [Installasjon](#installation) · [Språk](#languages) · [Kreditt](#credits) · [Lisens](#license)

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

**Witch Launcher** er en uavhengig, fellesskapsvedlikeholdt gaffel av [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) som bringer **Minecraft: Java Edition** til iPhone og iPad. Den kombinerer et brukergrensesnitt for berøring først med en full Java runtime manager, LWJGL, og en grafikkstabel bygget rundt Metal, MoltenVK og OpenGL oversettelseslag.

Witch er bygget på arbeidet til [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) fellesskapet, Amethyst-iOS og Amethyst-iOS-25. Det er et selvstendig prosjekt og er ikke tilknyttet Mojang Studios, Microsoft eller oppstrøms Amethyst-teamet.

> **Gjeldende versjon:** 0.0.4 · Se [`news.md`](../../news.md) for utgivelsesnotater.

---

<a id="features"></a>
## Funksjoner

### Minecraft og mods

- Kjører de fleste **Minecraft: Java Edition**-versjoner, fra tidlige beta-utgivelser til de siste øyeblikksbildene.
- Støtter **Vanilla, Fabric, Quilt, Forge, NeoForge og OptiFine**.
- Lag isolerte **spillprofiler** med sine egne innstillinger, mods, shaders, ressurspakker og verdener.
- Bla gjennom og installer innhold fra **Modrinth og CurseForge** uten å forlate startprogrammet:
  - mods
  - modpacks
  - shader-pakker
  - ressurspakker
  - eventyrkart og verdener
- Løs og installer mod-avhengigheter der kilden gir dem.
- Importer Forge/NeoForge installatør JARer og installer Fabric/Quilt lastere direkte fra versjonsvelgeren.

### Grafikk og ytelse

- Bytt mellom flere gjengivere fra **Innstillinger → Gjengiver og visning**:
  - **gl4es** — OpenGL 2.1 kompatibilitetsbane
  - **ANGLE** — OpenGL ES til og med Metal eller Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimentell
  - **Zink** — OpenGL 4.1 til og med Mesa 25 og MoltenVK
  - **LTW** — OpenGL 3.3 til og med OpenGL ES/Metal, Minecraft 1.17+, eksperimentell
  - **TGLMT** — OpenGL 4.6 Kjerne til Metal, A11 Bionic eller nyere
- **TGLMT med Sodium og Iris støtte** for moderne shader-baserte oppsett.
- **Rammegenerering** med Motion-Adaptive GPU (MADI) og Camera 3D Reproject modi, inkludert tidsmessig interpolasjon og prediktiv ekstrapolering.
- Oppløsningsskalering, maksimal bildefrekvens, FSR 1.0 oppskalering, GLSL shader cacher og justering per gjengiver.
- Ytelse HUD med konfigurerbare FPS, CPU, GPU, RAM, temperatur, batteri, klokke og rammegenerasjons FPS-widgets.
- Innebygd ytelsesopptak med diagrammer, PNG/PDF eksport og deling.

### Kontroller

- Fullt tilpassbare kontrolloppsett på skjermen, knappestørrelser og gjennomsiktighet.
- Støtte for **tastatur og mus**, inkludert en virtuell mus og justerbar pekerhastighet.
- Støtte for **Spillkontroller** med konfigurerbare oppsett og følsomhet.
- **Gyroskop**-sikting med justerbar følsomhet og akseinversjon.
- Mus-, rull- og hotbar-bevegelser.
- Valgfri oppførsel: trykk for å plassere blokker, hold for å bryte blokker.
- Dobbelttrykk på hotbaren for å bytte det holdte elementet til off-hand.
- Skyvbar hotbar og justerbar langtrykkstid.

### Launcher og kontoer

- **Microsoft**, **lokal/frakoblet**, **demo** og **Ely.by** kontostøtte.
- Administrer **Java 8, 17, 21 og 25** kjøretider, last dem ned i appen eller importer dine egne.
- Velg LWJGL-versjoner og juster JVM-argumenter, miljøvariabler og minneallokering.
- Automatisk RAM-administrasjon for enheter med begrenset minne.
- Temaer, aksentfarger, uskarphet, kanter, hjørneradius, egendefinerte oppstartsfonter og appikoner.
- In-game **F3 enhetsinformasjon**: enhetsbrikke, iOS versjon, startnavn/versjon, byggenummer og byggetype.
- Valgfrie **Witch Server**, CurseForge og AI integrasjoner for avanserte oppsett.
- **52 språk i appen**, inkludert språkpakker fra høyre til venstre og morsomme språk.

---

<a id="screenshots"></a>
## Skjermbilder

Skjermbilder fra en utviklingsbygging av Witch Launcher 0.0.4. Grensesnittet kan skifte mellom versjoner og temaer.

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
| **Enhet** | iPhone eller iPad med en arm64-behandler og Metal støtte |
| **System** | iOS eller iPadOS **14.0 eller nyere** |
| **JIT** | Obligatorisk. Aktiver JIT til StikDebug, SideStore, TrollStore, eller et jailbroken oppsett |
| **Konto** | En Microsoft-konto som eier Minecraft for offisielle nedlastinger; lokale og demo-moduser er også tilgjengelige |
| **Lagring** | Plass til lanseringen, Java kjøretider, spillversjoner, mods og verdener |
| **Nettverk** | Nødvendig for pålogging, versjonsnedlastinger, innholdsleseren og valgfrie nettjenester |

Witch inkluderer **ikke** Minecraft spillfiler. Spillfiler lastes ned gjennom startprogrammet etter at du har logget på en kvalifisert konto.

### JIT merknader

Minecraft: Java Edition trenger JIT, og Witch kan ikke starte spillet uten.

- **SideStore / AltStore-lignende installasjoner:** aktiver JIT for Witch og hold den nødvendige VPN/debugger-tilkoblingen aktiv. Meldingen i appen viser til **LocalDevVPN** og `CS_DEBUGGED`.
- **StikDebug:** legg ved StikDebug til Witch og aktiver JIT. På **iOS 26/27** må StikDebug forbli tilkoblet mens spillet kjører. `UniversalJIT26.js` kopieres til utklippstavlen ved behov.
- **TrollStore:** aktiver **URL Scheme** i TrollStore hvis Witch fortsetter å vente på JIT.
- **Jailbroken enheter:** bruk din foretrukne JIT aktivering.
- Hvis startprogrammet forblir på **Venter på JIT**-skjermen, kontroller feilsøkingstilkoblingen, VPN og TrollStore URL Scheme-innstillingen før du starter på nytt.

JIT oppførsel avhenger av iOS versjon og installasjonsmetode. Systemoppdateringer kan bryte eksisterende JIT-oppsett.

---

<a id="installation"></a>
## Installasjon

Witch må være signert for enheten din. Dette depotet sender ikke sertifikater eller forhåndssignerte IPAer.

### Bruk en build

1. Last ned et utviklingsbygg fra [utviklingsarbeidsflyten](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), eller bruk et signert bygg fra en kilde du stoler på.
2. Signer og installer den med **SideStore**, **AltStore**, **TrollStore**, eller din foretrukne sidelastingsmetode.
3. Aktiver JIT som beskrevet ovenfor før du starter spillet.

TrollStore-bygg bruker tilleggsrettigheter og bør ikke installeres med en vanlig sidelaster.

### Bygg fra kilden

Å kompilere Witch krever macOS med Xcode kommandolinjeverktøy, en iOS SDK 14.0 eller nyere, CMake, JDK 8, `ldid`, `wget`, `zip` og Git.

```bash
git clone --rekursiv https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Pakkede bygg skrives til `artifacts/`.

For å bygge en TrollStore-pakke i stedet:

```bash
make package TROLLSTORE_JIT_ENT=1
```

For gjengivelseskildelenker og byggenotater, se [`note.md`](../../note.md).

---

<a id="languages"></a>
## Språk

Witch Launcher leveres med **52 språkpakker**. Åpne **Innstillinger → Generelt → Språk** og velg et språk, eller bruk **Auto** for å følge enhetsspråket.

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

Appen sender alle **52 språkpakker**. README-oversettelser er tilgjengelige for **alle 52 språk**, inkludert engelsk.

Noen oversettelser er maskinassistert og kan inneholde vanskelige tekniske termer. Rettelser er velkomne.

Engelsk er kildespråket for denne README. Lokaliserte README-er er tilgjengelige fra språkvelgeren øverst på denne siden og i katalogen [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Merknader og begrensninger

- **JIT er obligatorisk.** Uten et fungerende JIT-oppsett vil ikke Minecraft starte.
- **iOS 26/27 JIT er skjør.** StikDebug må forbli vedlagt, og fremtidige OS-oppdateringer kan endre hva som fungerer.
- Gjengivere merket med **eksperimentell** kan krasje eller gjengi feil. Start med **Auto** hvis du er usikker.
- **Rammegenerering** krever MoltenVK gjengivelse og Metal databehandlingsstøtte. Det kan øke batteribruken og enhetens temperatur.
- Noen mods, modpacks, shaders og verdener kan kreve en spesifikk Minecraft-versjon, loader, renderer eller ekstra minne.
- CurseForge modpacks bruker `manifest.json`; Hvis installering med ett trykk ikke er tilgjengelig for en pakke, importerer du arkivet manuelt.
- Nettfunksjoner avhenger av tredjepartstjenester og kan være utilgjengelige.
- Skjermbilder er fra en utviklingsbygging og samsvarer kanskje ikke nøyaktig med gjeldende utgivelse.

---

<a id="project-lineage"></a>
## Prosjektslekt

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

### Relaterte prosjekter

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Bidrar

Feilrapporter og PR er velkomne. Når du rapporterer et problem, ta med:

- enhetsmodell og iOS/iPadOS versjon
- Witch Launcher versjon
- gjengiver og Minecraft versjon
- mod loader og en liste over installerte mods
- trinn for å reprodusere
- den relevante loggen eller krasjrapporten

Vennligst ikke begå signeringssertifikater, klargjøringsprofiler, API-nøkler eller andre hemmeligheter.

---

<a id="credits"></a>
## Studiepoeng

**Witch Launcher** vedlikeholdes av **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Oppstrøms og fellesskap

Witch Launcher og dets oppstrømsprosjekter er bygget på arbeidet til mange bidragsytere, inkludert:

- **@crystall1nedev** — Amethyst prosjektleder og iOS portutvikler
- **@khanhduytran0** — iOS portutvikler
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Ytterligere takk til **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE-prosjektet, Khronos-gruppen, Mesa-prosjektet, PojavLauncher-teamet, Mozilla og Minecraft-fellesskapet.

Spesiell takk til [MCHeads](https://mc-heads.net) for å tilby Minecraft avatartjenester.

Den komplette tredjepartskomponenten og lisenslisten er tilgjengelig i [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lisens

Witch Launcher distribueres under **GNU General Public License v3.0**, underlagt lisensene og opphavsrettskravene til tredjepartskomponentene oppført i [`credits.md`](../../credits.md).

Se [`LICENSE`](../../LICENSE) for den fullstendige lisensteksten.

---

<p align="center">
<sub>Minecraft er et varemerke for Mojang Studios. Witch Launcher er ikke tilknyttet Mojang Studios, Microsoft, eller Amethyst-prosjektet.</sub>
</p>
