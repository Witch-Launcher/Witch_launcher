<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition на iPhone і iPad.</strong><br>
Розгалуження iOS і iPadOS Amethyst, створене спільнотою, підтримується DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Функції](#features) · [Знімки екрана](#screenshots) · [Вимоги](#requirements) · [Встановлення](#installation) · [Мови](#languages) · [Кредити](#credits) · [Ліцензія](#license)

<details>
<summary><strong>Мови</strong></summary>

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
## про

**Witch Launcher** — це незалежний, підтримуваний спільнотою розгалуження [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), який переносить **Minecraft: Java Edition** у iPhone та iPad. Він поєднує в собі інтерфейс запуску з першим дотиком із повним менеджером середовища виконання Java, LWJGL, і графічним стеком, створеним навколо шарів перекладу Metal, MoltenVK і OpenGL.

Witch побудовано на роботі [Boardwalk](https://github.com/zhuowei/Boardwalk), спільноти [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS і Amethyst-iOS-25. Це незалежний проект і не пов’язаний з командою Mojang Studios, Microsoft або командою Amethyst.

> **Поточна версія:** 0.0.4 · Див. [`news.md`](../../news.md) для приміток до випуску.

---

<a id="features"></a>
## Особливості

### Minecraft та модифікації

- Запускає більшість версій **Minecraft: Java Edition**, від ранніх бета-версій до останніх знімків.
- Підтримує **Vanilla, Fabric, Quilt, Forge, NeoForge і OptiFine**.
- Створюйте ізольовані **ігрові профілі** з власними налаштуваннями, модами, шейдерами, пакетами ресурсів і світами.
- Переглядайте та встановлюйте вміст із **Modrinth і CurseForge**, не виходячи з панелі запуску:
  - моди
  - пакети модів
  - пакети шейдерів
  - пакети ресурсів
  - карти пригод і світи
- Розв’яжіть і встановіть залежності модів там, де їх надає джерело.
- Імпортуйте файли JAR інсталятора Forge/NeoForge і встановлюйте завантажувачі Fabric/Quilt безпосередньо з засобу вибору версій.

### Графіка та продуктивність

- Перемикайтеся між декількома засобами візуалізації в меню **Налаштування → Рендерер і дисплей**:
  - **gl4es** — шлях сумісності OpenGL 2.1
  - **ANGLE** — OpenGL ES до Metal або Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, експериментальний
  - **Zink** — OpenGL 4.1 до Mesa 25 і MoltenVK
  - **LTW** — OpenGL 3.3 до OpenGL ES/Metal, Minecraft 1.17+, експериментальний
  - **TGLMT** — OpenGL 4.6 Базовий до Metal, A11 Bionic або новіші
- **TGLMT з підтримкою Sodium і Iris** для сучасних установок на основі шейдерів.
- **Генерація кадрів** за допомогою графічного процесора з адаптацією до руху (MADI) і режимів Camera 3D Reproject, включаючи часову інтерполяцію та прогнозну екстраполяцію.
- Масштабування роздільної здатності, максимальна частота кадрів, підвищення масштабу FSR 1.0, кеші шейдерів GLSL і налаштування кожного рендерера.
- Performance HUD із настроюваними FPS, CPU, GPU, RAM, температурою, акумулятором, годинником і віджетами FPS для створення кадрів.
- Вбудований запис продуктивності з діаграмами, PNG/PDF експорт і спільний доступ.

### Елементи керування

- Повністю настроювані елементи керування на екрані, розміри кнопок і прозорість.
- Підтримка **клавіатури та миші**, включаючи віртуальну мишу та регульовану швидкість вказівника.
- Підтримка **ігрового контролера** з настроюваними макетами та чутливістю.
- **Гіроскоп** прицілювання з регульованою чутливістю та інверсією осі.
- Жести миші, прокручування та гарячої панелі.
- Додаткова поведінка: натисніть, щоб розмістити блоки, утримуйте, щоб розбити блоки.
- Двічі торкніться гарячої панелі, щоб поміняти утримуваний предмет на оф-хенд.
- Пересувна гаряча панель і регульований час тривалого натискання.

### Лаунчер і облікові записи

- Підтримка облікових записів **Microsoft**, **локальний/офлайн**, **демо** та **Ely.by**.
- Керуйте середовищами виконання **Java 8, 17, 21 і 25**, завантажуйте їх у програмі або імпортуйте власні.
- Виберіть версії LWJGL і налаштуйте аргументи JVM, змінні середовища та розподіл пам’яті.
- Автоматичне керування оперативною пам'яттю для пристроїв з обмеженою пам'яттю.
- Теми, акцентні кольори, розмиття, межі, кутовий радіус, спеціальні шрифти панелі запуску та значки програм.
- **Інформація про пристрій F3** у грі: чіп пристрою, версія iOS, назва/версія програми запуску, номер збірки та тип збірки.
- Додаткова інтеграція **Witch Server**, CurseForge і AI для розширених налаштувань.
- **52 мови програми**, включаючи мовні пакети справа наліво та цікаві мови.

---

<a id="screenshots"></a>
## Screenshots

Скріншоти зі збірки розробки Witch Launcher 0.0.4. Інтерфейс може змінюватися між версіями та темами.

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
## Requirements

| Вимога | Details |
|---|---|
| **Пристрій** | iPhone або iPad з процесором arm64 і підтримкою Metal |
| **System** | iOS або iPadOS **14.0 або новіша** |
| **JIT** | Обов'язковий. Увімкнути JIT - StikDebug, SideStore, TrollStore або зламану установку |
| **Account** | Обліковий запис Microsoft, який володіє Minecraft для офіційних завантажень; локальний і демонстраційний режими також доступні |
| **Storage** | Місце для панелі запуску, середовища виконання Java, версій гри, модів і світів |
| **Мережа** | Необхідно для входу, завантаження версії, браузера вмісту та додаткових онлайн-служб |

Witch **не** включає файли гри Minecraft. Файли гри завантажуються через панель запуску після входу в відповідний обліковий запис.

### JIT примітки

Minecraft: Java Edition потребує JIT, а Witch не може запустити гру без нього.

- **Встановлення у стилі SideStore / AltStore:** увімкніть JIT для Witch і збережіть необхідне з’єднання VPN/дебагера активним. Повідомлення в додатку стосується **LocalDevVPN** і `CS_DEBUGGED`.
- **StikDebug:** приєднайте StikDebug до Witch і ввімкніть JIT. У **iOS 26/27** StikDebug має залишатися підключеним, поки гра працює. `UniversalJIT26.js` за потреби копіюється до буфера обміну.
- **TrollStore:** увімкніть **URL Scheme** у TrollStore, якщо Witch чекає на JIT.
- **Зламані пристрої:** використовуйте бажаний активатор JIT.
- Якщо програма запуску залишається на екрані **Очікування JIT**, перевірте підключення до налагоджувача, налаштування VPN і TrollStore URL Scheme перед повторним запуском.

Поведінка JIT залежить від версії iOS і методу встановлення. Оновлення системи можуть порушити існуючі налаштування JIT.

---

<a id="installation"></a>
## монтаж

Witch має бути підписано для вашого пристрою. Цей репозиторій не надсилає сертифікати чи попередньо підписані IPA.

### Використовуйте збірку

1. Завантажте збірку розробки з [процесу розробки](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) або скористайтеся підписаною збіркою з джерела, якому ви довіряєте.
2. Підпишіть і встановіть його за допомогою **SideStore**, **AltStore**, **TrollStore** або бажаного методу бокового завантаження.
3. Увімкніть JIT, як описано вище, перед запуском гри.

У збірках TrollStore використовуються додаткові права доступу, і їх не слід встановлювати разом із звичайним підписувачем із боковим завантаженням.

### Збірка з джерела

Компіляція Witch вимагає macOS з інструментами командного рядка Xcode, iOS SDK 14.0 або новішої версії, CMake, JDK 8, `ldid`, `wget`, `zip` і Git.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Пакетні збірки описані в `artifacts/`.

Щоб замість цього створити пакунок TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Посилання на джерела рендерера та примітки до збірки див. [`note.md`](../../note.md).

---

<a id="languages"></a>
## Мови

Witch Launcher постачається з **52 мовними пакетами**. Відкрийте **Налаштування → Загальні → Мова** та виберіть мову або скористайтеся **Авто**, щоб слідкувати за мовою пристрою.

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

Програма постачає всі **52 мовні пакети**. Переклади README доступні для **всіх 52 мов**, включаючи англійську.

Деякі переклади виконуються машинним способом і можуть містити незграбні технічні терміни. Corrections are welcome.

Англійська є вихідною мовою для цього README. Локалізовані файли README доступні за допомогою селектора мови у верхній частині цієї сторінки та в каталозі [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Примітки та обмеження

- **JIT є обов’язковим.** Без працюючого налаштування JIT Minecraft не запуститься.
- **iOS 26/27 JIT крихкий.** StikDebug має залишатися підключеним, і майбутні оновлення ОС можуть змінити роботу.
- Засоби візуалізації, позначені як **експериментальні**, можуть виходити з ладу або відтворюватися неправильно. Почніть із **Авто**, якщо ви не впевнені.
- Для **генерації фреймів** потрібен рендерер MoltenVK і підтримка обчислень Metal. Це може збільшити використання акумулятора та температуру пристрою.
- Для деяких модів, пакетів модів, шейдерів і світів може знадобитися певна версія Minecraft, завантажувач, рендерер або додаткова пам’ять.
- CurseForge пакети модів використовують `manifest.json`; якщо установка одним дотиком недоступна для пакета, імпортуйте архів вручну.
- Онлайн-функції залежать від сторонніх служб і можуть бути недоступними.
- Скріншоти взято зі збірки розробки й можуть не точно відповідати поточному випуску.

---

<a id="project-lineage"></a>
## Родовід проекту

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

### Пов'язані проекти

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Сприяння

Повідомлення про помилки та PR вітаються. Повідомляючи про проблему, укажіть:

- модель пристрою та версію iOS/iPadOS
- Witch Launcher версія
- рендерер і версія Minecraft
- завантажувач модів і список встановлених модів
- кроки для відтворення
- відповідний журнал або звіт про збої

Будь ласка, не передавайте сертифікати підпису, профілі надання, ключі API або інші секрети.

---

<a id="credits"></a>
## Кредити

**Witch Launcher** підтримується **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Вгору та громада

Witch Launcher і його попередні проекти побудовані на роботі багатьох учасників, зокрема:

- **@crystall1nedev** — керівник проекту Amethyst і розробник портів iOS
- **@khanhduytran0** — розробник порту iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Додаткова подяка **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, проекту ANGLE, групі Khronos, проекту Mesa, команді PojavLauncher, Mozilla та спільноті Minecraft.

Особлива подяка [MCHeads](https://mc-heads.net) за надання послуг аватарів Minecraft.

Повний список сторонніх компонентів і ліцензій доступний у [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Ліцензія

Witch Launcher розповсюджується згідно з **Загальною публічною ліцензією GNU v3.0**, відповідно до ліцензій і вимог щодо авторських прав сторонніх компонентів, перелічених у [`credits.md`](../../credits.md).

Повний текст ліцензії див. [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft є товарним знаком Mojang Studios. Witch Launcher не пов'язаний з Mojang Studios, Microsoft або проектом Amethyst.</sub>
</p>
