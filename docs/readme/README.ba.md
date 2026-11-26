<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
  <strong>Minecraft: Java баҫмаһы iPhone һәм iPad.</strong><br>
Йәмәғәтселек төҙөгән iOS һәм iPadOS Amethyst санкаһы, ДуйАнх662 (За_д626) тарафынан ҡарала.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Сифаттар](#features) · [Скриншоты](#screenshots) · [Талаптар](#requirements) · [Ҡуйыу](#installation) · [Телдәр](#languages) · [Кредиттар](#credits) · [Лицензия](#license)

<details>
<summary><strong>Телдәр</strong></summary>

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
## Турала

**Witch Launcher** — бойондороҡһоҙ, йәмәғәтселек тарафынан ҡаралған [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) өлөшө, ул **Minecraft: Java Edition**-ды iPhone һәм iPad-ға килтерә. Ул сенсор-беренсе стартер UI менән тулы Java эшләү ваҡыты менеджеры, LWJGL, һәм график стека тирәләй төҙөлгән Metal, MoltenVK, һәм OpenGL тәржемә ҡатламдары берләштерә.

Witch [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) йәмәғәтселеге, Amethyst-iOS һәм Amethyst-iOS-25 эштәре буйынса төҙөлгән. Был бойондороҡһоҙ проект һәм Mojang Studios, Microsoft, йәки өҫкө Amethyst командаһы менән бәйле түгел.

> **Ағымдағы версия:** 0.0.4 · Релиз тураһында иҫкәрмәләр өсөн [`news.md`](../../news.md) ҡарағыҙ.

---

<a id="features"></a>
## Сифаттар

### Minecraft һәм модтар

- Күпселек **Minecraft: Java Edition** версияларын эшләй, тәүге Бета-версияларҙан алып һуңғы снимоктарға тиклем.
- **Ваниль, Fabric, Quilt, Forge, NeoForge һәм OptiFine**те ярҙам итә.
- Үҙ параметрҙары, модтары, шейдерҙар, ресурстар пакеттары һәм донъялары менән айырымланған **уйын профилдәре**н булдырыу.
- **Modrinth һәм CurseForge** йөкмәткеһен ҡарау һәм ҡуйыу, стартерҙан сыҡмайынса:
  - модтар
  - модпактар
  - шейдер пакеттары
  - ресурс пакеттары
  - мажаралы карталар һәм донъялар
- Хәл итеү һәм ҡуйыу мод зависимостей, унда сығанаҡ уларҙы тәьмин итә.
- Импорт Forge/NeoForge ҡуйыусы JARs һәм туранан-тура версия йыйыусы Fabric/Quilt тейәүселәр ҡуйыу.

### Графика һәм башҡарыу

- Бер нисә рендер араһында алмаштырыу **Көйләүҙәр → Рендер һәм дисплей**:
  - **gl4es** — OpenGL 2.1 совместимость юлы
  - **ANGLE** — Metal йәки Vulkan аша OpenGL ES
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, эксперименталь
  - **Zink** — OpenGL 4.1, Mesa 25 һәм MoltenVK аша
  - **LTW** — OpenGL 3.3, OpenGL ES/Metal аша, Minecraft 1.17+, эксперименталь
  - **TGLMT** — OpenGL 4.6 Core, Metal аша, A11 Bionic йәки яңыраҡ
- **TGLMT Sodium һәм Iris ярҙамы менән**заманса шейдерҙарға нигеҙләнгән ҡуйыуҙар өсөн.
- **Кадрҙарҙы генерациялау** хәрәкәткә яраҡлашҡан график процессор (MADI) һәм камера 3D ҡабаттан проектлау режимдары менән, шул иҫәптән ваҡыт интерполяцияһы һәм прогностик экстраполяция.
- Ҡарар масштаблау, максималь кадрҙар тиҙлеге, FSR 1.0 масштаблау, GLSL шейдер кэштар, һәм бер рендер көйләү.
- Һөҙөмтәлелек HUD менән настраиваемый FPS, процессор, GPU, оперативка, температура, батарея, сәғәт, һәм кадр-быуын FPS виджеттар.
- Встроенный етештереүсәнлеге менән яҙма диаграммалар, PNG/PDF экспорт, һәм бүлешергә.

### Контроль

- Тулыһынса настраиваемый экранда идара итеү макеттары, төймә ҙурлыҡтары, һәм үтә күренмәлелек.
- **Клавиатура һәм сысҡан** ярҙамы, шул иҫәптән виртуаль сысҡан һәм көйләнә торған күрһәткес тиҙлеге.
- **Уйын контролеры** конфигурацияланған макеттар һәм һиҙгерлек менән ярҙам итә.
- **Гироскоп** көйләнә торған һиҙгерлек һәм күсәр инверсияһы менән йүнәлтелгән.
- Сысҡан, прокрутка һәм горячая панель ымдары.
- Факультатив тәртип: блоктарҙы урынлаштырыу өсөн тап, блоктарҙы өҙөү өсөн тотоу.
- Ике тапҡыр ҡағыла ҡайнар панелгә алмаштырыу өсөн үткәрелгән әйберҙе офф-ҡул.
- Скользящий горячий панель һәм регулируемый оҙайлы баҫыу ваҡыты.

### Запуск һәм иҫәп яҙмалары

- **Microsoft**, **урындағы/офлайн**, **демо**, һәм **Ely.by** иҫәп яҙмаһын ярҙам итеү.
- Идара итеү **Java 8, 17, 21 һәм 25** эшләү ваҡыты, уларҙы ҡушымта эсендә скачать, йәки үҙ импорт.
- LWJGL версияларын һайлау һәм JVM аргументтарын, мөхит үҙгәртеүселәрен һәм хәтерҙе бүлеүҙе көйләү.
- Авто оперативка менән идара итеү ҡоролмалары өсөн сикләнгән хәтер.
- Темалар, акцент төҫтәре, асыҡланмау, сиктәр, мөйөш радиусы, ҡулланыусы стартер шрифттары, һәм ҡушымта иконкалары.
- Уйын эсендәге **F3 ҡоролма тураһында мәғлүмәт**: ҡоролма микросхемаһы, iOS версияһы, стартер исеме/версияһы, төҙөү номеры һәм төҙөү тибы.
- Һорау буйынса **Witch Сервер**, CurseForge һәм AI интеграциялары өсөн өҫтәмә ҡуйыуҙар.
- **52 ҡушымта эсендәге тел**, шул иҫәптән уңдан һулға тел пакеттары һәм күңелле локаль.

---

<a id="screenshots"></a>
## Скриншоты

Witch Launcher 0.0.4 үҫеш төҙөүҙән скриншоттар. Интерфейс версиялар һәм темалар араһында үҙгәрергә мөмкин.

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
## Талаптар

| Талап | Ентекле мәғлүмәт |
|---|---|
| **Ҡоролма** | iPhone йәки iPad менән arm64 процессор һәм Metal ярҙам |
| **Система** | iOS йәки iPadOS **14.0 йәки яңыраҡ** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Иҫәп яҙмаһы** | Microsoft иҫәп яҙмаһы, тип хужа Minecraft рәсми скачивание өсөн; локаль һәм демо-режимдар ҙа бар |
| **Һаҡлау** | Запуск өсөн урын, Java эшләү ваҡыты, уйын версиялары, модтар, һәм донъялар |
| **Селтәр** | Ҡабул итеү өсөн кәрәк, версия скачивание, йөкмәтке браузеры, һәм өҫтәмә онлайн хеҙмәттәр |

Witch **юҡ** Minecraft уйын файлдарын үҙ эсенә ала. Уйын файлдары скачать аша стартер хоҡуҡлы иҫәп яҙмаһына ингәндән һуң.

### JIT иҫкәрмәләр

Minecraft: Java Edition кәрәк JIT, һәм Witch уйынды унан башҡа башлай алмай.

- **SideStore / AltStore стилендәге ҡуйыуҙар:** Witch өсөн JIT-ты индерә һәм кәрәкле VPN/отладчик тоташыуын әүҙем тота. Ҡушымта эсендәге хәбәр **LocalDevVPN** һәм `CS_DEBUGGED`-ға һылтанма яһай.
- **StikDebug:** StikDebug-ны Witch-ға беркетергә һәм JIT-ны эшләтергә. **iOS 26/27**, StikDebug уйын барғанда беркетелгән ҡалырға тейеш. `UniversalJIT26.js` кәрәк саҡта буферға күсерелә.
- **TrollStore:** **URL Scheme**-ты TrollStore-да асыу, әгәр Witch JIT-ды көтөп торһа.
- **Джейлбрейк ҡоролмалары:** үҙегеҙгә оҡшаған JIT ярҙамсыһын ҡулланығыҙ.
- Әгәр ҙә стартер **JIT** экранында ҡала икән, ҡабаттан старт алдынан отладчик тоташыуын, VPN һәм TrollStore URL Scheme параметрҙарын тикшерегеҙ.

JIT тәртибе iOS версияһына һәм ҡуйыу ысулына бәйле. Система яңыртыуҙары ғәмәлдәге JIT ҡоролмаларын боҙа ала.

---

<a id="installation"></a>
## Ҡуйыу

Witch һеҙҙең ҡоролма өсөн ҡул ҡуйырға тейеш. Был һаҡлағыс сертификаттар йәки алдан ҡул ҡуйылған IPA-ларҙы ебәрмәй.

### Төҙөү ҡулланыу

1. Скачать үҫеш төҙөү [үҫеш эш ағымы](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), йәки ҡулланыу ҡул ҡуйылған төҙөү сығанаҡтан һеҙ ышанаһығыҙ.
2. Ҡул ҡуйығыҙ һәм уны **SideStore**, **AltStore**, **TrollStore**, йәки үҙегеҙгә оҡшаған ян йөкләү ысулы менән ҡуйығыҙ.
3. JIT өҫтә һүрәтләнгәнсә, уйынды башлағансы индереү.

TrollStore төҙөй өҫтәмә хоҡуҡтар ҡулланыу һәм ғәҙәти sideloading ҡул ҡуйыусы менән ҡуйырға тейеш түгел.

### Сығанаҡтан төҙөү

Witch-ты төҙөү өсөн macOS-ты Xcode команда юлдары ҡоралдары, iOS SDK 14.0 йәки яңыраҡ, CMake, JDK 8, `ldid`, `wget`, `zip` һәм Git кәрәк.

```bash
git клоны --рекурсив https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Ҡапланған төҙөүҙәр `artifacts/` яҙылған.

TrollStore пакет төҙөү өсөн урынына:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Рендер сығанаҡтары һылтанмалары һәм төҙөү иҫкәрмәләре өсөн ҡарағыҙ [`note.md`](../../note.md).

---

<a id="languages"></a>
## Телдәр

Witch Launcher **52 тел пакеты** менән ебәрелә. **Параметрҙар → Дөйөм → Тел** асып, тел һайлағыҙ, йәки ҡоролма телен үтәү өсөн **Авто** ҡулланығыҙ.

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

Ҡушымта бөтә **52 тел пакетын** ебәрә. README тәржемәләре **бөтә 52 тел** өсөн, шул иҫәптән инглиз теле өсөн дә бар.

Ҡайһы бер тәржемәләр машина ярҙамында эшләнә һәм уларҙа уңайһыҙ техник терминдар булыуы мөмкин. Төҙәтеүҙәр ҡабул ителә.

Инглиз теле был README өсөн сығанаҡ теле булып тора. Локалләштерелгән README-ларҙы был биттең өҫкө өлөшөндәге тел һайлаусыһынан һәм [`docs/readme/`](./) каталогында табырға мөмкин.

---

<a id="notes-and-limitations"></a>
## Иҫкәрмәләр һәм сикләүҙәр

- **JIT мотлаҡ.** Эшләгән JIT ҡуйыуһыҙ, Minecraft эшләй башламаясаҡ.
- **iOS 26/27 JIT һынғыһыҙ.** StikDebug беркетелгән булып ҡалырға тейеш, һәм киләсәктә ОС яңыртыуҙары нимә эшләгәнен үҙгәртергә мөмкин.
- **эксперименталь** тип билдәләнгән күрһәтеүселәр аварияға осрауы йәки дөрөҫ күрһәтелмәүе мөмкин. Ышанмаһағыҙ, **Авто** менән башлағыҙ.
- **Кадрҙарҙы генерациялау** өсөн MoltenVK рендер һәм Metal иҫәпләү ярҙамы кәрәк. Ул батарея ҡулланыуҙы һәм ҡоролма температураһын арттырырға мөмкин.
- Ҡайһы бер модтар, modpacks, шейдерҙар һәм донъялар аныҡ Minecraft версияһы, тейәүсе, рендерер йәки өҫтәмә хәтер талап итеүе мөмкин.
- CurseForge модпактар ​​ҡулланыу `manifest.json`; әгәр бер кран менән ҡуйыу пакет өсөн мөмкин булмаһа, архивты ҡул менән импортлағыҙ.
- Онлайн функциялар өсөнсө яҡ хеҙмәттәренә бәйле һәм уларҙы ҡулланыу мөмкинлеге булмауы ихтимал.
- Скриншоттар үҫеш төҙөүҙән һәм ағымдағы релизға тап килмәүе мөмкин.

---

<a id="project-lineage"></a>
## Проект нәҫеле

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

### Бәйләнешле проекттар

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Өлөш индереү

Хаталар тураһында отчеттар һәм пиар ҡабул ителә. Проблема тураһында хәбәр иткәндә, түбәндәгеләрҙе индерегеҙ:

- Ҡоролма моделе һәм iOS/iPadOS версияһы
- Witch Launcher версияһы
- рендер һәм Minecraft версияһы
- мод тейәгесе һәм ҡуйылған модтар исемлеге
- үрсетеү өсөн аҙымдар
- тейешле журнал йәки авария тураһында хәбәр

Зинһар, ҡул ҡуйыу сертификаттары, тәьмин итеү профилдәре, API асҡыстар, йәки башҡа серҙәр ҡылған түгел.

---

<a id="credits"></a>
## Кредиттар

**Witch Launcher** **ДуйАнх662 (За_д626)** тарафынан хеҙмәтләндерелә.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Үрге ағым һәм йәмәғәтселек

Witch Launcher һәм уның өҫкө проекттары күп өлөш индереүселәр эше нигеҙендә төҙөлгән, шул иҫәптән:

- **@crystall1nedev** — Amethyst проект менеджеры һәм iOS порт эшләүсе
- **@khanhduytran0** — iOS порт әҙерләүсе
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Өҫтәмә рәхмәт **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE проекты, Хронос төркөмө, Mesa проекты, PojavLauncher командаһы, Mozilla һәм Minecraft берләшмәһенә.

Айырым рәхмәт [MCHeads](https://mc-heads.net) Minecraft аватар хеҙмәттәрен күрһәтеү өсөн.

Тулы өсөнсө яҡ компоненты һәм лицензия исемлеге бар [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Лицензия

Witch Launcher **GNU дөйөм йәмәғәт лицензияһы v3.0** буйынса таратыла, [`credits.md`](../../credits.md) исемлегендә күрһәтелгән өсөнсө яҡ компоненттарының лицензиялары һәм авторлыҡ хоҡуҡтары талаптарына ярашлы.

Ҡарағыҙ [`LICENSE`](../../LICENSE) өсөн тулы лицензия тексы.

---

<p align="center">
<sub>Minecraft сауҙа маркаһы булып тора Mojang Studios. Witch Launcher менән бәйле түгел Mojang Studios, Microsoft, йәки Amethyst проекты.</sub>
</p>
