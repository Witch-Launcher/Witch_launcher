<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition ב-iPhone ו-iPad.</strong><br>
מזלג iOS ו-iPadOS שנבנה בקהילה של Amethyst, מתוחזק על ידי DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[תכונות](#features) · [צילומי מסך](#screenshots) · [דרישות](#requirements) · [התקנה](#installation) · [שפות](#languages) · [קרדיטים](#credits) · [רישיון](#license)

<details>
<summary><strong>שפות</strong></summary>

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
## אוֹדוֹת

**Witch Launcher** הוא מזלג עצמאי, המתוחזק על ידי קהילה, של [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) שמביא את **Minecraft: Java Edition** אל iPhone ו-iPad. הוא משלב ממשק משתמש משגר עם מגע ראשון עם מנהל זמן ריצה מלא Java, LWJGL, וערימה גרפית הבנויה סביב שכבות תרגום Metal, MoltenVK ו-OpenGL.

Witch בנוי על עבודתם של [Boardwalk](https://github.com/zhuowei/Boardwalk), הקהילה [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS, ו-Amethyst-iOS-25. זהו פרויקט עצמאי ואינו מזוהה עם Mojang Studios, Microsoft, או צוות ה-upstream Amethyst.

> **גרסה נוכחית:** 0.0.4 · ראה [`news.md`](../../news.md) עבור הערות מהדורה.

---

<a id="features"></a>
## תכונות

### Minecraft ומודים

- מריץ את רוב הגרסאות **Minecraft: Java Edition**, החל מגירסאות בטא מוקדמות ועד לתצלומים האחרונים.
- תומך ב**Vanilla, Fabric, Quilt, Forge, NeoForge, ו-OptiFine**.
- צור **פרופילי משחק** מבודדים עם הגדרות משלהם, אופנים, הצללות, חבילות משאבים ועולמות משלהם.
- דפדוף והתקן תוכן מ-**Modrinth ו-CurseForge** מבלי לצאת מהמפעיל:
  - אופנים
  - modpacks
  - חבילות shader
  - חבילות משאבים
  - מפות הרפתקאות ועולמות
- פתור והתקן תלות במוד היכן שהמקור מספק אותן.
- ייבא Forge/NeoForge מתקין JAR והתקן Fabric/Quilt מעמיסים ישירות מבוחר הגרסאות.

### גרפיקה וביצועים

- מעבר בין מעבדים מרובים מ**הגדרות → מעבד ותצוגה**:
  - **gl4es** — OpenGL נתיב תאימות 2.1
  - **ANGLE** - OpenGL ES עד Metal או Vulkan
  - **MobileGlues** - OpenGL 4.0, Minecraft 1.17+, ניסיוני
  - **Zink** - OpenGL 4.1 עד Mesa 25 ו-MoltenVK
  - **LTW** — OpenGL 3.3 עד OpenGL ES/Metal, Minecraft 1.17+, ניסיוני
  - **TGLMT** — OpenGL 4.6 Core עד Metal, A11 Bionic או חדש יותר
- **TGLMT עם תמיכה ב-Sodium ו-Iris** עבור הגדרות מודרניות מבוססות הצללה.
- **יצירת מסגרות** עם Motion-Adaptive GPU (MADI) ומצבי ההקרנה מחדש של מצלמה תלת-ממדית, כולל אינטרפולציה זמנית וחיזוי חזוי.
- קנה מידה של רזולוציה, קצב מסגרות מקסימלי, FSR 1.0 העלאת קנה מידה, מטמוני הצללה של GLSL וכוונון לכל מעבד.
- HUD ביצועים עם FPS, CPU, GPU, RAM, טמפרטורה, סוללה, שעון וווידג'טים של FPS של דור המסגרת.
- הקלטת ביצועים מובנית עם תרשימים, PNG/PDF ייצוא ושיתוף.

### בקרות

- פריסות שליטה על המסך, גדלי לחצנים ושקיפות הניתנות להתאמה אישית מלאה.
- תמיכה ב**מקלדת ועכבר**, כולל עכבר וירטואלי ומהירות מצביע מתכווננת.
- תמיכה ב**בקר משחק** עם פריסות ורגישות הניתנות להגדרה.
- **ג'ירוסקופ** מכוון עם רגישות מתכווננת והיפוך ציר.
- מחוות עכבר, גלילה וסרגל חם.
- התנהגות אופציונלית: הקש כדי למקם בלוקים, החזק כדי לשבור בלוקים.
- הקש פעמיים על הסרגל החם כדי להחליף את הפריט המוחזק ל-off-hand.
- בר חם הניתן להזזה ותזמון לחיצה ארוכה מתכווננת.

### משגר וחשבונות

- תמיכה בחשבון **Microsoft**, **מקומי/לא מקוון**, **הדגמה** ו**Ely.by**.
- נהל זמני ריצה של **Java 8, 17, 21 ו-25**, הורד אותם בתוך האפליקציה או ייבא משלך.
- בחר LWJGL גרסאות וכוונן ארגומנטים של JVM, משתני סביבה והקצאת זיכרון.
- ניהול RAM אוטומטי עבור מכשירים עם זיכרון מוגבל.
- ערכות נושא, צבעי הדגשה, טשטוש, גבולות, רדיוס פינות, גופני משגר מותאמים אישית וסמלי אפליקציה.
- מידע על מכשיר **F3 במשחק**: שבב מכשיר, גרסת iOS, שם/גרסה של משגר, מספר בנייה וסוג בנייה.
- אינטגרציות אופציונליות של **Witch שרת**, CurseForge, ו-AI עבור הגדרות מתקדמות.
- **52 שפות בתוך האפליקציה**, כולל חבילות שפה מימין לשמאל ומקומונים מהנים.

---

<a id="screenshots"></a>
## צילומי מסך

צילומי מסך ממבנה פיתוח של Witch Launcher 0.0.4. הממשק יכול לשנות בין גרסאות וערכות נושא.

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
## דרישות

| דרישה | פרטים |
|---|---|
| **מכשיר** | iPhone או iPad עם מעבד arm64 ותמיכה Metal |
| **מערכת** | iOS או iPadOS **14.0 ומעלה** |
| **JIT** | דָרוּשׁ. הפעל את JIT עד StikDebug, SideStore, TrollStore, או הגדרה שבורה בכלא |
| **חשבון** | חשבון Microsoft בעל Minecraft להורדות רשמיות; מצבים מקומיים ומצבי הדגמה זמינים גם |
| **אחסון** | מקום למשגר, Java זמני ריצה, גרסאות משחק, אופנים ועולמות |
| **רשת** | נדרש עבור כניסה, הורדות גרסאות, דפדפן התוכן ושירותים מקוונים אופציונליים |

Witch **לא** כולל Minecraft קובצי משחק. קובצי המשחק יורדים דרך המשגר ​​לאחר כניסה לחשבון כשיר.

### JIT הערות

Minecraft: Java Edition צריך JIT, ו-Witch לא יכול להפעיל את המשחק בלעדיו.

- התקנות בסגנון **SideStore / AltStore:** הפעל את JIT עבור Witch והשאר את החיבור הנדרש VPN/מאתר הבאגים פעיל. ההודעה בתוך האפליקציה מתייחסת ל-**LocalDevVPN** ו-`CS_DEBUGGED`.
- **StikDebug:** צרף StikDebug ל-Witch והפעל את JIT. ב-**iOS 26/27**, StikDebug חייב להישאר מחובר בזמן שהמשחק פועל. `UniversalJIT26.js` מועתק ללוח בעת הצורך.
- **TrollStore:** הפעל את **URL Scheme** ב-TrollStore אם Witch ממשיך לחכות ל-JIT.
- **מכשירי Jailbroken:** השתמש במאפשר ה-JIT המועדף עליך.
- אם המשגר נשאר במסך **מחכה ל-JIT**, בדוק את חיבור באגים, את ה-VPN ואת ההגדרה TrollStore URL Scheme לפני הפעלה מחדש.

התנהגות JIT תלויה בגרסה iOS ובשיטת ההתקנה. עדכוני מערכת יכולים לשבור הגדרות קיימות של JIT.

---

<a id="installation"></a>
## התקנה

Witch חייב להיות חתום עבור המכשיר שלך. מאגר זה אינו שולח אישורים או IPA חתומים מראש.

### השתמש במבנה

1. הורד בניית פיתוח מ[זרימת העבודה של הפיתוח](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), או השתמש ב-build חתום ממקור שאתה סומך עליו.
2. חתום והתקן אותו באמצעות **SideStore**, **AltStore**, **TrollStore**, או שיטת העמסת הצד המועדפת עליך.
3. הפעל את JIT כמתואר לעיל לפני הפעלת המשחק.

TrollStore בונים משתמשים בהרשאות נוספות ואין להתקין אותם עם חותם רגיל של טעינת צד.

### בנה ממקור

קומפילציה של Witch דורשת macOS עם Xcode כלי שורת פקודה, iOS SDK 14.0 ומעלה, CMake, JDK 8, `ldid`, `wget`, `zip`, ו-Git.

```bash
git clone --רקורסיבי https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

בנייה ארוזה נכתבת אל `artifacts/`.

כדי לבנות חבילה TrollStore במקום זאת:

```bash
make package TROLLSTORE_JIT_ENT=1
```

לקישורי מקור ממעבדים והערות בנייה, ראה [`note.md`](../../note.md).

---

<a id="languages"></a>
## שפות

Witch Launcher נשלח עם **52 חבילות שפה**. פתח את **הגדרות → כללי → שפה** ובחר שפה, או השתמש ב-**אוטומטי** כדי לעקוב אחר שפת המכשיר.

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

האפליקציה שולחת את כל **52 חבילות השפה**. תרגומי README זמינים עבור **כל 52 השפות**, כולל אנגלית.

חלק מהתרגומים הם בסיוע מכונה ועשויים להכיל מונחים טכניים מביכים. תיקונים יתקבלו בברכה.

אנגלית היא שפת המקור עבור README זה. READMEs מקומיים זמינים מבורר השפה בחלק העליון של דף זה ובספרייה [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## הערות ומגבלות

- **JIT הוא חובה.** ללא הגדרה תקינה של JIT, Minecraft לא יופעל.
- **iOS 26/27 JIT שביר.** StikDebug חייב להישאר מחובר, ועדכוני מערכת הפעלה עתידיים עשויים לשנות את מה שעובד.
- מעבדים המסומנים כ**ניסיוניים** יכולים לקרוס או לעבד בצורה שגויה. התחל עם **אוטומטי** אם אינך בטוח.
- **יצירת מסגרות** דורשת את המעבד MoltenVK ואת תמיכת המחשוב Metal. זה יכול להגביר את השימוש בסוללה ואת טמפרטורת המכשיר.
- מודדים מסוימים, חבילות מודפס, shaders ועולמות עשויים לדרוש גרסה ספציפית Minecraft, מטעין, renderer או זיכרון נוסף.
- CurseForge חבילות modpack משתמשות ב-`manifest.json`; אם התקנה בלחיצה אחת אינה זמינה עבור חבילה, ייבא את הארכיון באופן ידני.
- תכונות מקוונות תלויות בשירותי צד שלישי וייתכן שלא יהיו זמינות.
- צילומי מסך הם מפיתוח וייתכן שלא תואמים בדיוק למהדורה הנוכחית.

---

<a id="project-lineage"></a>
## שושלת פרויקט

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

### פרויקטים קשורים

- [Amethyst אנדרואיד](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## תורם

דיווחי באגים ויחסי ציבור יתקבלו בברכה. בעת דיווח על בעיה, כלול:

- דגם המכשיר וגרסת iOS/iPadOS
- Witch Launcher גרסה
- מעבד וגרסה Minecraft
- מטעין מוד ורשימת מודדים מותקנים
- שלבים להתרבות
- היומן הרלוונטי או דוח הקריסה

נא לא לבצע אישורי חתימה, פרופילי אספקה, מפתחות API או סודות אחרים.

---

<a id="credits"></a>
## קרדיטים

**Witch Launcher** מתוחזק על ידי **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### במעלה הזרם ובקהילה

Witch Launcher והפרויקטים במעלה הזרם שלו בנויים על עבודתם של תורמים רבים, כולל:

- **@crystall1nedev** - מנהל פרויקטים Amethyst ומפתח יציאות iOS
- **@khanhduytran0** - מפתח יציאות iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

תודות נוספות ל**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, פרויקט ANGLE, קבוצת Khronos, פרויקט Mesa, צוות PojavLauncher, מוזילה וקהילה Minecraft.

תודה מיוחדת ל-[MCHeads](https://mc-heads.net) על מתן שירותי אווטאר Minecraft.

רשימת הרכיבים והרישיונות המלאים של צד שלישי זמינים ב-[`credits.md`](../../credits.md).

---

<a id="license"></a>
## רישיון

Witch Launcher מופץ תחת **GNU General Public License v3.0**, בכפוף לרשיונות ולדרישות זכויות היוצרים של רכיבי הצד השלישי המפורטים ב-[`credits.md`](../../credits.md).

ראה [`LICENSE`](../../LICENSE) לטקסט הרישיון המלא.

---

<p align="center">
<sub>Minecraft הוא סימן מסחרי של Mojang Studios. Witch Launcher אינו מזוהה עם Mojang Studios, Microsoft, או לפרויקט Amethyst.</sub>
</p>
