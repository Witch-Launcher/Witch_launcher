<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone এবং iPad.</strong><br>
একটি সম্প্রদায়-নির্মিত iOS এবং Amethyst-এর iPadOS কাঁটা, DuyAnh662 (Za_d626) দ্বারা রক্ষণাবেক্ষণ করা হয়।
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[বৈশিষ্ট্য](#features) · [স্ক্রিনশট](#screenshots) · [প্রয়োজনীয়তা](#requirements) · [ইন্সটলেশন](#installation) · [ভাষা](#languages) · [ক্রেডিট](#credits) · [লাইসেন্স](#license)

<details>
<summary><strong>ভাষা</strong></summary>

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
## সম্পর্কে

**Witch Launcher** হল [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) এর একটি স্বাধীন, সম্প্রদায়-পরিচালিত কাঁটা যা **Minecraft: Java Edition** কে iPhone এবং iPad নিয়ে আসে। এটি একটি সম্পূর্ণ Java রানটাইম ম্যানেজার, LWJGL এবং Metal, MoltenVK এবং OpenGL অনুবাদ স্তরের চারপাশে নির্মিত একটি গ্রাফিক্স স্ট্যাকের সাথে একটি স্পর্শ-প্রথম লঞ্চার UI-কে একত্রিত করে।

Witch [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) সম্প্রদায়, Amethyst-iOS এবং Amethyst-iOS-25-এর কাজের উপর নির্মিত। এটি একটি স্বাধীন প্রকল্প এবং এটি Mojang Studios, Microsoft, বা আপস্ট্রিম Amethyst দলের সাথে সংযুক্ত নয়।

> **বর্তমান সংস্করণ:** 0.0.4 · রিলিজ নোটের জন্য [`news.md`](../../news.md) দেখুন।

---

<a id="features"></a>
## বৈশিষ্ট্য

### Minecraft এবং মোড

- প্রারম্ভিক বিটা রিলিজ থেকে সাম্প্রতিক স্ন্যাপশটের মাধ্যমে বেশিরভাগ **Minecraft: Java Edition** সংস্করণ চালায়।
- **ভ্যানিলা, Fabric, Quilt, Forge, NeoForge এবং OptiFine** সমর্থন করে।
- তাদের নিজস্ব সেটিংস, মোড, শেডার, রিসোর্স প্যাক এবং ওয়ার্ল্ডের সাথে বিচ্ছিন্ন **গেম প্রোফাইল** তৈরি করুন।
- লঞ্চার ছাড়াই **Modrinth এবং CurseForge** থেকে সামগ্রী ব্রাউজ এবং ইনস্টল করুন:
  - মোড
  - modpacks
  - shader প্যাক
  - সম্পদ প্যাক
  - অ্যাডভেঞ্চার মানচিত্র এবং বিশ্বের
- মোড নির্ভরতাগুলি সমাধান করুন এবং ইনস্টল করুন যেখানে উত্স তাদের সরবরাহ করে।
- Forge/NeoForge ইনস্টলার JAR আমদানি করুন এবং সংস্করণ পিকার থেকে সরাসরি Fabric/Quilt লোডার ইনস্টল করুন।

### গ্রাফিক্স এবং কর্মক্ষমতা

- **সেটিংস → রেন্ডারার এবং ডিসপ্লে** থেকে একাধিক রেন্ডারারের মধ্যে স্যুইচ করুন:
  - **gl4es** — OpenGL 2.1 সামঞ্জস্যের পথ
  - **ANGLE** — OpenGL ES থেকে Metal বা Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, পরীক্ষামূলক
  - **Zink** — OpenGL 4.1 থেকে Mesa 25 এবং MoltenVK
  - **LTW** — OpenGL 3.3 থেকে OpenGL ES/Metal, Minecraft 1.17+, পরীক্ষামূলক
  - **TGLMT** — OpenGL 4.6 কোর থেকে Metal, A11 Bionic বা নতুন
- আধুনিক শেডার-ভিত্তিক সেটআপের জন্য **TGLMT Sodium এবং Iris সমর্থনের সাথে**।
- মোশন-অ্যাডাপ্টিভ GPU (MADI) এবং টেম্পোরাল ইন্টারপোলেশন এবং ভবিষ্যদ্বাণীমূলক এক্সট্রাপোলেশন সহ ক্যামেরা 3D রিপ্রজেক্ট মোড সহ **ফ্রেম জেনারেশন**।
- রেজোলিউশন স্কেলিং, সর্বোচ্চ ফ্রেমরেট, FSR 1.0 আপস্কেলিং, GLSL শেডার ক্যাশে এবং প্রতি-রেন্ডারার টিউনিং।
- কনফিগারযোগ্য FPS, CPU, GPU, RAM, তাপমাত্রা, ব্যাটারি, ঘড়ি এবং ফ্রেম-জেনারেশন FPS উইজেট সহ পারফরম্যান্স HUD।
- চার্ট, PNG/PDF রপ্তানি, এবং ভাগ করে নেওয়ার সাথে অন্তর্নির্মিত কর্মক্ষমতা রেকর্ডিং।

### নিয়ন্ত্রণ করে

- সম্পূর্ণরূপে কাস্টমাইজযোগ্য অন-স্ক্রীন নিয়ন্ত্রণ বিন্যাস, বোতামের আকার এবং স্বচ্ছতা।
- ভার্চুয়াল মাউস এবং সামঞ্জস্যযোগ্য পয়েন্টার গতি সহ **কীবোর্ড এবং মাউস** সমর্থন।
- কনফিগারযোগ্য লেআউট এবং সংবেদনশীলতার সাথে **গেম কন্ট্রোলার** সমর্থন।
- **জাইরোস্কোপ** সামঞ্জস্যযোগ্য সংবেদনশীলতা এবং অক্ষ বিপর্যয় সহ লক্ষ্য।
- মাউস, স্ক্রোল এবং হটবার অঙ্গভঙ্গি।
- ঐচ্ছিক আচরণ: ব্লক বসাতে আলতো চাপুন, ব্লক ভাঙতে ধরে রাখুন।
- রাখা আইটেমটিকে অফ-হ্যান্ডে অদলবদল করতে হটবারে ডবল-ট্যাপ করুন৷
- স্লাইডযোগ্য হটবার এবং সামঞ্জস্যযোগ্য দীর্ঘ-প্রেস টাইমিং।

### লঞ্চার এবং অ্যাকাউন্ট

- **Microsoft**, **স্থানীয়/অফলাইন**, **ডেমো**, এবং **Ely.by** অ্যাকাউন্ট সমর্থন।
- **Java 8, 17, 21, এবং 25** রানটাইমগুলি পরিচালনা করুন, সেগুলিকে অ্যাপ-মধ্যস্থ ডাউনলোড করুন বা আপনার নিজস্ব আমদানি করুন৷
- LWJGL সংস্করণ নির্বাচন করুন এবং JVM আর্গুমেন্ট, পরিবেশ ভেরিয়েবল এবং মেমরি বরাদ্দ টিউন করুন।
- সীমিত মেমরি সহ ডিভাইসগুলির জন্য স্বয়ংক্রিয় RAM ব্যবস্থাপনা।
- থিম, অ্যাকসেন্ট রং, অস্পষ্টতা, সীমানা, কোণার ব্যাসার্ধ, কাস্টম লঞ্চার ফন্ট এবং অ্যাপ আইকন।
- ইন-গেম **F3 ডিভাইসের তথ্য**: ডিভাইস চিপ, iOS সংস্করণ, লঞ্চারের নাম/সংস্করণ, বিল্ড নম্বর এবং বিল্ড টাইপ।
- উন্নত সেটআপের জন্য ঐচ্ছিক **Witch সার্ভার**, CurseForge এবং AI ইন্টিগ্রেশন।
- **অ্যাপ-মধ্যস্থ 52টি ভাষা**, ডান-থেকে-বাম ভাষা প্যাক এবং মজার লোকেল সহ।

---

<a id="screenshots"></a>
## স্ক্রিনশট

Witch Launcher 0.0.4 এর একটি বিকাশ বিল্ড থেকে স্ক্রিনশট। ইন্টারফেস সংস্করণ এবং থিম মধ্যে পরিবর্তন করতে পারেন.

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
## প্রয়োজনীয়তা

| প্রয়োজনীয়তা | বিস্তারিত |
|---|---|
| **ডিভাইস** | iPhone বা iPad একটি arm64 প্রসেসর এবং Metal সমর্থন সহ |
| **সিস্টেম** | iOS বা iPadOS **14.0 বা নতুন** |
| **JIT** | প্রয়োজন। StikDebug, SideStore, TrollStore, বা একটি জেলব্রোকেন সেটআপের মাধ্যমে JIT সক্ষম করুন |
| **অ্যাকাউন্ট** | একটি Microsoft অ্যাকাউন্ট যা অফিসিয়াল ডাউনলোডের জন্য Minecraft এর মালিক; স্থানীয় এবং ডেমো মোড উপলব্ধ |
| **সঞ্চয়স্থান** | লঞ্চারের জন্য স্থান, Java রানটাইম, গেমের সংস্করণ, মোড এবং বিশ্বের |
| **Network** | Required for sign-in, version downloads, the content browser, and optional online services |

Witch Minecraft গেম ফাইল অন্তর্ভুক্ত **না** করে। একটি যোগ্য অ্যাকাউন্টে সাইন ইন করার পরে লঞ্চারের মাধ্যমে গেম ফাইলগুলি ডাউনলোড করা হয়।

### JIT নোট

Minecraft: Java Edition এর JIT প্রয়োজন এবং Witch এটি ছাড়া গেমটি চালু করতে পারে না।

- **SideStore / AltStore-শৈলী ইনস্টল:** Witch এর জন্য JIT সক্ষম করুন এবং প্রয়োজনীয় VPN/ডিবাগার সংযোগ সক্রিয় রাখুন। অ্যাপ-মধ্যস্থ বার্তাটি **LocalDevVPN** এবং `CS_DEBUGGED`কে বোঝায়।
- **StikDebug:** Witch-এর সাথে StikDebug সংযুক্ত করুন এবং JIT সক্ষম করুন। **iOS 26/27**-এ, গেমটি চলাকালীন StikDebug অবশ্যই সংযুক্ত থাকতে হবে। `UniversalJIT26.js` প্রয়োজন হলে ক্লিপবোর্ডে কপি করা হয়।
- **TrollStore:** TrollStore-এ **URL Scheme** সক্ষম করুন যদি Witch JIT-এর জন্য অপেক্ষা করে থাকে।
- **জেলব্রোকেন ডিভাইস:** আপনার পছন্দের JIT সক্ষমকারী ব্যবহার করুন।
- যদি লঞ্চারটি **JIT এর জন্য অপেক্ষা করা** স্ক্রিনে থাকে, তাহলে পুনরায় লঞ্চ করার আগে ডিবাগার সংযোগ, VPN এবং TrollStore URL Scheme সেটিং পরীক্ষা করুন।

JIT আচরণ iOS সংস্করণ এবং ইনস্টলেশন পদ্ধতির উপর নির্ভর করে। সিস্টেম আপডেট বিদ্যমান JIT সেটআপ ভাঙতে পারে।

---

<a id="installation"></a>
## ইনস্টলেশন

Witch আপনার ডিভাইসের জন্য স্বাক্ষরিত হতে হবে। এই সংগ্রহস্থল সার্টিফিকেট বা পূর্ব-স্বাক্ষরিত IPA গুলি পাঠায় না।

### একটি বিল্ড ব্যবহার করুন

1. [ডেভেলপমেন্ট ওয়ার্কফ্লো](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) থেকে একটি ডেভেলপমেন্ট বিল্ড ডাউনলোড করুন, অথবা আপনার বিশ্বাসযোগ্য উৎস থেকে একটি স্বাক্ষরিত বিল্ড ব্যবহার করুন।
2. সাইন ইন করুন এবং **SideStore**, **AltStore**, **TrollStore**, অথবা আপনার পছন্দের সাইডলোডিং পদ্ধতি দিয়ে ইনস্টল করুন।
3. গেম চালু করার আগে উপরে বর্ণিত JIT সক্ষম করুন।

TrollStore বিল্ডগুলি অতিরিক্ত এনটাইটেলমেন্ট ব্যবহার করে এবং একটি সাধারণ সাইডলোডিং স্বাক্ষরকারীর সাথে ইনস্টল করা উচিত নয়।

### উৎস থেকে তৈরি করুন

Witch কম্পাইল করার জন্য Xcode কমান্ড-লাইন টুল সহ macOS প্রয়োজন, একটি iOS SDK 14.0 বা নতুন, CMake, JDK 8, `ldid`, `wget`, `zip` এবং Git।

```bash
গিট ক্লোন --পুনরাবৃত্ত https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

প্যাকেজ করা বিল্ড `artifacts/` লেখা হয়।

পরিবর্তে একটি TrollStore প্যাকেজ তৈরি করতে:

```bash
make package TROLLSTORE_JIT_ENT=1
```

রেন্ডারার সোর্স লিঙ্ক এবং বিল্ড নোটের জন্য, [`note.md`](../../note.md) দেখুন।

---

<a id="languages"></a>
## ভাষা

Witch Launcher **52 ভাষা প্যাক** সহ জাহাজ। **সেটিংস → সাধারণ → ভাষা** খুলুন এবং একটি ভাষা নির্বাচন করুন, অথবা ডিভাইসের ভাষা অনুসরণ করতে **অটো** ব্যবহার করুন।

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

অ্যাপটি সমস্ত **52 ভাষা প্যাক** পাঠায়। README অনুবাদগুলি ইংরেজি সহ **সমস্ত 52টি ভাষায়** উপলব্ধ।

কিছু অনুবাদ মেশিন-সহায়তা এবং বিশ্রী প্রযুক্তিগত পদ থাকতে পারে। সংশোধন স্বাগত জানাই.

ইংরেজি এই README-এর উৎস ভাষা। স্থানীয়কৃত README গুলি এই পৃষ্ঠার উপরের ভাষা নির্বাচক থেকে এবং [`docs/readme/`](./) ডিরেক্টরিতে পাওয়া যায়।

---

<a id="notes-and-limitations"></a>
## নোট এবং সীমাবদ্ধতা

- **JIT বাধ্যতামূলক।** একটি কার্যকরী JIT সেটআপ ছাড়া, Minecraft চালু হবে না।
- **iOS 26/27 JIT ভঙ্গুর।** StikDebug অবশ্যই সংযুক্ত থাকতে হবে এবং ভবিষ্যতের OS আপডেটগুলি যা কাজ করে তা পরিবর্তন করতে পারে।
- **পরীক্ষামূলক** চিহ্নিত রেন্ডারাররা ক্র্যাশ বা ভুলভাবে রেন্ডার করতে পারে। আপনি যদি নিশ্চিত না হন তাহলে **অটো** দিয়ে শুরু করুন।
- **ফ্রেম জেনারেশন** এর জন্য MoltenVK রেন্ডারার এবং Metal গণনা সমর্থন প্রয়োজন। এটি ব্যাটারি ব্যবহার এবং ডিভাইসের তাপমাত্রা বাড়াতে পারে।
- কিছু মোড, মডপ্যাক, শেডার এবং ওয়ার্ল্ডের জন্য একটি নির্দিষ্ট Minecraft সংস্করণ, লোডার, রেন্ডারার বা অতিরিক্ত মেমরির প্রয়োজন হতে পারে।
- CurseForge modpacks `manifest.json` ব্যবহার করে; যদি একটি প্যাকের জন্য এক-ট্যাপ ইনস্টলেশন উপলব্ধ না হয়, আর্কাইভটি ম্যানুয়ালি আমদানি করুন৷
- অনলাইন বৈশিষ্ট্যগুলি তৃতীয় পক্ষের পরিষেবাগুলির উপর নির্ভর করে এবং অনুপলব্ধ হতে পারে৷
- স্ক্রিনশটগুলি একটি ডেভেলপমেন্ট বিল্ড থেকে এসেছে এবং বর্তমান রিলিজের সাথে ঠিক মেলে নাও হতে পারে।

---

<a id="project-lineage"></a>
## প্রকল্পের বংশ

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

### সম্পর্কিত প্রকল্প

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## অবদান

বাগ রিপোর্ট এবং PR স্বাগত জানাই. একটি সমস্যা রিপোর্ট করার সময়, অন্তর্ভুক্ত করুন:

- ডিভাইস মডেল এবং iOS/iPadOS সংস্করণ
- Witch Launcher সংস্করণ
- রেন্ডারার এবং Minecraft সংস্করণ
- মোড লোডার এবং ইনস্টল করা মোডগুলির একটি তালিকা
- পুনরুত্পাদন করার জন্য পদক্ষেপ
- প্রাসঙ্গিক লগ বা ক্র্যাশ রিপোর্ট

অনুগ্রহ করে সাইনিং সার্টিফিকেট, প্রোভিশনিং প্রোফাইল, API কী, বা অন্যান্য গোপনীয়তার প্রতিশ্রুতি দেবেন না।

---

<a id="credits"></a>
## ক্রেডিট

**Witch Launcher** **DuyAnh662 (Za_d626)** দ্বারা রক্ষণাবেক্ষণ করা হয়।

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### আপস্ট্রিম এবং সম্প্রদায়

Witch Launcher এবং এর আপস্ট্রিম প্রকল্পগুলি অনেক অবদানকারীদের কাজের উপর নির্মিত, যার মধ্যে রয়েছে:

- **@crystall1nedev** — Amethyst প্রজেক্ট ম্যানেজার এবং iOS পোর্ট ডেভেলপার
- **@khanhduytran0** — iOS পোর্ট ডেভেলপার
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE প্রকল্প, Khronos Group, Mesa প্রকল্প, PojavLauncher টিম, Mozilla এবং Minecraft সম্প্রদায়কে অতিরিক্ত ধন্যবাদ।

Minecraft অবতার পরিষেবা প্রদানের জন্য [MCHeads](https://mc-heads.net) কে বিশেষ ধন্যবাদ।

সম্পূর্ণ তৃতীয় পক্ষের উপাদান এবং লাইসেন্স তালিকা [`credits.md`](../../credits.md) এ উপলব্ধ।

---

<a id="license"></a>
## লাইসেন্স

Witch Launcher **GNU জেনারেল পাবলিক লাইসেন্স v3.0**-এর অধীনে বিতরণ করা হয়, [`credits.md`](../../credits.md) তালিকাভুক্ত তৃতীয় পক্ষের উপাদানগুলির লাইসেন্স এবং কপিরাইট প্রয়োজনীয়তা সাপেক্ষে।

সম্পূর্ণ লাইসেন্স পাঠ্যের জন্য [`LICENSE`](../../LICENSE) দেখুন।

---

<p align="center">
<sub>Minecraft হল Mojang Studios-এর একটি ট্রেডমার্ক। Witch Launcher Mojang Studios, Microsoft, বা Amethyst প্রকল্পের সাথে অনুমোদিত নয়। </sub>
</p>
