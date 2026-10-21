<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition по iPhone и iPad.</strong><br>
Созданная сообществом форк iOS и iPadOS Amethyst, поддерживаемая DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Функции](#features) · [Скриншоты](#screenshots) · [Требования](#requirements) · [Установка](#installation) · [Языки](#languages) · [Кредиты](#credits) · [Лицензия](#license)

<details>
<summary><strong>Языки</strong></summary>

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
## О

**Witch Launcher** — это независимая, поддерживаемая сообществом версия [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), которая превращает **Minecraft: Java Edition** в iPhone и iPad. Он сочетает в себе сенсорный интерфейс запуска с полным менеджером времени выполнения Java, LWJGL, и графическим стеком, построенным на основе слоев перевода Metal, MoltenVK и OpenGL.

Witch основан на работе [Boardwalk](https://github.com/zhuowei/Boardwalk), сообщества [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS и Amethyst-iOS-25. Это независимый проект, не связанный с Mojang Studios, Microsoft или командой разработчиков Amethyst.

> **Текущая версия:** 0.0.4 · Примечания к выпуску см. в [`news.md`](../../news.md).

---

<a id="features"></a>
## Особенности

### Minecraft и моды

- Работает с большинством версий **Minecraft: Java Edition**, от ранних бета-версий до последних снимков.
- Поддерживает **Vanilla, Fabric, Quilt, Forge, NeoForge и OptiFine**.
- Создавайте изолированные **игровые профили** со своими собственными настройками, модами, шейдерами, пакетами ресурсов и мирами.
- Просматривайте и устанавливайте контент из **Modrinth и CurseForge**, не выходя из панели запуска:
  - моды
  - модпаки
  - пакеты шейдеров
  - пакеты ресурсов
  - карты приключений и миры
- Разрешите и установите зависимости модов там, где их предоставляет источник.
- Импортируйте JAR-файлы установщика Forge/NeoForge и устанавливайте загрузчики Fabric/Quilt непосредственно из средства выбора версий.

### Графика и производительность

- Переключайтесь между несколькими модулями рендеринга в **Настройки → Средство рендеринга и отображения**:
  - **gl4es** — путь совместимости OpenGL 2.1
  - **ANGLE** — OpenGL от ES до Metal или Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, экспериментальная версия
  - **Zink** — от OpenGL 4.1 до Mesa 25 и MoltenVK
  - **LTW** — от OpenGL 3.3 до OpenGL ES/Metal, Minecraft 1.17+, экспериментальная версия
  - **TGLMT** — OpenGL 4.6 От ядра до Metal, A11 Bionic или новее
- **TGLMT с поддержкой Sodium и Iris** для современных установок на основе шейдеров.
- **Генерация кадров** с помощью адаптивного к движению графического процессора (MADI) и режимов 3D-перепроецирования камеры, включая временную интерполяцию и прогнозирующую экстраполяцию.
- Масштабирование разрешения, максимальная частота кадров, масштабирование FSR 1.0, кэши шейдеров GLSL и настройка для каждого рендерера.
- HUD производительности с настраиваемыми виджетами FPS, CPU, GPU, RAM, температуры, батареи, часов и генерации кадров FPS.
- Встроенная запись исполнения с диаграммами, экспорт PNG/PDF и обмен информацией.

### Элементы управления

- Полностью настраиваемые макеты экранных элементов управления, размеры кнопок и прозрачность.
- Поддержка **клавиатуры и мыши**, включая виртуальную мышь и регулируемую скорость указателя.
- Поддержка **игрового контроллера** с настраиваемыми макетами и чувствительностью.
- **Гироскоп** с регулируемой чувствительностью и инверсией оси.
- Жесты мыши, прокрутки и панели быстрого доступа.
- Дополнительное поведение: нажмите, чтобы разместить блоки, удерживайте, чтобы разбить блоки.
- Дважды коснитесь панели быстрого доступа, чтобы переместить удерживаемый предмет в дополнительную руку.
- Сдвижная панель быстрого доступа и регулируемое время длительного нажатия.

### Лаунчер и аккаунты

- Поддержка учетных записей **Microsoft**, **локальная/офлайн**, **демо** и **Ely.by**.
- Управляйте средами выполнения **Java 8, 17, 21 и 25**, загружайте их в приложение или импортируйте свои собственные.
- Выберите версии LWJGL и настройте аргументы JVM, переменные среды и распределение памяти.
- Автоматическое управление оперативной памятью для устройств с ограниченной памятью.
- Темы, акцентные цвета, размытие, границы, радиус углов, пользовательские шрифты запуска и значки приложений.
- Внутриигровая **F3 информация об устройстве**: чип устройства, версия iOS, название/версия средства запуска, номер сборки и тип сборки.
- Дополнительная интеграция **Witch Server**, CurseForge и AI для расширенных настроек.
- **52 языка приложения**, включая языковые пакеты с письмом справа налево и забавные языки.

---

<a id="screenshots"></a>
## Скриншоты

Скриншоты разрабатываемой сборки Witch Launcher 0.0.4. Интерфейс может меняться в зависимости от версии и темы.

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
## Требования

| Требование | Подробности |
|---|---|
| **Устройство** | iPhone или iPad с процессором arm64 и поддержкой Metal |
| **Система** | iOS или iPadOS **14.0 или новее** |
| **JIT** | Необходимый. Включите JIT–StikDebug, SideStore, TrollStore или установку с джейлбрейком |
| **Аккаунт** | Учетная запись Microsoft, владеющая Minecraft для официальных загрузок; также доступны локальный и демонстрационный режимы |
| **Хранение** | Место для лаунчера, среды выполнения Java, версий игр, модов и миров |
| **Сеть** | Требуется для входа в систему, загрузки версий, браузера содержимого и дополнительных онлайн-сервисов |

Witch **не** включает файлы игры Minecraft. Файлы игры загружаются через программу запуска после входа в соответствующую учетную запись.

### JIT примечания

Для Minecraft: Java Edition требуется JIT, а Witch не может запустить игру без него.

- **Установка в стиле SideStore / AltStore:** включите JIT для Witch и оставьте активное требуемое соединение VPN/отладчик. Сообщение в приложении относится к **LocalDevVPN** и `CS_DEBUGGED`.
- **StikDebug:** присоедините StikDebug к Witch и включите JIT. **iOS 26/27** StikDebug должен оставаться прикрепленным во время игры. `UniversalJIT26.js` копируется в буфер обмена при необходимости.
- **TrollStore:** включите **URL Scheme** в TrollStore, если Witch продолжает ждать JIT.
- **Устройства с джейлбрейком:** используйте предпочитаемый вами активатор JIT.
- Если программа запуска остается на экране **Ожидание JIT**, проверьте подключение отладчика, настройки VPN и TrollStore URL Scheme перед перезапуском.

Поведение JIT зависит от версии iOS и метода установки. Обновления системы могут нарушить существующие настройки JIT.

---

<a id="installation"></a>
## Установка

Witch должен быть подписан для вашего устройства. Этот репозиторий не отправляет сертификаты или предварительно подписанные IPA.

### Используйте сборку

1. Загрузите сборку для разработки из [рабочего процесса разработки] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) или используйте подписанную сборку из источника, которому вы доверяете.
2. Подпишите и установите его с помощью **SideStore**, **AltStore**, **TrollStore** или предпочитаемого вами метода загрузки неопубликованных материалов.
3. Перед запуском игры включите JIT, как описано выше.

Сборки TrollStore используют дополнительные права и не должны устанавливаться с помощью обычного подписывающего лица, загружающего неопубликованные версии.

### Сборка из исходного кода

Для компиляции Witch требуется macOS с инструментами командной строки Xcode, iOS SDK 14.0 или новее, CMake, JDK 8, `ldid`, `wget`, `zip` и Git.

```bash
git клон --рекурсивный https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Пакетные сборки записаны в `artifacts/`.

Чтобы вместо этого собрать пакет TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Ссылки на исходные коды средства рендеринга и примечания к сборке см. в [`note.md`](../../note.md).

---

<a id="languages"></a>
## Языки

Witch Launcher поставляется с **52 языковыми пакетами**. Откройте **Настройки → Общие → Язык** и выберите язык или используйте **Авто**, чтобы выбрать язык устройства.

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

Приложение поставляется со всеми **52 языковыми пакетами**. Переводы README доступны для **всех 52 языков**, включая английский.

Некоторые переводы выполняются машинным способом и могут содержать неудобные технические термины. Исправления приветствуются.

Исходным языком данного README является английский. Локализованные файлы README доступны с помощью переключателя языка вверху этой страницы и в каталоге [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Примечания и ограничения

- **JIT является обязательным.** Без работающей установки JIT Minecraft не запустится.
- **iOS 26/27 JIT хрупкий.** StikDebug должен оставаться прикрепленным, и будущие обновления ОС могут изменить то, что работает.
- Средства визуализации, помеченные как **экспериментальные**, могут привести к сбою или некорректному рендерингу. Если вы не уверены, начните с **Авто**.
- **Генерация кадров** требует средства рендеринга MoltenVK и поддержки вычислений Metal. Это может увеличить расход заряда батареи и температуру устройства.
- Для некоторых модов, модпаков, шейдеров и миров может потребоваться определенная версия Minecraft, загрузчик, средство рендеринга или дополнительная память.
- Модпаки CurseForge используют `manifest.json`; если для пакета недоступна установка в одно касание, импортируйте архив вручную.
- Онлайн-функции зависят от сторонних сервисов и могут быть недоступны.
- Снимки экрана взяты из разрабатываемой сборки и могут не совсем соответствовать текущей версии.

---

<a id="project-lineage"></a>
## Родословная проекта

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

### Связанные проекты

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Содействие

Сообщения об ошибках и PR приветствуются. Сообщая о проблеме, укажите:

- модель устройства и версия iOS/iPadOS
- Witch Launcher версия
- рендерер и версия Minecraft
- загрузчик модов и список установленных модов
- шаги по воспроизведению
- соответствующий журнал или отчет о сбое

Пожалуйста, не раскрывайте сертификаты подписи, профили обеспечения, ключи API или другие секреты.

---

<a id="credits"></a>
## Кредиты

**Witch Launcher** поддерживается **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Добыча и сообщество

Witch Launcher и его проекты по разведке и добыче основаны на работе многих участников, в том числе:

- **@crystall1nedev** — руководитель проекта Amethyst и разработчик порта iOS
- **@khanhduytran0** — разработчик порта iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Дополнительная благодарность **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, проекту ANGLE, группе Khronos, проекту Mesa, команде PojavLauncher, Mozilla и сообществу Minecraft.

Особая благодарность [MCHeads](https://mc-heads.net) за предоставление услуг по созданию аватаров Minecraft.

Полный список сторонних компонентов и лицензий доступен в [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Лицензия

Witch Launcher распространяется под лицензией **GNU General Public License v3.0** с учетом лицензий и требований авторских прав сторонних компонентов, перечисленных в [`credits.md`](../../credits.md).

Полный текст лицензии см. в [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft является товарным знаком Mojang Studios. Witch Launcher не связан с Mojang Studios, Microsoft или проектом Amethyst.</sub>
</p>
