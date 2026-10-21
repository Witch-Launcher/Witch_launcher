<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition na iPhone a iPad.</strong><br>
Komunitne vytvorená vidlica iOS a iPadOS Amethyst, ktorú spravuje DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funkcie](#features) · [Snímky obrazovky](#screenshots) · [Požiadavky](#requirements) · [Inštalácia](#installation) · [Jazyky](#languages) · [Kredity](#credits) · [Licencia](#license)

<details>
<summary><strong>Jazyky</strong></summary>

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
## O

**Witch Launcher** je nezávislá komunita spravovaná vidlica [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), ktorá prináša **Minecraft: Java Edition** do iPhone a iPad. Kombinuje dotykové spúšťacie používateľské rozhranie s úplným správcom runtime Java, LWJGL, a grafickým zásobníkom postaveným na prekladových vrstvách Metal, MoltenVK a OpenGL.

Witch je postavený na práci [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) spoločenstva, Amethyst-iOS a Amethyst-iOS-25. Je to nezávislý projekt a nie je pridružený k tímu Mojang Studios, Microsoft ani k predchádzajúcemu tímu Amethyst.

> **Aktuálna verzia:** 0.0.4 · Pozri [`news.md`](../../news.md) pre poznámky k vydaniu.

---

<a id="features"></a>
## Vlastnosti

### Minecraft a mods

- Spúšťa väčšinu verzií **Minecraft: Java Edition**, od prvých verzií beta až po najnovšie snímky.
- Podporuje **vanilku, Fabric, Quilt, Forge, NeoForge a OptiFine**.
- Vytvorte izolované **herné profily** s vlastnými nastaveniami, modifikáciami, shadermi, balíkmi zdrojov a svetmi.
- Prehliadajte a inštalujte obsah z **Modrinth a CurseForge** bez opustenia spúšťača:
  - mods
  - modpacks
  - shader balíčky
  - zdrojových balíkov
  - dobrodružné mapy a svety
- Vyriešte a nainštalujte závislosti modov tam, kde ich zdroj poskytuje.
- Importujte inštalačné JAR Forge/NeoForge a nainštalujte nakladače Fabric/Quilt priamo z výberu verzie.

### Grafika a výkon

- Prepínajte medzi viacerými vykresľovacími modulmi v časti **Nastavenia → Vykresľovací modul a zobrazenie**:
  - **gl4es** — OpenGL 2.1 cesta kompatibility
  - **ANGLE** — OpenGL ES až Metal alebo Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimentálne
  - **Zink** — OpenGL 4.1 až Mesa 25 a MoltenVK
  - **LTW** — OpenGL 3.3 až OpenGL ES/Metal, Minecraft 1.17+, experimentálne
  - **TGLMT** — OpenGL 4.6 Základné až Metal, A11 Bionic alebo novšie
- **TGLMT s podporou Sodium a Iris** pre moderné nastavenia založené na shader.
- **Generovanie snímok** s GPU adaptívnym na pohyb (MADI) a režimami 3D premietania fotoaparátu vrátane časovej interpolácie a prediktívnej extrapolácie.
- Škálovanie rozlíšenia, maximálna snímková frekvencia, FSR 1.0 upscaling, vyrovnávacia pamäť shadera GLSL a ladenie podľa vykresľovača.
- Výkonnostný HUD s konfigurovateľnými miniaplikáciami FPS, CPU, GPU, RAM, teploty, batérie, hodín a FPS generovania snímok.
- Zabudované zaznamenávanie výkonu s grafmi, export PNG/PDF a zdieľanie.

### Ovládacie prvky

- Plne prispôsobiteľné rozloženia ovládacích prvkov na obrazovke, veľkosti tlačidiel a priehľadnosť.
- Podpora **klávesnice a myši** vrátane virtuálnej myši a nastaviteľnej rýchlosti ukazovateľa.
- Podpora **Herného ovládača** s konfigurovateľným rozložením a citlivosťou.
- **Gyroskop** mierenie s nastaviteľnou citlivosťou a inverziou osi.
- Gestá myši, posúvania a aktívnej lišty.
- Voliteľné správanie: klepnutím umiestnite bloky, podržaním bloky rozbijete.
- Dvojitým ťuknutím na horúcu lištu vymeníte zadržanú položku za odloženú.
- Posuvný horúci panel a nastaviteľné načasovanie dlhého stlačenia.

### Spúšťač a účty

- **Microsoft**, **lokálny/offline**, **demo** a **Ely.by** podpora účtu.
- Spravujte runtime **Java 8, 17, 21 a 25**, stiahnite si ich do aplikácie alebo importujte svoje vlastné.
- Vyberte verzie LWJGL a vylaďte argumenty JVM, premenné prostredia a alokáciu pamäte.
- Automatická správa RAM pre zariadenia s obmedzenou pamäťou.
- Motívy, zvýrazňujúce farby, rozmazanie, okraje, polomer rohov, vlastné spúšťacie písma a ikony aplikácií.
- **Informácie o zariadení F3 v hre**: čip zariadenia, verzia iOS, názov/verzia spúšťača, číslo zostavy a typ zostavy.
- Voliteľné integrácie **Witch Server**, CurseForge a AI pre pokročilé nastavenia.
- **52 jazykov v aplikácii** vrátane jazykových balíkov písaných sprava doľava a zábavných miestnych nastavení.

---

<a id="screenshots"></a>
## Snímky obrazovky

Snímky obrazovky z vývojovej zostavy Witch Launcher 0.0.4. Rozhranie sa môže meniť medzi verziami a témami.

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
## Požiadavky

| Požiadavka | Podrobnosti |
|---|---|
| **Zariadenie** | iPhone alebo iPad so spracovateľom arm64 a podporou Metal |
| **Systém** | iOS alebo iPadOS **14.0 alebo novší** |
| **JIT** | Povinné. Povoliť JIT až StikDebug, SideStore, TrollStore alebo nastavenie s jailbreakom |
| **Účet** | Microsoft účet, ktorý vlastní Minecraft na oficiálne sťahovanie; dostupné sú aj miestne a demo režimy |
| **Ukladací priestor** | Priestor pre spúšťač, Java runtime, verzie hier, mody a svety |
| **Sieť** | Vyžaduje sa pre prihlásenie, sťahovanie verzií, prehliadač obsahu a voliteľné online služby |

Witch **nezahŕňa** herné súbory Minecraft. Herné súbory sa sťahujú cez spúšťač po prihlásení do vhodného účtu.

### JIT poznámky

Minecraft: Java Edition potrebuje JIT a Witch bez neho nemôže spustiť hru.

- **Inštalácie v štýle SideStore / AltStore:** povoľte JIT pre Witch a ponechajte požadované pripojenie VPN/debugger aktívne. Správa v aplikácii odkazuje na **LocalDevVPN** a `CS_DEBUGGED`.
- **StikDebug:** pripojte StikDebug k Witch a povoľte JIT. Na **iOS 26/27** musí StikDebug zostať pripojený, kým hra beží. `UniversalJIT26.js` sa v prípade potreby skopíruje do schránky.
- **TrollStore:** povoľte **URL Scheme** v TrollStore, ak Witch stále čaká na JIT.
- **Jailbreaknuté zariadenia:** použite preferovaný aktivátor JIT.
- Ak spúšťač zostane na obrazovke **Čaká sa na JIT**, pred opätovným spustením skontrolujte pripojenie ladiaceho programu, nastavenie VPN a TrollStore URL Scheme.

Správanie JIT závisí od verzie iOS a spôsobu inštalácie. Aktualizácie systému môžu prerušiť existujúce nastavenia JIT.

---

<a id="installation"></a>
## Inštalácia

Witch musí byť pre vaše zariadenie podpísaný. Toto úložisko neposiela certifikáty ani vopred podpísané IPA.

### Použite zostavu

1. Stiahnite si vývojovú zostavu z [pracovného postupu vývoja](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) alebo použite podpísanú zostavu zo zdroja, ktorému dôverujete.
2. Podpíšte a nainštalujte ho pomocou **SideStore**, **AltStore**, **TrollStore** alebo vami preferovanou metódou bočného načítania.
3. Pred spustením hry povoľte JIT, ako je popísané vyššie.

Zostavy podľa TrollStore používajú dodatočné oprávnenia a nemali by sa inštalovať pomocou bežného podpisovateľa s bočným načítaním.

### Zostavte zo zdroja

Kompilácia Witch vyžaduje macOS s nástrojmi príkazového riadka Xcode, iOS SDK 14.0 alebo novší, CMake, JDK 8, `ldid`, `wget`, `zip` a Git.

```bash
git clone --rekurzívny https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Zabalené zostavy sú zapísané do `artifacts/`.

Ak chcete namiesto toho zostaviť balík TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Odkazy na zdroj renderera a poznámky k zostaveniu nájdete v [`note.md`](../../note.md).

---

<a id="languages"></a>
## Jazyky

Witch Launcher sa dodáva s **52 jazykovými balíkmi**. Otvorte **Nastavenia → Všeobecné → Jazyk** a vyberte jazyk alebo použite možnosť **Automaticky**, ak chcete sledovať jazyk zariadenia.

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

Aplikácia dodáva všetkých **52 jazykových balíkov**. Preklady README sú dostupné pre **všetkých 52 jazykov** vrátane angličtiny.

Niektoré preklady sú podporované strojom a môžu obsahovať nepríjemné technické výrazy. Opravy sú vítané.

Angličtina je zdrojovým jazykom tohto README. Lokalizované súbory README sú dostupné cez výber jazyka v hornej časti tejto stránky a v adresári [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Poznámky a obmedzenia

- **JIT je povinný.** Bez funkčného nastavenia JIT sa Minecraft nespustí.
- **iOS 26/27 JIT je krehký.** StikDebug musí zostať pripojený a budúce aktualizácie operačného systému môžu zmeniť fungovanie.
- Vykresľovacie nástroje označené ako **experimentálne** môžu zlyhať alebo sa môžu vykresliť nesprávne. Ak si nie ste istí, začnite s **Automaticky**.
- **Generovanie rámcov** vyžaduje vykresľovací modul MoltenVK a výpočtovú podporu Metal. Môže zvýšiť spotrebu batérie a teplotu zariadenia.
- Niektoré mody, modpacky, shadery a svety môžu vyžadovať špecifickú verziu Minecraft, zavádzač, renderer alebo dodatočnú pamäť.
- CurseForge modpacky používajú `manifest.json`; ak pre balík nie je dostupná inštalácia jedným klepnutím, importujte archív manuálne.
- Online funkcie závisia od služieb tretích strán a môžu byť nedostupné.
- Snímky obrazovky pochádzajú z vývojovej zostavy a nemusia presne zodpovedať aktuálnemu vydaniu.

---

<a id="project-lineage"></a>
## Projektová línia

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

### Súvisiace projekty

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Prispievanie

Hlásenia chýb a PR sú vítané. Pri nahlasovaní problému uveďte:

- model zariadenia a verzia iOS/iPadOS
- Witch Launcher verzia
- renderer a verzia Minecraft
- zavádzač modov a zoznam nainštalovaných modov
- kroky na reprodukciu
- príslušný denník alebo správu o zlyhaní

Prosím, nezaväzujte podpisové certifikáty, profily poskytovania, kľúče API ani iné tajomstvá.

---

<a id="credits"></a>
## Kredity

**Witch Launcher** spravuje **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream a komunita

Witch Launcher a jeho predchádzajúce projekty sú postavené na práci mnohých prispievateľov, vrátane:

- **@crystall1nedev** — Amethyst projektový manažér a iOS vývojár portu
- **@khanhduytran0** — iOS vývojár portu
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Ďalšie poďakovanie patrí **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, projektu ANGLE, skupine Khronos, projektu Mesa, tímu PojavLauncher, Mozille a komunite Minecraft.

Špeciálne poďakovanie patrí [MCHeads](https://mc-heads.net) za poskytovanie služieb avatarov podľa Minecraft.

Kompletný zoznam komponentov a licencií tretích strán je dostupný v [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licencia

Witch Launcher je distribuovaný pod **GNU General Public License v3.0**, s výhradou licencií a požiadaviek na autorské práva komponentov tretích strán uvedených v [`credits.md`](../../credits.md).

Úplný text licencie nájdete v [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft je ochranná známka Mojang Studios. Witch Launcher nie je pridružený k Mojang Studios, Microsoft alebo k projektu Amethyst.</sub>
</p>
