<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition на iPhone и iPad.</strong><br>
Рачва iOS и iPadOS од Amethyst направљена у заједници, коју одржава ДуиАнх662 (За_д626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Карактеристике](#features) · [Снимци екрана](#screenshots) · [Захтеви](#requirements) · [Инсталација](#installation) · [Језици](#languages) · [Кредити](#credits) · [Лиценца](#license)

<details>
<summary><strong>Језици</strong></summary>

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
## Абоут

**Witch Launcher** је независна вилица [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) коју одржава заједница која доводи **Minecraft: Java Edition** у iPhone и iPad. Комбинује кориснички интерфејс покретача са додиром са пуним Java рунтиме менаџером, LWJGL, и графичким стеком изграђеним око Metal, MoltenVK и OpenGL слојева превођења.

Witch је изграђен на раду [Boardwalk](https://github.com/zhuowei/Boardwalk), заједнице [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS и Amethyst-iOS-25. То је независан пројекат и није повезан са Mojang Studios, Microsoft или претходним Amethyst тимом.

> **Тренутна верзија:** 0.0.4 · Погледајте [`news.md`](../../news.md) за белешке о издању.

---

<a id="features"></a>
## Карактеристике

### Minecraft и мод

- Покреће већину верзија **Minecraft: Java Edition**, од раних Бета издања до најновијих снимака.
- Подржава **Ванилу, Fabric, Quilt, Forge, NeoForge и OptiFine**.
- Креирајте изоловане **профиле игара** са сопственим подешавањима, модовима, схадерима, пакетима ресурса и световима.
- Прегледајте и инсталирајте садржај из **Modrinth и CurseForge** без напуштања покретача:
  - модс
  - модпацкс
  - схадер пакети
  - пакети ресурса
  - авантуристичке карте и светови
- Решите и инсталирајте зависности модова тамо где их извор обезбеђује.
- Увезите Forge/NeoForge ЈАР-ове за инсталацију и инсталирајте Fabric/Quilt учитаче директно из бирача верзија.

### Графика и перформансе

- Пребацивање између више приказивача из **Подешавања → Рендерер & Дисплаи**:
  - **гл4ес** — OpenGL 2.1 путања компатибилности
  - **ANGLE** — OpenGL ЕС до Metal или Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, експериментално
  - **Zink** — OpenGL 4.1 до Mesa 25 и MoltenVK
  - **LTW** — OpenGL 3.3 до OpenGL ЕС/Metal, Minecraft 1.17+, експериментално
  - **TGLMT** — OpenGL 4.6 Основни до Metal, A11 Bionic или новији
- **TGLMT са Sodium и Iris подршком** за модерна подешавања заснована на схадерима.
- **Генерација оквира** са ГПУ-ом који се прилагођава покрету (MADI) и режимима 3Д поновног пројектовања камере, укључујући временску интерполацију и предиктивну екстраполацију.
- Скалирање резолуције, максимална брзина кадрова, повећање величине FSR 1.0, кеширање ГЛСЛ схадера и подешавање по рендереру.
- Перформансни ХУД са подесивим ФПС, ЦПУ, ГПУ, РАМ меморијом, температуром, батеријом, сатом и ФПС виџетима за генерисање оквира.
- Уграђено снимање перформанси са графиконима, PNG/PDF извоз и дељење.

### Контроле

- Потпуно прилагодљиви распореди контроле на екрану, величине дугмади и транспарентност.
- Подршка за **тастатуру и миш**, укључујући виртуелни миш и подесиву брзину показивача.
- Подршка за **контролор игара** са подесивим изгледима и осетљивошћу.
- **Жироскоп** са подесивом осетљивошћу и инверзијом осе.
- Покрети миша, скроловања и хотбар-а.
- Опционо понашање: додирните да бисте поставили блокове, држите да бисте разбили блокове.
- Двапут додирните хотбар да бисте заменили држану ставку у опуштену.
- Покретна хотбар и подесиво време дугог притиска.

### Покретач и рачуни

- Подршка за налоге **Microsoft**, **локално/офлајн**, **демо** и **Ely.by**.
- Управљајте **Java 8, 17, 21 и 25** временима извођења, преузмите их у апликацији или увезите своје.
- Изаберите LWJGL верзије и подесите ЈВМ аргументе, променљиве окружења и доделу меморије.
- Аутоматско управљање РАМ-ом за уређаје са ограниченом меморијом.
- Теме, боје акцента, замућење, границе, радијус угла, прилагођени фонтови покретача и иконе апликација.
- У игри **F3 информације о уређају**: чип уређаја, iOS верзија, назив/верзија покретача, број верзије и тип израде.
- Опционе интеграције **Witch Сервер**, CurseForge и AI за напредна подешавања.
- **52 језика у апликацији**, укључујући језичке пакете за писање здесна налево и забавне локације.

---

<a id="screenshots"></a>
## Снимци екрана

Снимци екрана из развојне верзије Witch Launcher 0.0.4. Интерфејс се може мењати између верзија и тема.

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
## Захтеви

| Захтев | Детаљи |
|---|---|
| **Уређај** | iPhone или iPad са arm64 процесором и Metal подршком |
| **Систем** | iOS или iPadOS **14.0 или новији** |
| **JIT** | Обавезно. Омогућите JIT до StikDebug, SideStore, TrollStore или јаилбреак подешавање |
| **Налог** | Microsoft налог који поседује Minecraft за званична преузимања; локални и демо режими су такође доступни |
| **Складиштење** | Простор за покретач, Java времена извођења, верзије игре, модове и светове |
| **Мрежа** | Потребно за пријављивање, преузимање верзија, претраживач садржаја и опционе услуге на мрежи |

Witch **не** укључује Minecraft фајлове игара. Датотеке игара се преузимају преко покретача након што се пријавите на налог који испуњава услове.

### JIT напомене

Minecraft: Java Edition треба JIT, а Witch не може покренути игру без њега.

- **Инсталације у стилу SideStore / AltStore:** омогућите JIT за Witch и оставите потребну везу VPN/дебагера активном. Порука у апликацији се односи на **LocalDevVPN** и `CS_DEBUGGED`.
- **StikDebug:** прикључите StikDebug на Witch и омогућите JIT. На **iOS 26/27**, StikDebug мора остати прикачен док игра траје. `UniversalJIT26.js` се копира у клипборд када је потребно.
- **TrollStore:** омогући **URL Scheme** у TrollStore ако Witch чека на JIT.
- **Јаилброкен уређаји:** користите жељени JIT омогућавач.
- Ако покретач остане на екрану **Чека се JIT**, проверите везу за отклањање грешака, поставке VPN и TrollStore URL Scheme пре поновног покретања.

Понашање JIT зависи од верзије iOS и начина инсталације. Ажурирања система могу да прекину постојеће поставке JIT.

---

<a id="installation"></a>
## Инсталација

Witch мора бити потписан за ваш уређај. Ово спремиште не шаље сертификате или унапред потписане ИПА-е.

### Користите градњу

1. Преузмите развојну верзију из [тока рада развоја](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) или користите потписану верзију из извора коме верујете.
2. Потпишите га и инсталирајте помоћу **SideStore**, **AltStore**, **TrollStore** или вашим жељеним методом бочног учитавања.
3. Омогућите JIT као што је горе описано пре покретања игре.

TrollStore верзије користе додатна права и не би требало да се инсталирају са нормалним потписником са бочним учитавањем.

### Изградите из извора

Компајлирање Witch захтева macOS са Xcode алатима командне линије, iOS SDK 14.0 или новији, CMake, JDK 8, `ldid`, `wget`, `zip` и Гит.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Паковане верзије су написане у `artifacts/`.

Да бисте уместо тога направили пакет TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

За изворне везе рендерера и белешке о изградњи, погледајте [`note.md`](../../note.md).

---

<a id="languages"></a>
## Језици

Witch Launcher се испоручује са **52 језичка пакета**. Отворите **Подешавања → Опште → Језик** и изаберите језик или користите **Ауто** да бисте пратили језик уређаја.

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

Апликација испоручује сва **52 језичка пакета**. РЕАДМЕ преводи су доступни за **сва 52 језика**, укључујући енглески.

Неки преводи су машински потпомогнути и могу да садрже незгодне техничке термине. Исправке су добродошле.

Енглески је изворни језик за овај РЕАДМЕ. Локализовани РЕАДМЕ-ови доступни су из бирача језика на врху ове странице иу директоријуму [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Напомене и ограничења

- **JIT је обавезан.** Без исправног подешавања JIT, Minecraft се неће покренути.
- **iOS 26/27 JIT је крхак.** StikDebug мора остати приложен, а будућа ажурирања ОС-а могу да промене оно што функционише.
- Рендерери означени као **експериментално** могу да се сруше или неисправно приказују. Почните са **Ауто** ако нисте сигурни.
- **Генерација оквира** захтева MoltenVK рендерер и Metal рачунарску подршку. Може повећати потрошњу батерије и температуру уређаја.
- Неки модови, пакети модова, сејдери и светови могу захтевати одређену верзију Minecraft, учитавач, рендерер или додатну меморију.
- CurseForge модпацкови користе `manifest.json`; ако инсталација једним додиром није доступна за пакет, увезите архиву ручно.
- Функције на мрежи зависе од услуга трећих страна и могу бити недоступне.
- Снимци екрана су из развојне верзије и можда неће тачно одговарати тренутном издању.

---

<a id="project-lineage"></a>
## Линија пројекта

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

### Повезани пројекти

- [Amethyst Андроид](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Допринос

Извештаји о грешкама и ПР-ови су добродошли. Када пријавите проблем, укључите:

- модел уређаја и верзија iOS/iPadOS
- Witch Launcher верзија
- рендерер и Minecraft верзија
- учитавач модова и листа инсталираних модова
- кораци за репродукцију
- релевантни дневник или извештај о паду

Молимо вас да не урезујете сертификате за потписивање, профиле за обезбеђивање, API кључеве или друге тајне.

---

<a id="credits"></a>
## Цредитс

**Witch Launcher** одржава **ДуиАнх662 (За_д626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [Кс](https://x.com/duyanh662)

### Узводно и заједница

Witch Launcher и његови упстреам пројекти су изграђени на раду многих сарадника, укључујући:

- **@crystall1nedev** — Amethyst менаџер пројекта и iOS програмер порта
- **@khanhduytran0** — iOS програмер порта
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Додатно захваљујемо **@луникбоцхс**, **@птитСеб**, **@какасхидинхо**, пројекту ANGLE, Кхронос групи, Mesa пројекту, PojavLauncher тиму, Мозили и заједници Minecraft.

Посебно хвала [MCHeads](https://mc-heads.net) за пружање Minecraft услуга аватара.

Комплетна компонента и листа лиценци треће стране су доступне у [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Лиценца

Witch Launcher се дистрибуира под **ГНУ општом јавном лиценцом в3.0**, у складу са лиценцама и захтевима за ауторска права компоненти треће стране наведене у [`credits.md`](../../credits.md).

Погледајте [`LICENSE`](../../LICENSE) за комплетан текст лиценце.

---

<p align="center">
<sub>Minecraft је заштитни знак Mojang Studios. Witch Launcher није повезан са Mojang Studios, Microsoft или Amethyst пројектом.</sub>
</p>
