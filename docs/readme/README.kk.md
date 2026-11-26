<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone және iPad.</strong><br>.
DuyAnh662 (Za_d626) басқаратын Amethyst iOS және iPadOS қауымдастық құрастырған.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Мүмкіндіктер](#features) · [Скриншоттар](#screenshots) · [Талаптар](#requirements) · [Орнату](#installation) · [Тілдер](#languages) · [Несиелер](#credits) · [Лицензия](#license)

<details>
<summary><strong>Тілдер</strong></summary>

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
## туралы

**Witch Launcher** тәуелсіз, қауымдастық қолдайтын [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) айырмасы, **Minecraft: Java Edition** тармақтарын iPhone және iPad-ге әкеледі. Ол бірінші сенсорлық іске қосу интерфейсін толық Java орындау уақытының басқарушысымен, LWJGL және Metal, MoltenVK және OpenGL аударма қабаттары айналасында құрастырылған графикалық стекпен біріктіреді.

Witch [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) қауымдастығы, Amethyst-iOS және Amethyst-iOS-25 жұмысына негізделген. Бұл тәуелсіз жоба және Mojang Studios, Microsoft немесе жоғарғы Amethyst командасымен байланысты емес.

> **Ағымдағы нұсқасы:** 0.0.4 · Шығарылым жазбалары үшін [`news.md`](../../news.md) бөлімін қараңыз.

---

<a id="features"></a>
## Ерекшеліктер

### Minecraft және модификациялар

- Көптеген **Minecraft: Java Edition** нұсқаларын, ерте бета шығарылымдарынан бастап соңғы суреттерге дейін іске қосады.
- **Ваниль, Fabric, Quilt, Forge, NeoForge және OptiFine** қолдайды.
- Жеке параметрлері, модтары, шейдерлері, ресурс бумалары және әлемдері бар оқшауланған **ойын профильдерін** жасаңыз.
- Іске қосу құрылғысынан шықпастан **Modrinth және CurseForge** мазмұнын шолыңыз және орнатыңыз:
  - мод
  - модпакеттер
  - шейдер пакеттері
  - ресурстар пакеттері
  - шытырман оқиғалы карталар мен әлемдер
- Мод тәуелділіктерін көз беретін жерде шешіп, орнатыңыз.
- Forge/NeoForge орнатушы JAR файлдарын импорттаңыз және Fabric/Quilt жүктегіштерін нұсқа таңдау құралынан тікелей орнатыңыз.

### Графика және өнімділік

- **Параметрлер → Рендерер және дисплей** ішінен бірнеше рендерерлер арасында ауысыңыз:
  - **gl4es** — OpenGL 2.1 үйлесімділік жолы
  - **ANGLE** — OpenGL ES және Metal немесе Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, эксперименталды
  - **Zink** — OpenGL 4.1 - Mesa 25 және MoltenVK
  - **LTW** — OpenGL 3.3 және OpenGL ES/Metal, Minecraft 1.17+, эксперименталды
  - **TGLMT** — OpenGL 4.6 Негізгі және Metal, A11 Bionic немесе жаңарақ
- **TGLMT Sodium және Iris қолдауы бар** заманауи шейдер негізіндегі орнатулар үшін.
- Уақытша интерполяцияны және болжамды экстраполяцияны қоса, қозғалысқа бейімделетін GPU (MADI) және Камераны 3D қайта жобалау режимдері бар **кадр құру**.
- Ажыратымдылықты масштабтау, максималды кадр жиілігі, FSR 1.0 масштабтау, GLSL шейдер кэштері және әр рендерерге баптау.
- Конфигурацияланатын FPS, CPU, GPU, RAM, температура, батарея, сағат және кадрлық генерациялау FPS виджеттері бар өнімділік HUD.
- Диаграммалар, PNG/PDF экспорттау және ортақ пайдалану арқылы кірістірілген өнімділік жазбасы.

### Басқару элементтері

- Толығымен реттелетін экрандағы басқару схемалары, түйме өлшемдері және мөлдірлік.
- **Пернетақта мен тінтуір** қолдауы, соның ішінде виртуалды тінтуір және реттелетін меңзер жылдамдығы.
- Конфигурацияланатын орналасулары мен сезімталдығы бар **ойын контроллері** қолдауы.
- **Гироскоп** реттелетін сезімталдығы және осьтің инверсиясы бар.
- Тінтуір, айналдыру және ыстық жолақ қимылдары.
- Қосымша әрекет: блоктарды орналастыру үшін түртіңіз, блоктарды бұзу үшін басып тұрыңыз.
- Ұстап тұрған элементті қолмен ауыстыру үшін ыстық жолақты екі рет түртіңіз.
- Жылжымалы ыстық тақта және реттелетін ұзақ басу уақыты.

### Іске қосу құралы және тіркелгілер

- **Microsoft**, **жергілікті/офлайн**, **демо** және **Ely.by** тіркелгіні қолдау.
- **Java 8, 17, 21 және 25** орындалу уақыттарын басқарыңыз, оларды қолданбадан жүктеп алыңыз немесе өзіңізді импорттаңыз.
- LWJGL нұсқаларын таңдап, JVM аргументтерін, ортаның айнымалы мәндерін және жадты бөлуді реттеңіз.
- Жады шектеулі құрылғылар үшін жедел жадты автоматты басқару.
- Тақырыптар, екпін түстері, бұлыңғырлық, жиектер, бұрыш радиусы, реттелетін қосқыш қаріптері және қолданба белгішелері.
- Ойын ішіндегі **F3 құрылғы ақпараты**: құрылғы чипі, iOS нұсқасы, іске қосу құралының аты/нұсқасы, құрастыру нөмірі және құрастыру түрі.
- Қосымша орнатулар үшін **Witch Сервер**, CurseForge және AI интеграциялары.
- **52 қолданбадағы тіл**, соның ішінде оңнан солға тілдер пакеттері мен қызықты тілдер.

---

<a id="screenshots"></a>
## Скриншоттар

Witch Launcher 0.0.4 әзірлеу құрылымынан скриншоттар. Интерфейс нұсқалар мен тақырыптар арасында өзгеруі мүмкін.

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

| Талап | Мәліметтер |
|---|---|
| **Құрылғы** | arm64 процессоры және Metal қолдауы бар iPhone немесе iPad |
| **Жүйе** | iOS немесе iPadOS **14.0 немесе одан жаңа** |
| **JIT** | Міндетті. JIT StikDebug, SideStore, TrollStore немесе джейлбрейктік орнату арқылы қосу |
| **Тіркелгі** | Ресми жүктеп алулар үшін Minecraft иесі бар Microsoft тіркелгісі; жергілікті және демо режимдері де қол жетімді |
| **Сақтау** | Іске қосу құралына арналған кеңістік, Java жұмыс уақыты, ойын нұсқалары, модтар және әлемдер |
| **Желі** | Жүйеге кіру, нұсқаны жүктеп алу, мазмұн шолғышы және қосымша онлайн қызметтер |

Witch Minecraft ойын файлдарын **камтымайды**. Ойын файлдары жарамды есептік жазбаға кіргеннен кейін іске қосу құралы арқылы жүктеледі.

### JIT ескертпелер

Minecraft: Java Edition JIT қажет, ал Witch онсыз ойынды іске қоса алмайды.

- **SideStore / AltStore стиліндегі орнатулар:** Witch үшін JIT мүмкіндігін қосыңыз және қажетті VPN/отладчик қосылымын белсенді күйде ұстаңыз. Қолданбадағы хабар **LocalDevVPN** және `CS_DEBUGGED`-ге сілтеме жасайды.
- **StikDebug:** StikDebug-ті Witch-ға тіркеңіз және JIT қосыңыз. **iOS 26/27** бойынша, StikDebug ойын жүріп жатқанда қосылып тұруы керек. `UniversalJIT26.js` қажет болғанда алмасу буферіне көшіріледі.
- **TrollStore:** TrollStore ішінде **URL Scheme** қосыңыз, егер Witch JIT күте берсе.
- **Jailbroken құрылғылар:** таңдаулы JIT қосу құралын пайдаланыңыз.
- Іске қосу құралы **JIT күтілуде** экранында қалса, қайта іске қоспас бұрын отладчик қосылымын, VPN және TrollStore URL Scheme параметрін тексеріңіз.

JIT тәртібі iOS нұсқасы мен орнату әдісіне байланысты. Жүйе жаңартулары бар JIT параметрлерін бұзуы мүмкін.

---

<a id="installation"></a>
## Орнату

Witch құрылғыңызға қол қою керек. Бұл репозиторий сертификаттарды немесе алдын ала қол қойылған IPA-ны жібермейді.

### Құрылымды пайдаланыңыз

1. [әзірлеу жұмыс процесі](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) ішінен әзірлеу құрылымын жүктеп алыңыз немесе сенімді көзден қол қойылған құрастыруды пайдаланыңыз.
2. Оған **SideStore**, **AltStore**, **TrollStore** немесе өзіңіз қалаған бүйірлік жүктеу әдісі арқылы қол қойып, орнатыңыз.
3. Ойынды бастамас бұрын жоғарыда сипатталғандай JIT қосыңыз.

TrollStore құрастырулары қосымша құқықтарды пайдаланады және қалыпты бүйірлік жүктеу қолтаңбасымен орнатылмауы керек.

### Дереккөзден құрастыру

Witch құрастыру үшін Xcode пәрмен жолы құралдарымен macOS, iOS SDK 14.0 немесе одан жаңа, CMake, JDK 8, `ldid`, `wget`, `zip` және Git қажет.

```bash
git clone --рекурсивті https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Пакеттелген конструкциялар `artifacts/`-ге жазылған.

Оның орнына TrollStore бумасын құру үшін:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Рендерердің бастапқы сілтемелері және құрастыру жазбалары үшін [`note.md`](../../note.md) бөлімін қараңыз.

---

<a id="languages"></a>
## Тілдер

Witch Launcher **52 тіл бумасы**мен жеткізіледі. **Параметрлер → Жалпы → Тіл** тармағын ашып, тілді таңдаңыз немесе құрылғы тілін орындау үшін **Авто** түймесін пайдаланыңыз.

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

Қолданба барлық **52 тіл бумаларын** жеткізеді. README аудармалары **барлық 52 тілге**, соның ішінде ағылшын тіліне де қолжетімді.

Кейбір аудармалар машина көмегімен жасалған және ыңғайсыз техникалық терминдерді қамтуы мүмкін. Түзетулер қабылданады.

Ағылшын тілі осы README үшін бастапқы тіл болып табылады. Локализацияланған README файлдары осы беттің жоғарғы жағындағы тіл селекторында және [`docs/readme/`](./) каталогында қолжетімді.

---

<a id="notes-and-limitations"></a>
## Ескертулер мен шектеулер

- **JIT міндетті болып табылады.** Жұмыс істейтін JIT орнатусыз Minecraft іске қосылмайды.
- **iOS 26/27 JIT сынғыш.** StikDebug тіркелген күйінде қалуы керек және болашақ ОЖ жаңартулары жұмыс істейтін нәрсені өзгертуі мүмкін.
- **Эксперименталды** деп белгіленген рендерерлер бұзылуы немесе қате көрсетуі мүмкін. Егер сенімді болмасаңыз, **Авто** арқылы бастаңыз.
- **Жақтауды құру** үшін MoltenVK рендерері және Metal есептеу қолдауы қажет. Ол батареяны пайдалануды және құрылғы температурасын арттыруы мүмкін.
- Кейбір модтар, модпакеттер, шейдерлер және әлемдер арнайы Minecraft нұсқасын, жүктеуші, рендерер немесе қосымша жадты қажет етуі мүмкін.
- CurseForge модпакеттер `manifest.json` пайдаланады; егер бір рет түрту арқылы орнату бума үшін қолжетімді болмаса, мұрағатты қолмен импорттаңыз.
- Онлайн мүмкіндіктер үшінші тарап қызметтеріне байланысты және қолжетімсіз болуы мүмкін.
- Скриншоттар әзірлеу құрастырудан алынған және ағымдағы шығарылымға дәл сәйкес келмеуі мүмкін.

---

<a id="project-lineage"></a>
## Жоба тегі

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

### Қатысты жобалар

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Үлес қосу

Қате туралы есептер мен PR хабарлары қабылданады. Мәселе туралы хабарлау кезінде мыналарды қосыңыз:

- құрылғы үлгісі және iOS/iPadOS нұсқасы
- Witch Launcher нұсқасы
- көрсетуші және Minecraft нұсқасы
- мод жүктеушісі және орнатылған модтердің тізімі
- көбейту қадамдары
- сәйкес журнал немесе қате туралы есеп

Қол қою сертификаттарын, провизияларды, API кілттерін немесе басқа құпияларды бермеңіз.

---

<a id="credits"></a>
## Несиелер

**Witch Launcher** **DuyAnh662 (Za_d626)** арқылы жүргізіледі.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Жоғары ағын және қауымдастық

Witch Launcher және оның жоғарыдағы жобалары көптеген салымшылардың жұмысына негізделген, соның ішінде:

- **@crystall1nedev** — Amethyst жоба менеджері және iOS порт әзірлеушісі
- **@khanhduytran0** — iOS порт әзірлеушісі
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE жобасы, Khronos тобы, Mesa жобасы, PojavLauncher командасы, Mozilla және Minecraft қауымдастығына қосымша алғыс айтамыз.

[MCHeads](https://mc-heads.net) Minecraft аватар қызметтерін ұсынғаны үшін ерекше алғыс айтамыз.

Толық үшінші тарап құрамдас бөлігі мен лицензия тізімі [`credits.md`](../../credits.md) ішінде қолжетімді.

---

<a id="license"></a>
## Лицензия

Witch Launcher **GNU General Public License v3.0** бойынша таратылады, [`credits.md`](../../credits.md) бөлімінде тізімделген үшінші тарап құрамдастарының лицензиялары мен авторлық құқық талаптарына сәйкес.

Толық лицензия мәтінін [`LICENSE`](../../LICENSE) қараңыз.

---

<p align="center">
<sub>Minecraft - Mojang Studios сауда белгісі. Witch Launcher Mojang Studios, Microsoft немесе Amethyst жобасына қатысты емес.</sub>
</p>
