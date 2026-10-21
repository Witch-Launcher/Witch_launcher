<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition पर iPhone और iPad।</strong><br>
एक समुदाय-निर्मित iOS और iPadOS कांटा Amethyst, जिसका रखरखाव DuyAnh662 (Za_d626) द्वारा किया जाता है।
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[विशेषताएं](#features) · [स्क्रीनशॉट](#screenshots) · [आवश्यकताएं](#requirements) · [इंस्टॉलेशन](#installation) · [भाषाएं](#languages) · [क्रेडिट](#credits) · [लाइसेंस](#license)

<details>
<summary><strong>बोली</strong></summary>

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
## के बारे में

**Witch Launcher** एक स्वतंत्र, समुदाय-संचालित कांटा है [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) जो **Minecraft: Java Edition** को iPhone और iPad पर लाता है। यह एक पूर्ण Java रनटाइम मैनेजर, LWJGL, और Metal, MoltenVK, और OpenGL अनुवाद परतों के आसपास निर्मित ग्राफिक्स स्टैक के साथ एक टच-फर्स्ट लॉन्चर यूआई को जोड़ता है।

Witch [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) समुदाय, Amethyst-iOS, और Amethyst-iOS-25 के काम पर बनाया गया है। यह एक स्वतंत्र परियोजना है और Mojang Studios, Microsoft, या अपस्ट्रीम Amethyst टीम से संबद्ध नहीं है।

> **वर्तमान संस्करण:** 0.0.4 · रिलीज़ नोट्स के लिए [`news.md`](../../news.md) देखें।

---

<a id="features"></a>
## विशेषताएं

### Minecraft और मॉड

- शुरुआती बीटा रिलीज़ से लेकर नवीनतम स्नैपशॉट तक अधिकांश **Minecraft: Java Edition** संस्करण चलता है।
- **वेनिला, Fabric, Quilt, Forge, NeoForge, और OptiFine** का समर्थन करता है।
- अपनी स्वयं की सेटिंग्स, मॉड, शेडर्स, संसाधन पैक और दुनिया के साथ पृथक **गेम प्रोफ़ाइल** बनाएं।
- लॉन्चर छोड़े बिना **Modrinth और CurseForge** से सामग्री ब्राउज़ करें और इंस्टॉल करें:
  - mods
  - modpacks
  - शेडर पैक
  - संसाधन पैक
  - साहसिक मानचित्र और दुनिया
- मॉड निर्भरताओं को हल करें और स्थापित करें जहां स्रोत उन्हें प्रदान करता है।
- Forge/NeoForge इंस्टॉलर जार आयात करें और सीधे संस्करण पिकर से Fabric/Quilt लोडर इंस्टॉल करें।

### ग्राफ़िक्स और प्रदर्शन

- **सेटिंग्स → रेंडरर और डिस्प्ले** से एकाधिक रेंडरर्स के बीच स्विच करें:
  - **gl4es** — OpenGL 2.1 अनुकूलता पथ
  - **ANGLE** — OpenGL ईएस से Metal या Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, प्रयोगात्मक
  - **Zink** — OpenGL 4.1 से Mesa 25 और MoltenVK
  - **LTW** - OpenGL 3.3 से OpenGL ईएस/Metal, Minecraft 1.17+, प्रयोगात्मक
  - **TGLMT** — OpenGL 4.6 कोर से Metal, A11 Bionic या नया
- **TGLMT आधुनिक शेडर-आधारित सेटअप के लिए Sodium और Iris समर्थन** के साथ।
- **फ़्रेम जेनरेशन** मोशन-एडेप्टिव जीपीयू (MADI) और कैमरा 3डी रिप्रोजेक्ट मोड के साथ, जिसमें टेम्पोरल इंटरपोलेशन और प्रेडिक्टिव एक्सट्रपलेशन शामिल है।
- रिज़ॉल्यूशन स्केलिंग, अधिकतम फ़्रेमरेट, FSR 1.0 अपस्केलिंग, जीएलएसएल शेडर कैश, और प्रति-रेंडरर ट्यूनिंग।
- कॉन्फ़िगर करने योग्य एफपीएस, सीपीयू, जीपीयू, रैम, तापमान, बैटरी, घड़ी और फ्रेम-पीढ़ी एफपीएस विजेट के साथ प्रदर्शन एचयूडी।
- चार्ट, PNG/PDF निर्यात और साझाकरण के साथ अंतर्निहित प्रदर्शन रिकॉर्डिंग।

### नियंत्रण

- पूरी तरह से अनुकूलन योग्य ऑन-स्क्रीन नियंत्रण लेआउट, बटन आकार और पारदर्शिता।
- **कीबोर्ड और माउस** समर्थन, जिसमें वर्चुअल माउस और समायोज्य पॉइंटर गति शामिल है।
- **गेम कंट्रोलर** कॉन्फ़िगर करने योग्य लेआउट और संवेदनशीलता के साथ समर्थन।
- **जाइरोस्कोप** समायोज्य संवेदनशीलता और अक्ष व्युत्क्रम के साथ लक्ष्य।
- माउस, स्क्रॉल और हॉटबार जेस्चर।
- वैकल्पिक व्यवहार: ब्लॉक रखने के लिए टैप करें, ब्लॉक तोड़ने के लिए दबाए रखें।
- पकड़ी गई वस्तु को ऑफ-हैंड में बदलने के लिए हॉटबार पर दो बार टैप करें।
- स्लाइड करने योग्य हॉटबार और एडजस्टेबल लॉन्ग-प्रेस टाइमिंग।

### लांचर और खाते

- **Microsoft**, **स्थानीय/ऑफ़लाइन**, **डेमो**, और **Ely.by** खाता समर्थन।
- **Java 8, 17, 21, और 25** रनटाइम प्रबंधित करें, उन्हें ऐप में डाउनलोड करें, या अपना खुद का आयात करें।
- LWJGL संस्करण चुनें और जेवीएम तर्क, पर्यावरण चर और मेमोरी आवंटन को ट्यून करें।
- सीमित मेमोरी वाले उपकरणों के लिए ऑटो रैम प्रबंधन।
- थीम, उच्चारण रंग, धुंधलापन, बॉर्डर, कोने का दायरा, कस्टम लॉन्चर फ़ॉन्ट और ऐप आइकन।
- इन-गेम **F3 डिवाइस जानकारी**: डिवाइस चिप, iOS संस्करण, लॉन्चर नाम/संस्करण, बिल्ड नंबर और बिल्ड प्रकार।
- उन्नत सेटअप के लिए वैकल्पिक **Witch सर्वर**, CurseForge, और AI एकीकरण।
- **52 इन-ऐप भाषाएँ**, जिसमें दाएँ से बाएँ भाषा पैक और मज़ेदार स्थान शामिल हैं।

---

<a id="screenshots"></a>
## स्क्रीनशॉट

Witch Launcher 0.0.4 के विकास निर्माण से स्क्रीनशॉट। इंटरफ़ेस संस्करणों और थीम के बीच बदल सकता है।

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
## आवश्यकताएँ

| आवश्यकता | विवरण |
|---|---|
| **डिवाइस** | iPhone या iPad एक arm64 प्रोसेसर और Metal समर्थन के साथ |
| **सिस्टम** | iOS या iPadOS **14.0 या नया** |
| **JIT** | आवश्यक। JIT को StikDebug, SideStore, TrollStore, या जेलब्रेक सेटअप के माध्यम से सक्षम करें |
| **खाता** | एक Microsoft खाता जो आधिकारिक डाउनलोड के लिए Minecraft का स्वामी है; स्थानीय और डेमो मोड भी उपलब्ध हैं |
| **भंडारण** | लॉन्चर के लिए जगह, Java रनटाइम, गेम संस्करण, मॉड और दुनिया |
| **नेटवर्क** | साइन-इन, संस्करण डाउनलोड, सामग्री ब्राउज़र और वैकल्पिक ऑनलाइन सेवाओं के लिए आवश्यक |

Witch में Minecraft गेम फ़ाइलें शामिल **नहीं** हैं। किसी योग्य खाते में साइन इन करने के बाद गेम फ़ाइलें लॉन्चर के माध्यम से डाउनलोड की जाती हैं।

### JIT नोट्स

Minecraft: Java Edition को JIT की आवश्यकता है, और Witch इसके बिना गेम लॉन्च नहीं कर सकता।

- **SideStore / AltStore-शैली इंस्टॉल:** Witch के लिए JIT सक्षम करें और आवश्यक VPN/डीबगर कनेक्शन सक्रिय रखें। इन-ऐप संदेश **LocalDevVPN** और `CS_DEBUGGED` को संदर्भित करता है।
- **StikDebug:** StikDebug को Witch से जोड़ें और JIT सक्षम करें। **iOS 26/27** को, StikDebug को खेल चलने के दौरान जुड़े रहना चाहिए। `UniversalJIT26.js` को जरूरत पड़ने पर क्लिपबोर्ड पर कॉपी किया जाता है।
- **TrollStore:** यदि Witch JIT की प्रतीक्षा करता रहता है, तो TrollStore में **URL Scheme** को सक्षम करें।
- **जेलब्रेक डिवाइस:** अपने पसंदीदा JIT इनेबलर का उपयोग करें।
- यदि लॉन्चर **वेटिंग फॉर JIT** स्क्रीन पर रहता है, तो पुन: लॉन्च करने से पहले डिबगर कनेक्शन, VPN, और TrollStore URL Scheme सेटिंग की जांच करें।

JIT व्यवहार iOS संस्करण और स्थापना विधि पर निर्भर करता है। सिस्टम अपडेट मौजूदा JIT सेटअप को तोड़ सकता है।

---

<a id="installation"></a>
## स्थापना

Witch आपके डिवाइस के लिए हस्ताक्षरित होना चाहिए। यह भंडार प्रमाणपत्र या पूर्व-हस्ताक्षरित आईपीए नहीं भेजता है।

### एक निर्माण का प्रयोग करें

1. [डेवलपमेंट वर्कफ़्लो](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) से एक डेवलपमेंट बिल्ड डाउनलोड करें, या जिस स्रोत पर आप भरोसा करते हैं, उससे हस्ताक्षरित बिल्ड का उपयोग करें।
2. इसे **SideStore**, **AltStore**, **TrollStore**, या अपनी पसंदीदा साइडलोडिंग विधि से साइन और इंस्टॉल करें।
3. गेम लॉन्च करने से पहले ऊपर बताए अनुसार JIT सक्षम करें।

TrollStore बिल्ड अतिरिक्त पात्रताओं का उपयोग करता है और इसे सामान्य साइडलोडिंग साइनर के साथ स्थापित नहीं किया जाना चाहिए।

### स्रोत से निर्माण करें

Witch को संकलित करने के लिए macOS के साथ Xcode कमांड-लाइन टूल, iOS SDK 14.0 या नया, CMake, JDK 8, `ldid`, `wget`, `zip`, और गिट की आवश्यकता होती है।

```bash
गिट क्लोन - पुनरावर्ती https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

पैकेज्ड बिल्ड्स को `artifacts/` को लिखा जाता है।

इसके बजाय एक TrollStore पैकेज बनाने के लिए:

```bash
make package TROLLSTORE_JIT_ENT=1
```

रेंडरर स्रोत लिंक और नोट्स बनाने के लिए, [`note.md`](../../note.md) देखें।

---

<a id="languages"></a>
## भाषाएँ

Witch Launcher **52 भाषा पैक** के साथ जहाज। **सेटिंग्स → सामान्य → भाषा** खोलें और एक भाषा चुनें, या डिवाइस की भाषा का अनुसरण करने के लिए **ऑटो** का उपयोग करें।

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

ऐप सभी **52 भाषा पैक** शिप करता है। README अनुवाद अंग्रेजी सहित **सभी 52 भाषाओं** के लिए उपलब्ध हैं।

कुछ अनुवाद मशीन-समर्थित होते हैं और उनमें अजीब तकनीकी शब्द हो सकते हैं। सुधारों का स्वागत है.

इस README की स्रोत भाषा अंग्रेजी है। स्थानीयकृत README इस पृष्ठ के शीर्ष पर और [`docs/readme/`](./) निर्देशिका में भाषा चयनकर्ता से उपलब्ध हैं।

---

<a id="notes-and-limitations"></a>
## नोट्स और सीमाएँ

- **JIT अनिवार्य है।** बिना कार्यशील JIT सेटअप के, Minecraft लॉन्च नहीं होगा।
- **iOS 26/27 JIT नाजुक है।** StikDebug संलग्न रहना चाहिए, और भविष्य में ओएस अपडेट जो काम करता है उसे बदल सकता है।
- **प्रयोगात्मक** के रूप में चिह्नित रेंडरर्स क्रैश हो सकते हैं या गलत तरीके से रेंडर कर सकते हैं। यदि आप अनिश्चित हैं तो **ऑटो** से प्रारंभ करें।
- **फ़्रेम जनरेशन** को MoltenVK रेंडरर और Metal कंप्यूट समर्थन की आवश्यकता होती है। यह बैटरी उपयोग और डिवाइस तापमान को बढ़ा सकता है।
- कुछ मॉड, मॉडपैक, शेडर्स और वर्ल्ड के लिए एक विशिष्ट Minecraft संस्करण, लोडर, रेंडरर या अतिरिक्त मेमोरी की आवश्यकता हो सकती है।
- CurseForge मॉडपैक `manifest.json` का उपयोग करते हैं; यदि किसी पैक के लिए वन-टैप इंस्टॉलेशन उपलब्ध नहीं है, तो संग्रह को मैन्युअल रूप से आयात करें।
- ऑनलाइन सुविधाएँ तृतीय-पक्ष सेवाओं पर निर्भर करती हैं और अनुपलब्ध हो सकती हैं।
- स्क्रीनशॉट एक डेवलपमेंट बिल्ड से हैं और वर्तमान रिलीज़ से बिल्कुल मेल नहीं खा सकते हैं।

---

<a id="project-lineage"></a>
## परियोजना वंश

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

### संबंधित परियोजनाएँ

- [Amethyst एंड्रॉइड](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## योगदान दे रहे हैं

बग रिपोर्ट और पीआर का स्वागत है। किसी समस्या की रिपोर्ट करते समय, इसमें शामिल करें:

- डिवाइस मॉडल और iOS/iPadOS संस्करण
- Witch Launcher संस्करण
- रेंडरर और Minecraft संस्करण
- मॉड लोडर और स्थापित मॉड की एक सूची
- पुनरुत्पादन के चरण
- प्रासंगिक लॉग या क्रैश रिपोर्ट

कृपया प्रमाणपत्रों, प्रावधान प्रोफ़ाइलों, API कुंजियों, या अन्य रहस्यों पर हस्ताक्षर न करें।

---

<a id="credits"></a>
## श्रेय

**Witch Launcher** का रखरखाव **DuyAnh662 (Za_d626)** द्वारा किया जाता है।

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [एक्स](https://x.com/duyanh662)

### अपस्ट्रीम और समुदाय

Witch Launcher और इसकी अपस्ट्रीम परियोजनाएं कई योगदानकर्ताओं के काम पर बनाई गई हैं, जिनमें शामिल हैं:

- **@crystall1nedev** - Amethyst प्रोजेक्ट मैनेजर और iOS पोर्ट डेवलपर
- **@khanhduytran0** - iOS पोर्ट डेवलपर
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE प्रोजेक्ट, ख्रोनोस ग्रुप, Mesa प्रोजेक्ट, PojavLauncher टीम, मोज़िला, और Minecraft समुदाय को अतिरिक्त धन्यवाद।

[MCHeads](https://mc-heads.net) को Minecraft अवतार सेवाएँ प्रदान करने के लिए विशेष धन्यवाद।

संपूर्ण तृतीय-पक्ष घटक और लाइसेंस सूची [`credits.md`](../../credits.md) में उपलब्ध है।

---

<a id="license"></a>
## लाइसेंस

Witch Launcher को **जीएनयू जनरल पब्लिक लाइसेंस v3.0** के तहत वितरित किया जाता है, जो [`credits.md`](../../credits.md) में सूचीबद्ध तीसरे पक्ष के घटकों के लाइसेंस और कॉपीराइट आवश्यकताओं के अधीन है।

संपूर्ण लाइसेंस पाठ के लिए [`LICENSE`](../../LICENSE) देखें।

---

<p align="center">
<sub>Minecraft Mojang Studios का ट्रेडमार्क है। Witch Launcher Mojang Studios, Microsoft, या Amethyst परियोजना से संबद्ध नहीं है।</sub>
</p>
