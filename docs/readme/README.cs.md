<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
  <strong>Minecraft: Java Edition na iPhone a iPad.</strong><br>
Komunitně vytvořený iOS a iPadOS fork Amethyst, spravovaný DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Vlastnosti](#features) · [Snímky obrazovky](#screenshots) · [Požadavky](#requirements) · [Instalace](#installation) · [Jazyky](#languages) · [Kredity](#credits) · [Licence](#license)

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

**Witch Launcher** je nezávislý, komunitou spravovaný fork [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), který přináší **Minecraft: Java Edition** na iPhone a iPad. Kombinuje dotykové spouštěcí uživatelské rozhraní s úplným Java správcem běhového prostředí LWJGL a grafickým zásobníkem vytvořeným na překladových vrstvách Metal, MoltenVK a OpenGL.

Witch je postaven na práci [Boardwalk](https://github.com/zhuowei/Boardwalk), komunity [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS a Amethyst-iOS-25. Je to nezávislý projekt a není přidružen k týmu Mojang Studios, Microsoft nebo upstreamu Amethyst.

> **Aktuální verze:** 0.0.4 · Viz [`news.md`](../../news.md) pro poznámky k vydání.

---

<a id="features"></a>
## Vlastnosti

### Minecraft a mod

- Spouští většinu **Minecraft: Java Edition** verzí, od prvních beta verzí až po nejnovější snímky.
- Podporuje **Vanilla, Fabric, Quilt, Forge, NeoForge a OptiFine**.
- Vytvářejte izolované **herní profily** s vlastními nastaveními, mody, shadery, balíčky zdrojů a světy.
- Procházejte a instalujte obsah z **Modrinth a CurseForge**, aniž byste opustili spouštěč:
  - mods
  - modpacky
  - balíčky shaderů
  - balíčky zdrojů
  - dobrodružné mapy a světy
- Vyřešte a nainstalujte závislosti modů tam, kde je zdroj poskytuje.
- Importujte Forge/NeoForge instalační soubory JAR a nainstalujte Fabric/Quilt zavaděče přímo z nástroje pro výběr verze.

### Grafika a výkon

- Přepínání mezi více vykreslovacími moduly z **Nastavení → Vykreslovací modul a zobrazení**:
  - **gl4es** — OpenGL cesta kompatibility 2.1
  - **ANGLE** — OpenGL ES až Metal nebo Vulkan
  - **MobileGlues** — OpenGL 4,0, Minecraft 1,17+, experimentální
  - **Zink** — OpenGL 4.1 až Mesa 25 a MoltenVK
  - **LTW** — OpenGL 3,3 až OpenGL ES/Metal, Minecraft 1,17+, experimentální
  - **TGLMT** — OpenGL 4.6 Core až Metal, A11 Bionic nebo novější
- **TGLMT s podporou Sodium a Iris** pro moderní nastavení založená na shaderu.
- **Generování snímků** s Motion-Adaptive GPU (MADI) a režimy Camera 3D Reproject, včetně časové interpolace a prediktivní extrapolace.
- Škálování rozlišení, maximální snímková frekvence, FSR 1.0 upscaling, GLSL shader cache a ladění podle vykreslovače.
- Výkonnostní HUD s konfigurovatelnými FPS, CPU, GPU, RAM, teplotou, baterií, hodinami a widgety FPS generace snímků.
- Vestavěný záznam výkonu s grafy, PNG/PDF export a sdílení.

### Ovládací prvky

- Plně přizpůsobitelné rozvržení ovládacích prvků na obrazovce, velikosti tlačítek a průhlednost.
- Podpora **klávesnice a myši**, včetně virtuální myši a nastavitelné rychlosti ukazatele.
- Podpora **herního ovladače** s konfigurovatelným rozložením a citlivostí.
- **Gyroskop** zaměřování s nastavitelnou citlivostí a inverzí os.
- Gesta myši, posouvání a aktivní lišty.
- Volitelné chování: klepnutím umístíte bloky, podržením bloky rozbijete.
- Dvojitým poklepáním na hotbar vyměníte drženou položku za hotovou.
- Posuvný hotbar a nastavitelné načasování dlouhého stisknutí.

### Spouštěč a účty

- Podpora účtů **Microsoft**, **místní/offline**, **demo** a **Ely.by**.
- Spravujte běhová prostředí **Java 8, 17, 21 a 25**, stahujte je v aplikaci nebo importujte své vlastní.
- Vyberte verze LWJGL a vylaďte argumenty JVM, proměnné prostředí a alokaci paměti.
- Automatická správa RAM pro zařízení s omezenou pamětí.
- Motivy, zvýrazňující barvy, rozostření, okraje, poloměr rohů, vlastní spouštěcí písma a ikony aplikací.
- **Informace o zařízení F3 ve hře**: čip zařízení, verze iOS, název/verze spouštěče, číslo sestavení a typ sestavení.
- Volitelné integrace **Witch Server**, CurseForge a AI pro pokročilá nastavení.
- **52 jazyků v aplikaci**, včetně jazykových balíčků psaných zprava doleva a zábavných lokalit.

---

<a id="screenshots"></a>
## Snímky obrazovky

Snímky obrazovky z vývojového sestavení Witch Launcher 0.0.4. Rozhraní se může měnit mezi verzemi a tématy.

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
## Požadavky

| Požadavek | Podrobnosti |
|---|---|
| **Zařízení** | iPhone nebo iPad s procesorem arm64 a podporou Metal |
| **Systém** | iOS nebo iPadOS **14.0 nebo novější** |
| **JIT** | Požadovaný. Povolit JIT až StikDebug, SideStore, TrollStore nebo nastavení s jailbreakem |
| **Účet** | Účet Microsoft, který vlastní Minecraft pro oficiální stahování; místní a demo režimy jsou také k dispozici |
| **Úložiště** | Prostor pro launcher, Java runtime, verze her, mody a světy |
| **Síť** | Vyžadováno pro přihlášení, stahování verzí, prohlížeč obsahu a volitelné online služby |

Witch **nezahrnuje** herní soubory Minecraft. Herní soubory se stahují prostřednictvím spouštěče po přihlášení ke způsobilému účtu.

### JIT poznámky

Minecraft: Java Edition potřebuje JIT a Witch bez něj nemůže hru spustit.

- **Instalace ve stylu SideStore / AltStore:** povolte JIT pro Witch a ponechejte aktivní požadované připojení VPN/debugger. Zpráva v aplikaci odkazuje na **LocalDevVPN** a `CS_DEBUGGED`.
- **StikDebug:** připojte StikDebug k Witch a povolte JIT. Dne **iOS 26/27** musí StikDebug zůstat připojen, zatímco hra běží. `UniversalJIT26.js` se v případě potřeby zkopíruje do schránky.
- **TrollStore:** povolte **URL Scheme** v TrollStore, pokud Witch stále čeká na JIT.
- **Zařízení s jailbreakem:** použijte preferovaný aktivátor JIT.
- Pokud spouštěč zůstane na obrazovce **Čekání na JIT**, zkontrolujte před opětovným spuštěním připojení ladicího programu, nastavení VPN a TrollStore URL Scheme.

Chování JIT závisí na verzi iOS a způsobu instalace. Aktualizace systému mohou přerušit stávající nastavení JIT.

---

<a id="installation"></a>
## Instalace

Witch musí být pro vaše zařízení podepsáno. Toto úložiště nezasílá certifikáty ani předem podepsané IPA.

### Použijte sestavení

1. Stáhněte si vývojové sestavení z [pracovního postupu vývoje](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) nebo použijte podepsané sestavení ze zdroje, kterému důvěřujete.
2. Podepište a nainstalujte jej pomocí **SideStore**, **AltStore**, **TrollStore** nebo vaší preferované metody bočního načítání.
3. Před spuštěním hry povolte JIT, jak je popsáno výše.

TrollStore sestavení používají další oprávnění a neměly by být instalovány s normálním signerem s bočním načítáním.

### Sestavte ze zdroje

Kompilace Witch vyžaduje macOS s nástroji příkazového řádku Xcode, iOS SDK 14.0 nebo novější, CMake, JDK 8, `ldid`, `wget`, `zip`.

```bash
git klon --rekurzivní https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Zabalená sestavení se zapisují do `artifacts/`.

Chcete-li místo toho sestavit balíček TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Odkazy na zdrojové kódy rendereru a poznámky k sestavení viz [`note.md`](../../note.md).

---

<a id="languages"></a>
## Jazyky

Witch Launcher se dodává s **52 jazykovými balíčky**. Otevřete **Nastavení → Obecné → Jazyk** a vyberte jazyk, nebo použijte **Automaticky** a postupujte podle jazyka zařízení.

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

Aplikace dodává všech **52 jazykových balíčků**. Překlady README jsou k dispozici pro **všech 52 jazyků**, včetně angličtiny.

Některé překlady jsou strojově podporované a mohou obsahovat nepohodlné technické výrazy. Opravy jsou vítány.

Angličtina je zdrojovým jazykem tohoto README. Lokalizované soubory README jsou dostupné ve selektoru jazyka v horní části této stránky a v adresáři [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Poznámky a omezení

- **JIT je povinné.** Bez funkčního nastavení JIT se Minecraft nespustí.
- **iOS 26/27 JIT je křehký.** StikDebug musí zůstat připojený a budoucí aktualizace operačního systému mohou změnit fungování.
- Vykreslovací moduly označené jako **experimentální** mohou selhat nebo se mohou vykreslit nesprávně. Pokud si nejste jisti, začněte s **Automaticky**.
- **Generování rámců** vyžaduje vykreslovací modul MoltenVK a podporu výpočtu Metal. Může zvýšit spotřebu baterie a teplotu zařízení.
- Některé mody, modpacky, shadery a světy mohou vyžadovat konkrétní Minecraft verzi, zavaděč, renderer nebo další paměť.
- CurseForge modpacky používají `manifest.json`; pokud instalace jedním klepnutím není pro balíček k dispozici, importujte archiv ručně.
- Online funkce závisí na službách třetích stran a mohou být nedostupné.
- Snímky obrazovky jsou z vývojového sestavení a nemusí přesně odpovídat aktuální verzi.

---

<a id="project-lineage"></a>
## Projektová linie

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

### Související projekty

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Přispívání

Zprávy o chybách a PR jsou vítány. Při hlášení problému uveďte:

- model zařízení a verze iOS/iPadOS
- Witch Launcher verze
- renderer a verzi Minecraft
- zavaděč modů a seznam nainstalovaných modů
- kroky k reprodukci
- příslušný protokol nebo zprávu o selhání

Nezavazujte prosím podpisové certifikáty, zřizovací profily, API klíče ani jiná tajemství.

---

<a id="credits"></a>
## Kredity

**Witch Launcher** spravuje **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream a komunita

Witch Launcher a jeho upstream projekty jsou postaveny na práci mnoha přispěvatelů, včetně:

- **@crystall1nedev** — Amethyst projektový manažer a iOS vývojář portů
- **@khanhduytran0** — iOS vývojář portu
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Další poděkování patří **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Project, Khronos Group, Mesa Project, PojavLauncher týmu, Mozille a Minecraft komunitě.

Zvláštní poděkování patří [MCHeads](https://mc-heads.net) za poskytování služeb Minecraft avatarů.

Úplný seznam komponent a licencí třetích stran je k dispozici v [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licence

Witch Launcher je distribuován pod **GNU General Public License v3.0** a podléhá licencím a požadavkům na autorská práva komponent třetích stran uvedených v [`credits.md`](../../credits.md).

Úplný text licence naleznete v [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft je ochranná známka společnosti Mojang Studios. Witch Launcher není přidružen k projektu Mojang Studios, Microsoft nebo Amethyst.</sub>
</p>
