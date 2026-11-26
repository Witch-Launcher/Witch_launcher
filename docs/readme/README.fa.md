<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition در iPhone و iPad.</strong><br>
یک چنگال iOS و iPadOS ساخته شده در جامعه از Amethyst، نگهداری شده توسط DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[ویژگی ها](#features) · [عکس های صفحه](#screenshots) · [شرایط مورد نیاز](#requirements) · [نصب](#installation) · [زبان](#languages) · [اعتبار](#credits) · [مجوز](#license)

<details>
<summary><strong>زبان ها</strong></summary>

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
## درباره

**Witch Launcher** یک چنگال مستقل و حفظ شده توسط جامعه از [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) است که **Minecraft: Java Edition** را به iPhone و iPad می رساند. این رابط کاربری پرتاب اولین لمسی را با یک مدیریت زمان اجرا کامل Java، LWJGL، و یک پشته گرافیکی ساخته شده در اطراف لایه های ترجمه Metal، MoltenVK، و OpenGL ترکیب می کند.

Witch بر اساس کار [Boardwalk](https://github.com/zhuowei/Boardwalk)، [PojavLauncher](https://github.com/PojavLauncherTeam) جامعه، Amethyst-iOS و Amethyst-iOS-25 بنا شده است. این یک پروژه مستقل است و به Mojang Studios،Microsoft، یا تیم بالادست Amethyst وابسته نیست.

> **نسخه فعلی:** 0.0.4 · برای یادداشت های انتشار به [`news.md`](../../news.md) مراجعه کنید.

---

<a id="features"></a>
## ویژگی ها

### Minecraft و مدها

- اکثر نسخه‌های **Minecraft: Java Edition**، از نسخه‌های اولیه بتا تا آخرین عکس‌های فوری را اجرا می‌کند.
- پشتیبانی از **وانیل، Fabric، Quilt، Forge، NeoForge، و OptiFine**.
- **نمایه‌های بازی** مجزا را با تنظیمات، حالت‌ها، سایه‌زنان، بسته‌های منابع و جهان‌های خاص خود ایجاد کنید.
- محتوای **Modrinth و CurseForge** را بدون خروج از راه‌انداز مرور و نصب کنید:
  - مدها
  - modpacks
  - بسته های سایه زن
  - بسته های منابع
  - نقشه ها و جهان های ماجراجویی
- وابستگی‌های مود را در جایی که منبع ارائه می‌کند، حل کرده و نصب کنید.
- JARهای نصب کننده Forge/NeoForge را وارد کنید و لودرهای Fabric/Quilt را مستقیماً از انتخابگر نسخه نصب کنید.

### گرافیک و عملکرد

- از **تنظیمات ← رندر و نمایش** بین چند رندر جابجا شوید:
  - **gl4es** — مسیر سازگاری OpenGL 2.1
  - **ANGLE** — OpenGL ES تا Metal یا Vulkan
  - **MobileGlues** — OpenGL 4.0، Minecraft 1.17+، تجربی
  - **Zink** — OpenGL 4.1 تا Mesa 25 و MoltenVK
  - **LTW** — OpenGL 3.3 تا OpenGL ES/Metal، Minecraft 1.17+، تجربی
  - **TGLMT** — OpenGL 4.6 هسته تا Metal، A11 Bionic یا جدیدتر
- **TGLMT با پشتیبانی Sodium و Iris** برای تنظیمات مبتنی بر سایه زن مدرن.
- **تولید فریم** با GPU سازگار با حرکت (MADI) و حالت‌های بازپروژه سه بعدی دوربین، از جمله درون یابی زمانی و برون یابی پیش بینی.
- مقیاس‌بندی وضوح، حداکثر نرخ فریم، ارتقاء مقیاس FSR 1.0، حافظه پنهان سایه‌زن GLSL، و تنظیم هر رندر.
- عملکرد HUD با FPS، CPU، GPU، RAM، دما، باتری، ساعت و فریم ویجت‌های FPS قابل تنظیم.
- ضبط عملکرد داخلی با نمودارها، صادرات PNG/PDF، و اشتراک گذاری.

### کنترل ها

- طرح‌بندی‌های کنترل روی صفحه، اندازه دکمه‌ها و شفافیت کاملاً قابل تنظیم.
- پشتیبانی از **صفحه کلید و ماوس**، از جمله ماوس مجازی و سرعت اشاره گر قابل تنظیم.
- پشتیبانی **کنترل‌کننده بازی** با چینش‌های قابل تنظیم و حساسیت.
- هدف گیری **ژیروسکوپ** با حساسیت قابل تنظیم و وارونگی محور.
- حرکات ماوس، اسکرول و هاتبار.
- رفتار اختیاری: برای قرار دادن بلوک ها ضربه بزنید، برای شکستن بلوک ها را نگه دارید.
- دوبار روی هاتبار ضربه بزنید تا آیتم نگه‌داشته شده را در حالت غیرفعال قرار دهید.
- هاتبار قابل لغزش و زمان فشار طولانی قابل تنظیم.

### راه‌انداز و حساب‌ها

- **Microsoft**، **محلی/آفلاین**، **دمو**، و **Ely.by** پشتیبانی حساب.
- زمان‌های اجرا **Java 8، 17، 21، و 25** را مدیریت کنید، آن‌ها را درون برنامه دانلود کنید، یا خودتان وارد کنید.
- نسخه های LWJGL را انتخاب کنید و آرگومان های JVM، متغیرهای محیطی و تخصیص حافظه را تنظیم کنید.
- مدیریت خودکار RAM برای دستگاه هایی با حافظه محدود.
- تم ها، رنگ های تاکیدی، تاری، حاشیه ها، شعاع گوشه، فونت های راه اندازی سفارشی، و نمادهای برنامه.
- **F3 اطلاعات دستگاه** درون بازی: تراشه دستگاه، نسخه iOS، نام/نسخه راه‌انداز، شماره ساخت و نوع ساخت.
- یکپارچه‌سازی‌های **Witch سرور**، CurseForge، و AI برای تنظیمات پیشرفته.
- **۵۲ زبان درون برنامه‌ای**، از جمله بسته‌های زبانی راست به چپ و مناطق سرگرم‌کننده.

---

<a id="screenshots"></a>
## اسکرین شات ها

اسکرین شات از ساخت توسعه Witch Launcher 0.0.4. رابط می تواند بین نسخه ها و تم ها تغییر کند.

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
## الزامات

| مورد نیاز | جزئیات |
|---|---|
| **دستگاه** | iPhone یا iPad با پردازنده arm64 و پشتیبانی Metal |
| **سیستم** | iOS یا iPadOS **14.0 یا جدیدتر** |
| **JIT** | مورد نیاز. فعال کردن JIT از طریق StikDebug، SideStore، TrollStore، یا تنظیمات جیلبریک |
| **حساب** | یک حساب Microsoft که دارای Minecraft برای دانلودهای رسمی است. حالت محلی و دمو نیز موجود است |
| **ذخیره** | فضایی برای لانچر، زمان‌های اجرا Java، نسخه‌های بازی، مدها و دنیاها |
| **شبکه** | برای ورود به سیستم، دانلود نسخه، مرورگر محتوا و خدمات آنلاین اختیاری مورد نیاز است |

Witch فایل های بازی Minecraft را **نمی** می کند. فایل‌های بازی پس از ورود به حساب واجد شرایط، از طریق لانچر دانلود می‌شوند.

### یادداشت های JIT

Minecraft: Java Edition به JIT نیاز دارد و Witch نمی تواند بازی را بدون آن راه اندازی کند.

- نصب‌های **SideStore / AltStore به سبک:** JIT را برای Witch فعال کنید و اتصال VPN/اشکال‌زدای مورد نیاز را فعال نگه دارید. پیام درون برنامه به **LocalDevVPN** و `CS_DEBUGGED` اشاره دارد.
- **StikDebug:** StikDebug را به Witch پیوست کنید و JIT را فعال کنید. در **iOS 26/27**، StikDebug باید در حین اجرای بازی پیوست بماند. `UniversalJIT26.js` در صورت نیاز در کلیپ بورد کپی می شود.
- **TrollStore:** **URL Scheme** را در TrollStore فعال کنید اگر Witch همچنان منتظر JIT است.
- **دستگاه های فرار از زندان:** از فعال کننده JIT دلخواه خود استفاده کنید.
- اگر راه‌انداز در صفحه **در انتظار JIT** باقی می‌ماند، قبل از راه‌اندازی مجدد، اتصال اشکال‌زدا، VPN و تنظیمات TrollStore URL Scheme را بررسی کنید.

رفتار JIT به نسخه iOS و روش نصب بستگی دارد. به روز رسانی سیستم می تواند تنظیمات JIT موجود را خراب کند.

---

<a id="installation"></a>
## نصب و راه اندازی

Witch باید برای دستگاه شما امضا شود. این مخزن گواهی ها یا IPA های از پیش امضا شده را ارسال نمی کند.

### از ساختنی استفاده کنید

1. یک ساخت توسعه را از [جریان کاری توسعه] دانلود کنید (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)، یا از یک ساخت امضا شده از منبعی که به آن اعتماد دارید استفاده کنید.
2. آن را با **SideStore**، **AltStore**، **TrollStore** یا روش بارگذاری جانبی دلخواه خود امضا و نصب کنید.
3. قبل از شروع بازی، JIT را همانطور که در بالا توضیح داده شد، فعال کنید.

بیلدهای TrollStore از حقایق اضافی استفاده می کنند و نباید با یک امضاکننده بارگذاری جانبی معمولی نصب شوند.

### ساخت از منبع

کامپایل Witch به macOS با ابزارهای خط فرمان Xcode، iOS SDK 14.0 یا جدیدتر، CMake، JDK 8، `ldid`، `wget`، `zip`، و Git نیاز دارد.

```bash
git clone -- بازگشتی https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

بیلدهای بسته بندی شده به `artifacts/` نوشته می شوند.

برای ساختن یک بسته TrollStore به جای آن:

```bash
make package TROLLSTORE_JIT_ENT=1
```

برای پیوندهای منبع رندر و یادداشت‌های ساخت، [`note.md`](../../note.md) را ببینید.

---

<a id="languages"></a>
## زبان ها

Witch Launcher با **52 بسته زبان** ارسال می‌شود. **تنظیمات ← عمومی ← زبان** را باز کنید و یک زبان را انتخاب کنید، یا از **خودکار** برای دنبال کردن زبان دستگاه استفاده کنید.

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

این برنامه همه **52 بسته زبان** را ارسال می کند. ترجمه‌های README برای **همه 52 زبان** از جمله انگلیسی در دسترس هستند.

برخی از ترجمه ها به کمک ماشین هستند و ممکن است حاوی اصطلاحات فنی ناخوشایند باشند. اصلاحات استقبال می شود.

انگلیسی زبان منبع این README است. READMEهای محلی شده از انتخابگر زبان در بالای این صفحه و در فهرست [`docs/readme/`](./) در دسترس هستند.

---

<a id="notes-and-limitations"></a>
## یادداشت ها و محدودیت ها

- **JIT اجباری است.** بدون راه‌اندازی JIT، Minecraft راه‌اندازی نمی‌شود.
- **iOS 26/27 JIT شکننده است.** StikDebug باید پیوست باقی بماند، و به‌روزرسانی‌های آینده سیستم‌عامل ممکن است عملکرد را تغییر دهند.
- رندرهایی که **آزمایشی** علامت‌گذاری شده‌اند ممکن است خراب شوند یا نادرست رندر شوند. اگر مطمئن نیستید با **Auto** شروع کنید.
- **تولید فریم** نیاز به ارائه‌دهنده MoltenVK و پشتیبانی محاسبه Metal دارد. می تواند مصرف باتری و دمای دستگاه را افزایش دهد.
- برخی از مودها، مودپک‌ها، سایه‌زن‌ها و جهان‌ها ممکن است به یک نسخه Minecraft، لودر، رندر یا حافظه اضافی نیاز داشته باشند.
- CurseForge modpacks از `manifest.json` استفاده می کنند. اگر نصب با یک ضربه برای یک بسته در دسترس نیست، بایگانی را به صورت دستی وارد کنید.
- ویژگی های آنلاین به خدمات شخص ثالث بستگی دارد و ممکن است در دسترس نباشد.
- اسکرین شات ها از یک ساخت توسعه هستند و ممکن است دقیقاً با نسخه فعلی مطابقت نداشته باشند.

---

<a id="project-lineage"></a>
## اصل و نسب پروژه

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

### پروژه های مرتبط

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## کمک کردن

گزارش اشکال و روابط عمومی استقبال می شود. هنگام گزارش یک مشکل، شامل موارد زیر باشد:

- مدل دستگاه و نسخه iOS/iPadOS
- نسخه Witch Launcher
- رندر و نسخه Minecraft
- مود لودر و لیستی از مدهای نصب شده
- مراحل تولید مثل
- گزارش مربوطه یا گزارش خرابی

لطفاً گواهینامه‌های امضا، تهیه نمایه‌ها، کلیدهای API، یا اسرار دیگر را متعهد نشوید.

---

<a id="credits"></a>
## اعتبارات

**Witch Launcher** توسط **DuyAnh662 (Za_d626)** نگهداری می‌شود.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### بالادست و جامعه

Witch Launcher و پروژه های بالادستی آن بر اساس کار بسیاری از مشارکت کنندگان ساخته شده اند، از جمله:

- **@crystall1nedev** — مدیر پروژه Amethyst و توسعه دهنده پورت iOS
- **@khanhduytran0** — توسعه‌دهنده بندر iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

با تشکر اضافی از **@lunixbochs**، **@ptitSeb**، **@kakashidinho**، پروژه ANGLE، گروه Khronos، Mesa پروژه، PojavLauncher تیم، Mozilla، و انجمن Minecraft.

تشکر ویژه از [MCHeads](https://mc-heads.net) برای ارائه خدمات آواتار Minecraft.

جزء کامل شخص ثالث و لیست مجوز در [`credits.md`](../../credits.md) موجود است.

---

<a id="license"></a>
## مجوز

Witch Launcher تحت **مجوز عمومی عمومی گنو نسخه 3.0** توزیع شده است، مشروط به مجوزها و الزامات حق نسخه برداری اجزای شخص ثالث فهرست شده در [`credits.md`](../../credits.md).

برای متن کامل مجوز به [`LICENSE`](../../LICENSE) مراجعه کنید.

---

<p align="center">
<sub>Minecraft علامت تجاری Mojang Studios است. Witch Launcher به Mojang Studios، Microsoft، یا پروژه Amethyst وابسته نیست.</sub>
</p>
