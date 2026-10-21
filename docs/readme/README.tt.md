<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone һәм iPad.</strong><br>
  DuyAnh662 (Za_d626) белән сакланган Amethyst-ның җәмгыятьтә төзелгән iOS һәм iPadOS форкы.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Үзенчәлекләр](#features) · [Скриншотлар](#screenshots) · [Таләпләр](#requirements) · [Урнаштыру](#installation) · [Телләр](#languages) · [Кредитлар](#credits) · [Лицензия](#license)

<details>
<summary><strong>Телләр</strong></summary>

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
## Турында

**Witch Launcher** - мөстәкыйль, җәмгыять тарафыннан сакланган тармагы [Amethyst] (https://github.com/AngelAuraMC/Amethyst-iOS), ул **Minecraft: Java Edition** iPhone һәм iPad китерә. Ул сенсор-беренче эшләтеп җибәрүче UI белән тулы Java эш вакыты менеджеры, LWJGL, һәм Metal, MoltenVK, һәм OpenGL тәрҗемә катламнары тирәсендә төзелгән график стекны берләштерә.

Witch [Boardwalk] (https://github.com/zhuowei/Boardwalk), [PojavLauncher] (https://github.com/PojavLauncherTeam) җәмгыяте, Amethyst-iOS, һәм Amethyst-iOS-25 эшенә корылган. Бу мөстәкыйль проект һәм Mojang Studios, Microsoft, яки агымдагы Amethyst командасы белән бәйләнешле түгел.

> **Хәзерге версия:** 0.0.4 · Карагыз [`news.md`] (news.md).

---

<a id="features"></a>
## Featuresзенчәлекләр

### Minecraft һәм режим

- Күпчелек **Minecraft: Java Edition** версияләрен эшли, Бета иртә чыгарылышыннан соңгы снэпшотлар аша.
- **Ванила, Fabric, Quilt, Forge, NeoForge, һәм OptiFine** ярдәм итә.
- Settingз көйләүләре, режимнары, шейдерлары, ресурс пакетлары, дөньялары белән изоляцияләнгән **уен профиле** булдырыгыз.
- Эчтәлекне калдырмыйча, **Modrinth һәм CurseForge** дан эчтәлекне карагыз һәм урнаштырыгыз:
  - режим
  - модпаклар
  - шейдер пакетлары
  - ресурс пакетлары
  - маҗаралы карталар һәм дөньялар
- Чыганак тәэмин иткән мод бәйләнешләрен чишегез һәм урнаштырыгыз.
- Forge / NeoForge урнаштыручы JAR-ны импортлагыз һәм версия сайлаучыдан Fabric / Quilt йөкләүчеләрне урнаштырыгыз.

### Графика һәм башкару

- **көйләүләр → Рендерер һәм дисплей** дан берничә рендерер арасында күчү:
  - **gl4es** - OpenGL 2.1 туры килү юлы
  - **ANGLE** - OpenGL ES Metal яки Vulkan аша
  - **MobileGlues** - OpenGL 4.0, Minecraft 1.17+, эксперименталь
  - **Zink** - OpenGL 4.1 Mesa 25 һәм MoltenVK
  - **LTW** - OpenGL 3.3 OpenGL ES / Metal, Minecraft 1.17+, эксперименталь
  - **TGLMT** - OpenGL 4.6 үзәк Metal, A11 Bionic яки яңарак
- Заманча шейдерга нигезләнгән көйләүләр өчен **TGLMT Sodium һәм Iris ярдәме белән**.
- **Кадрлар ясау** хәрәкәт-адаптив GPU (MADI) һәм камера 3D репроект режимнары белән, шул исәптән вакытлы интерполяция һәм прогнозлы экстролапация.
- Резолюция масштабы, максималь рамка, FSR 1.0 күтәрү, GLSL шейдер кэшлары, һәм бер рендерер көйләү.
- Конфигурацияләнә торган FPS, үзәк эшкәрткеч җайланма, GPU, RAM, температура, батарея, сәгать, һәм FPS виджетлары белән HUD башкару.
- Диаграммалар, PNG/PDF экспорт һәм бүлешү белән урнаштырылган башкару.

### Контроль

- Экранда контроль макетлары, төймә зурлыклары, ачыклыгы тулысынча көйләнә.
- **Клавиатура һәм тычкан** виртуаль тычкан һәм көйләнә торган күрсәткеч тизлеген кертеп.
- **Уен контроллеры** конфигурацияләнгән макетлар һәм сизгерлек белән ярдәм.
- **Гироскоп** көйләнә торган сизгерлек һәм күчәр инверсиясе белән.
- Тычкан, әйләндерү һәм кайнар ишарәләр.
- Ихтимал тәртип: блоклар урнаштыру өчен басыгыз, блокларны сындыру өчен тотыгыз.
- Тотылган әйберне кулдан алыштыру өчен кайнар линиягә ике тапкыр басыгыз.
- Слайдлы кайнар плитә һәм көйләнә торган озын басу вакыты.

### Эшләткеч һәм счетлар

- **Microsoft**, **җирле / оффлайн**, **демо**, һәм **Ely.by** хисап ярдәме.
- **Java 8, 17, 21, һәм 25** эш вакыты белән идарә итегез, аларны кушымтада йөкләгез, яки үзегезнекен импортлагыз.
- LWJGL версияләрен сайлагыз һәм JVM аргументларын, әйләнә-тирә үзгәрүчәннәрне, хәтер бүлүне көйләгез.
- Хәтере чикләнгән җайланмалар өчен автоматик RAM белән идарә итү.
- Темалар, акцент төсләре, төссезлек, чикләр, почмак радиусы, махсус шрифтлар, кушымта иконалары.
- Уен эчендә **F3 җайланма турында мәгълүмат**: җайланма чипы, iOS версиясе, эшләтеп җибәрүче исеме / версиясе, номер төзү, төзү төре.
- Алга киткән көйләүләр өчен өстәмә **Witch Сервер**, CurseForge, һәм AI интеграцияләр.
- **52 кушымта телләре**, шул исәптән уңнан-сул тел пакетлары һәм кызыклы җирлекләр.

---

<a id="screenshots"></a>
## Скриншотлар

Witch Launcher 0.0.4 үсеш корпусыннан скриншотлар. Интерфейс версияләр һәм темалар арасында үзгәрергә мөмкин.

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
## Таләпләр

| Таләп | Детальләр |
|---|---|
| **җайланма** | arm64 процессоры һәм Metal ярдәме белән iPhone яки iPad |
| **Система** | iOS яки iPadOS **14.0 яки яңарак** |
| **JIT** | Кирәк. JIT StikDebug, SideStore, TrollStore аша, яисә төрмәдән өзелгән көйләү |
| **Хисап** | Рәсми йөкләүләр өчен Minecraft булган Microsoft счеты; җирле һәм демо режимнары да бар |
| **Саклау** | Эшләткеч өчен урын, Java эш вакыты, уен версияләре, режимнар, дөньялар |
| **челтәр** | Керү, версияне йөкләү, эчтәлек браузеры, һәм өстәмә онлайн хезмәтләр өчен кирәк |

Witch **түгел** Minecraft уен файлларын кертә. Уен файллары яраклы счетка кергәннән соң эшләтеп җибәрүче аша йөкләнә.

### JIT язмалар

Minecraft: Java Edition JIT кирәк, һәм Witch уенсыз ансыз җибәрә алмый.

- **SideStore / AltStore-стиль урнаштыру:** Witch өчен JIT эшләгез һәм кирәкле VPN / төзәтүче тоташуны актив саклагыз. Кушымтадагы хәбәр **LocalDevVPN** һәм `CS_DEBUGGED` турында бара.
- **StikDebug:** StikDebugны Witch белән бәйләгез һәм JIT эшләгез. **iOS 26/27** та, StikDebug уен барган вакытта бәйләнергә тиеш. `UniversalJIT26.js` кирәк вакытта буферга күчерелә.
- **TrollStore:** TrollStore **URL Scheme** Witch JIT көтүен дәвам итсә.
- **ailимерелгән җайланмалар:** өстенлекле JIT рөхсәтен кулланыгыз.
- Әгәр эшләтеп җибәрүче **JIT** экранында торса, яңадан эшләтеп җибәргәнче төзәтүче тоташуны, VPN һәм TrollStore URL Scheme көйләүләрен тикшерегез.

JIT тәртибе iOS версиясенә һәм урнаштыру ысулына бәйле. Система яңартулары булган JIT көйләүләрен бозырга мөмкин.

---

<a id="installation"></a>
## Урнаштыру

Witch сезнең җайланма өчен имзаланырга тиеш. Бу склад сертификатлар яки алдан имзаланган IPA җибәрми.

### Төзелеш кулланыгыз

1. [Developmentсеш эш процессыннан] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) үсеш төзелешен йөкләгез, яки сез ышанган чыганактан имзаланган төзелешне кулланыгыз.
2. Аны **SideStore**, **AltStore**, **TrollStore** яки өстенлекле йөкләү ысулы белән урнаштырыгыз.
3. Уенны башлар алдыннан югарыда әйтелгәнчә JIT рөхсәт итегез.

TrollStore төзи өстәмә хокуклар куллана һәм гадәти юл куючы белән урнаштырылырга тиеш түгел.

### Чыганактан төзегез

Witch туплау macOS Xcode командование кораллары, iOS SDK 14.0 яки яңарак, CMake, JDK 8, `ldid`, `wget`, `zip`, һәм Гит таләп итә.

```bash
гит клон - рекурсив https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Пакетланган корылмалар `artifacts/` язылган.

Аның урынына TrollStore пакет төзү өчен:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Рендерер чыганак сылтамалары һәм искәрмәләр төзү өчен [`note.md`] карагыз (note.md).

---

<a id="languages"></a>
## Телләр

Witch Launcher **52 тел пакеты** белән җибәрелә. **көйләүләр → Гомуми → Тел** ачыгыз һәм тел сайлагыз, яки җайланма теленә иярү өчен **Авто** кулланыгыз.

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

Кушымта барлык **52 тел пакеты** җибәрә. README тәрҗемәләре **барлык 52 телдә**, шул исәптән инглиз телендә дә бар.

Кайбер тәрҗемәләр машина ярдәмендә һәм уңайсыз техник терминнарны үз эченә ала. Төзәтмәләр кабул ителә.

Инглиз теле - бу README өчен чыганак теле. Локальләштерелгән READMEлар бу битнең өстендә һәм [`docs/readme/`] (docs/readme/) каталогында тел селекторыннан бар.

---

<a id="notes-and-limitations"></a>
## Искәрмәләр һәм чикләүләр

- **JIT мәҗбүри.** Эшче JIT булмаса, Minecraft эшләмәячәк.
- **iOS 26/27 JIT ватык.** StikDebug кушылырга тиеш, һәм киләчәктә ОС яңартулары эшне үзгәртә ала.
- **эксперименталь** дип билгеләнгән рендерерлар ватылырга яки дөрес күрсәтелмәскә мөмкин. Ышанмасагыз, **Авто** белән башлап җибәрегез.
- **Рам ясау** MoltenVK рендерер һәм Metal исәпләү ярдәме таләп итә. Бу батарея куллануны һәм җайланма температурасын арттырырга мөмкин.
- Кайбер режимнар, модпаклар, шейдерлар һәм дөньялар билгеле Minecraft версиясен, йөкләүче, рендерер яки өстәмә хәтер таләп итә ала.
- CurseForge модпаклар `manifest.json` куллана; пакет өчен бер таптап урнаштыру мөмкин булмаса, архивны кул белән импортлагыз.
- Онлайн функцияләр өченче як хезмәтләренә бәйле һәм мөмкин түгел.
- Скриншотлар үсеш корпусыннан һәм хәзерге чыгарылышка туры килмәскә мөмкин.

---

<a id="project-lineage"></a>
## Проект нәселе

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

### Бәйләнешле проектлар

- [Amethyst Android] (https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS] (https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25] (https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk] (https://github.com/zhuowei/Boardwalk)
- [PojavLauncher] (https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Идарә итү

Хата отчетлары һәм PR-лар рәхим итегез. Проблема турында хәбәр иткәндә:

- җайланма моделе һәм iOS / iPadOS версиясе
- Witch Launcher версия
- рендерер һәм Minecraft версиясе
- mod loader һәм урнаштырылган режимнар исемлеге
- үрчү өчен адымнар
- тиешле бүрәнә яки авария турында отчет

Зинһар, кул кую сертификатлары, профильләр, API ачкычлары яки бүтән серләр бирмәгез.

---

<a id="credits"></a>
## Кредитлар

**Witch Launcher** **DuyAnh662 (Za_d626)** белән саклана.

- [TikTok] (https://tiktok.com/@za_d626)
- [YouTube] (https://youtube.com/@za_d626)
- [X] (https://x.com/duyanh662)

### Агым һәм җәмгыять

Witch Launcher һәм аның агымдагы проектлары күп катнашучылар эшенә корылган, шул исәптән:

- **@crystall1nedev** - Amethyst проект менеджеры һәм iOS порт ясаучы
- **@khanhduytran0** - iOS порт ясаучы
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Өстәмә рәхмәт **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Проект, Хронос Группасы, Mesa Проект, PojavLauncher Команда, Мозилла, һәм Minecraft җәмгыяте.

[MCHeads] (https://mc-heads.net) Minecraft аватар хезмәтләрен күрсәткән өчен зур рәхмәт.

Өченче як компоненты һәм лицензия исемлеге [`credits.md`] (credits.md) бар.

---

<a id="license"></a>
## Лицензия

Witch Launcher [`credits.md`] (credits.md) исемлегендә күрсәтелгән өченче як компонентларының лицензияләре һәм авторлык таләпләре нигезендә **GNU General Public License v3.0** нигезендә таратыла.

Лицензия тексты өчен [`LICENSE`] (LICENSE) карагыз.

---

<p align="center">
  <sub>Minecraft - Mojang Studios сәүдә маркасы. Witch Launcher Mojang Studios, Microsoft, яки Amethyst проект белән бәйләнешле түгел.</sub>
</p>
