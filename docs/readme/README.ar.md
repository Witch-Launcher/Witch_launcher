<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition على iPhone و iPad.</strong><br>
تم بناء المجتمع iOS و iPadOS شوكة Amethyst، والتي تمت صيانتها بواسطة DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[المميزات](#features) · [لقطات الشاشة](#screenshots) · [المتطلبات](#requirements) · [التثبيت](#installation) · [اللغات](#languages) · [الاعتمادات](#credits) · [الترخيص](#license)

<details>
<summary><strong>اللغات</strong></summary>

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
## حول

**Witch Launcher** عبارة عن شوكة مستقلة يديرها المجتمع لـ [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) والتي تجلب **Minecraft: Java Edition** إلى iPhone و iPad. فهو يجمع بين واجهة مستخدم المشغل التي تعمل باللمس أولاً مع مدير وقت التشغيل الكامل Java، وLWJGL، ومجموعة رسومات مبنية حول Metal، وMoltenVK، وOpenGL طبقات الترجمة.

Witch مبني على عمل [Boardwalk](https://github.com/zhuowei/Boardwalk)، ومجتمع [PojavLauncher](https://github.com/PojavLauncherTeam)، وAmethyst-iOS، وAmethyst-iOS-25. وهو مشروع مستقل وغير تابع لفريق Mojang Studios أو Microsoft أو فريق المنبع Amethyst.

> **الإصدار الحالي:** 0.0.4 · راجع [`news.md`](../../news.md) للاطلاع على ملاحظات الإصدار.

---

<a id="features"></a>
## الميزات

### Minecraft والتعديلات

- يشغل معظم إصدارات **Minecraft: Java Edition**، بدءًا من الإصدارات التجريبية المبكرة وحتى أحدث اللقطات.
- يدعم **الفانيليا، Fabric، Quilt، Forge، NeoForge، و OptiFine**.
- أنشئ **ملفات تعريف للعبة** معزولة باستخدام إعداداتها وتعديلاتها وتظليلاتها وحزم الموارد والعوالم الخاصة بها.
- تصفح المحتوى وتثبيته من **Modrinth وCurseForge** دون مغادرة المشغل:
  - تعديل
  - modpacks
  - حزم التظليل
  - حزم الموارد
  - خرائط المغامرة والعوالم
- حل وتثبيت تبعيات التعديل حيث يوفرها المصدر.
- قم باستيراد Forge/NeoForge ملفات JAR الخاصة بتثبيت Fabric/Quilt مباشرة من منتقي الإصدار.

### الرسومات والأداء

- قم بالتبديل بين العارضين المتعددين من **الإعدادات → العارض والعرض**:
  - **gl4es** — OpenGL مسار التوافق 2.1
  - **ANGLE** — OpenGL ES حتى Metal أو Vulkan
  - **MobileGlues** — OpenGL 4.0، Minecraft 1.17+، تجريبي
  - **Zink** — OpenGL 4.1 حتى Mesa 25 وMoltenVK
  - **LTW** — OpenGL 3.3 إلى OpenGL ES/Metal، Minecraft 1.17+، تجريبي
  - **TGLMT** — OpenGL 4.6 النواة حتى Metal، A11 Bionic أو الأحدث
- **TGLMT مع دعم Sodium وIris** للإعدادات الحديثة القائمة على التظليل.
- **إنشاء الإطارات** باستخدام وحدة معالجة الرسومات المتكيفة مع الحركة (MADI) وأوضاع إعادة عرض الكاميرا ثلاثية الأبعاد، بما في ذلك الاستيفاء الزمني والاستقراء التنبؤي.
- قياس الدقة والحد الأقصى لمعدل الإطارات ورفع المستوى FSR 1.0 وذاكرة التخزين المؤقت لتظليل GLSL والضبط لكل عارض.
- شاشة عرض الأداء مع عناصر واجهة المستخدم FPS ووحدة المعالجة المركزية ووحدة معالجة الرسومات وذاكرة الوصول العشوائي ودرجة الحرارة والبطارية والساعة وإطارات الإطارات القابلة للتكوين.
- تسجيل أداء مدمج مع المخططات، PNG/PDF التصدير والمشاركة.

### الضوابط

- تخطيطات التحكم التي تظهر على الشاشة وأحجام الأزرار والشفافية قابلة للتخصيص بالكامل.
- دعم **لوحة المفاتيح والماوس**، بما في ذلك الماوس الافتراضي وسرعة المؤشر القابلة للتعديل.
- دعم **وحدة التحكم في الألعاب** بتخطيطات وحساسية قابلة للتكوين.
- **الجيروسكوب** يهدف إلى ضبط الحساسية وانعكاس المحور.
- إيماءات الماوس والتمرير وشريط التشغيل السريع.
- السلوك الاختياري: انقر لوضع الكتل، اضغط باستمرار لكسر الكتل.
- انقر نقرًا مزدوجًا على شريط التشغيل لتبديل العنصر المحتفظ به في وضع اليد.
- شريط ساخن قابل للانزلاق وتوقيت ضغطة طويلة قابل للتعديل.

### قاذفة والحسابات

- دعم الحسابات **Microsoft**، و**المحلي/غير المتصل بالإنترنت**، و**التجريبي**، و**Ely.by**.
- يمكنك إدارة أوقات التشغيل **Java 8 و17 و21 و25**، أو تنزيلها داخل التطبيق، أو استيراد أوقات التشغيل الخاصة بك.
- حدد إصدارات LWJGL وقم بضبط وسائط JVM ومتغيرات البيئة وتخصيص الذاكرة.
- إدارة ذاكرة الوصول العشوائي التلقائية للأجهزة ذات الذاكرة المحدودة.
- السمات، وألوان التمييز، والتمويه، والحدود، ونصف قطر الزاوية، وخطوط المشغل المخصصة، وأيقونات التطبيقات.
- **F3 معلومات الجهاز** داخل اللعبة: شريحة الجهاز، إصدار iOS، اسم/إصدار المشغل، رقم الإصدار، ونوع الإصدار.
- عمليات تكامل **Witch اختيارية مع الخادم**، وCurseForge، وAI للإعدادات المتقدمة.
- **52 لغة داخل التطبيق**، بما في ذلك حزم اللغات المكتوبة من اليمين إلى اليسار واللغات المحلية الممتعة.

---

<a id="screenshots"></a>
## لقطات الشاشة

لقطات شاشة من النسخة التطويرية لـ Witch Launcher 0.0.4. يمكن أن تتغير الواجهة بين الإصدارات والموضوعات.

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
## المتطلبات

| المتطلبات | التفاصيل |
|---|---|
| **الجهاز** | iPhone أو iPad بمعالج arm64 ودعم Metal |
| **النظام** | iOS أو iPadOS **14.0 أو أحدث** |
| **JIT** | مطلوب. تمكين JIT من خلال StikDebug، SideStore، TrollStore، أو إعداد كسر الحماية |
| **الحساب** | حساب Microsoft يملك Minecraft للتنزيلات الرسمية؛ تتوفر أيضًا الأوضاع المحلية والتجريبية |
| **التخزين** | مساحة للمشغل، Java أوقات التشغيل، وإصدارات اللعبة، والتعديلات، والعوالم |
| **الشبكة** | مطلوب لتسجيل الدخول وتنزيلات الإصدار ومتصفح المحتوى والخدمات الاختيارية عبر الإنترنت |

Witch **لا** يتضمن Minecraft ملفات اللعبة. يتم تنزيل ملفات اللعبة من خلال المشغل بعد تسجيل الدخول إلى حساب مؤهل.

### JIT ملاحظات

Minecraft: Java Edition يحتاج إلى JIT، و Witch لا يمكن تشغيل اللعبة بدونه.

- **SideStore / AltStore - عمليات التثبيت:** قم بتمكين JIT لـ Witch واحتفظ باتصال VPN/مصحح الأخطاء المطلوب نشطًا. تشير الرسالة داخل التطبيق إلى **LocalDevVPN** و`CS_DEBUGGED`.
- **StikDebug:** قم بإرفاق StikDebug بـ Witch وتمكين JIT. في **iOS 26/27**، يجب أن يظل StikDebug متصلاً أثناء تشغيل اللعبة. `UniversalJIT26.js` يتم نسخه إلى الحافظة عند الحاجة.
- **TrollStore:** قم بتمكين **URL Scheme** في TrollStore إذا استمر Witch في انتظار JIT.
- **أجهزة كسر الحماية:** استخدم أداة التمكين JIT المفضلة لديك.
- إذا ظل المشغل على شاشة **انتظار JIT**، فتحقق من اتصال مصحح الأخطاء، والإعدادات VPN، والإعدادات TrollStore URL Scheme قبل إعادة التشغيل.

يعتمد سلوك JIT على إصدار iOS وطريقة التثبيت. يمكن لتحديثات النظام كسر إعدادات JIT الموجودة.

---

<a id="installation"></a>
## التثبيت

Witch يجب أن يتم توقيعه لجهازك. لا يقوم هذا المستودع بشحن الشهادات أو وكالات ترويج الاستثمار الموقعة مسبقًا.

### استخدم البناء

1. قم بتنزيل نسخة تطوير من [سير عمل التطوير](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)، أو استخدم نسخة موقعة من مصدر تثق به.
2. قم بالتوقيع عليه وتثبيته باستخدام **SideStore**، أو **AltStore**، أو **TrollStore**، أو طريقة التحميل الجانبي المفضلة لديك.
3. قم بتمكين JIT كما هو موضح أعلاه قبل تشغيل اللعبة.

TrollStore تستخدم الإصدارات استحقاقات إضافية ولا يجب تثبيتها باستخدام مُوقع التحميل الجانبي العادي.

### البناء من المصدر

يتطلب تجميع Witch macOS باستخدام أدوات سطر الأوامر Xcode، وiOS SDK 14.0 أو أحدث، CMake، JDK 8، `ldid`، `wget`، `zip`، وGit.

```bash
git clone - العودي https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

تتم كتابة الإصدارات المجمعة إلى `artifacts/`.

لإنشاء حزمة TrollStore بدلاً من ذلك:

```bash
make package TROLLSTORE_JIT_ENT=1
```

للحصول على روابط مصدر العارض وملاحظات البناء، راجع [`note.md`](../../note.md).

---

<a id="languages"></a>
## اللغات

Witch Launcher يأتي مع **52 حزمة لغة**. افتح **الإعدادات → عام → اللغة** وحدد لغة، أو استخدم **تلقائيًا** لمتابعة لغة الجهاز.

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

يشحن التطبيق كافة **حزمة اللغات الـ52**. تتوفر ترجمات README **لجميع اللغات الـ 52**، بما في ذلك اللغة الإنجليزية.

تتم بعض الترجمات بمساعدة الآلة وقد تحتوي على مصطلحات تقنية غريبة. التصحيحات هي موضع ترحيب.

اللغة الإنجليزية هي اللغة المصدر لهذا الملف README. تتوفر ملفات README المترجمة من محدد اللغة الموجود أعلى هذه الصفحة وفي الدليل [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## الملاحظات والقيود

- **JIT إلزامي.** بدون إعداد JIT فعال، لن يتم تشغيل Minecraft.
- **iOS 26/27 JIT هش.** StikDebug يجب أن يظل مرفقًا، وقد تؤدي تحديثات نظام التشغيل المستقبلية إلى تغيير ما يعمل.
- يمكن أن تتعطل برامج العرض التي تم وضع علامة **تجريبية** عليها أو يتم عرضها بشكل غير صحيح. ابدأ بـ **تلقائي** إذا لم تكن متأكدًا.
- **إنشاء الإطار** يتطلب العارض MoltenVK ودعم الحساب Metal. يمكن أن يزيد من استخدام البطارية ودرجة حرارة الجهاز.
- قد تتطلب بعض التعديلات وحزم التعديل والتظليل والعوالم إصدارًا Minecraft محددًا أو مُحملًا أو عارضًا أو ذاكرة إضافية.
- CurseForge تستخدم حزم التعديل `manifest.json`؛ إذا لم يكن التثبيت بنقرة واحدة متاحًا للحزمة، فاستورد الأرشيف يدويًا.
- تعتمد الميزات المتوفرة عبر الإنترنت على خدمات الجهات الخارجية وقد لا تكون متاحة.
- لقطات الشاشة مأخوذة من نسخة تطوير وقد لا تتطابق تمامًا مع الإصدار الحالي.

---

<a id="project-lineage"></a>
## نسب المشروع

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

### المشاريع ذات الصلة

- [Amethyst أندرويد](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## المساهمة

نرحب بتقارير الأخطاء والعلاقات العامة. عند الإبلاغ عن مشكلة، قم بتضمين ما يلي:

- طراز الجهاز وإصدار iOS/iPadOS
- Witch Launcher نسخة
- العارض و Minecraft الإصدار
- محمل التعديل وقائمة التعديلات المثبتة
- خطوات التكاثر
- السجل ذي الصلة أو تقرير الأعطال

يرجى عدم الالتزام بتوقيع الشهادات أو توفير الملفات الشخصية أو API المفاتيح أو الأسرار الأخرى.

---

<a id="credits"></a>
## الاعتمادات

**Witch Launcher** تتم صيانته بواسطة **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### المنبع والمجتمع

Witch Launcher ومشاريعها الأولية مبنية على عمل العديد من المساهمين، منهم:

- **@crystall1nedev** — Amethyst مدير المشروع وiOS مطور المنفذ
- **@khanhduytran0** — iOS مطور المنفذ
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

شكرًا إضافيًا لـ **@lunixbochs**، و**@ptitSeb**، و**@kakashidinho**، ومشروع ANGLE، ومجموعة Khronos، وMesa مشروع، وPojavLauncher فريق، وMozilla، ومجتمع Minecraft.

شكر خاص لـ [MCHeads](https://mc-heads.net) على توفير Minecraft خدمات الصور الرمزية.

تتوفر قائمة تراخيص ومكونات الطرف الثالث الكاملة في [`credits.md`](../../credits.md).

---

<a id="license"></a>
## الترخيص

يتم توزيع Witch Launcher بموجب **GNU General Public License v3.0**، مع مراعاة التراخيص ومتطلبات حقوق الطبع والنشر لمكونات الطرف الثالث المدرجة في [`credits.md`](../../credits.md).

راجع [`LICENSE`](../../LICENSE) للحصول على نص الترخيص الكامل.

---

<p align="center">
<sub>Minecraft هي علامة تجارية لشركة Mojang Studios. Witch Launcher لا يتبع Mojang Studios، Microsoft، أو مشروع Amethyst.</sub>
</p>
