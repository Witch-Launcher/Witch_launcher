<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition บน iPhone และ iPad.</strong><br>
ทางแยก iOS และ iPadOS ที่สร้างโดยชุมชนของ Amethyst ดูแลโดย DuyAnh662 (Za_d626)
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[คุณสมบัติ](#features) · [ภาพหน้าจอ](#screenshots) · [ข้อกำหนด](#requirements) · [การติดตั้ง](#installation) · [ภาษา](#languages) · [เครดิต](#credits) · [ใบอนุญาต](#license)

<details>
<summary><strong>ภาษา</strong></summary>

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
## เกี่ยวกับ

**Witch Launcher** เป็นทางแยกอิสระที่ดูแลโดยชุมชนของ [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) ที่นำ **Minecraft: Java Edition** มาสู่ iPhone และ iPad โดยผสมผสาน UI ของ Launcher แบบสัมผัสเข้ากับตัวจัดการรันไทม์ Java เต็มรูปแบบ LWJGL และสแต็กกราฟิกที่สร้างขึ้นรอบเลเยอร์การแปล Metal, MoltenVK และ OpenGL

Witch สร้างขึ้นจากผลงานของ [Boardwalk](https://github.com/zhuowei/Boardwalk), ชุมชน [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS และ Amethyst-iOS-25 เป็นโครงการอิสระและไม่มีส่วนเกี่ยวข้องกับทีมงาน Mojang Studios, Microsoft หรือทีมงานต้นน้ำ Amethyst

> **เวอร์ชันปัจจุบัน:** 0.0.4 · ดูบันทึกประจำรุ่น [`news.md`](../../news.md)

---

<a id="features"></a>
## คุณสมบัติ

### Minecraft และม็อด

- ใช้งานเวอร์ชัน **Minecraft: Java Edition** ส่วนใหญ่ ตั้งแต่รุ่นเบต้าช่วงแรกๆ ไปจนถึงสแนปชอตล่าสุด
- รองรับ **วานิลลา Fabric, Quilt, Forge, NeoForge และ OptiFine**
- สร้าง**โปรไฟล์เกม**แบบแยกส่วนด้วยการตั้งค่า ม็อด เชเดอร์ ชุดทรัพยากร และโลกของตัวเอง
- เรียกดูและติดตั้งเนื้อหาจาก **Modrinth และ CurseForge** โดยไม่ต้องออกจาก Launcher:
  - ม็อด
  - ม็อดแพ็ก
  - แพ็คเชเดอร์
  - ชุดทรัพยากร
  - แผนที่การผจญภัยและโลก
- แก้ไขและติดตั้งการขึ้นต่อกันของ mod โดยที่แหล่งที่มาจัดเตรียมไว้
- นำเข้า JAR ตัวติดตั้ง Forge/NeoForge และติดตั้งตัวโหลด Fabric/Quilt โดยตรงจากเครื่องมือเลือกเวอร์ชัน

### กราฟิกและประสิทธิภาพ

- สลับระหว่างตัวเรนเดอร์หลายตัวจาก **การตั้งค่า → ตัวเรนเดอร์และดิสเพลย์**:
  - **gl4es** — OpenGL 2.1 เส้นทางความเข้ากันได้
  - **ANGLE** — OpenGL ES ถึง Metal หรือ Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, การทดลอง
  - **Zink** — OpenGL 4.1 ถึง Mesa 25 และ MoltenVK
  - **LTW** — OpenGL 3.3 ถึง OpenGL ES/Metal, Minecraft 1.17+, การทดลอง
  - **TGLMT** — OpenGL 4.6 หลักถึง Metal, A11 Bionic หรือใหม่กว่า
- **TGLMT พร้อมการสนับสนุน Sodium และ Iris** สำหรับการตั้งค่าที่ใช้เชดเดอร์สมัยใหม่
- **การสร้างเฟรม**ด้วย GPU แบบปรับตามการเคลื่อนไหว (MADI) และโหมดการฉายภาพ 3 มิติของกล้อง รวมถึงการแก้ไขชั่วคราวและการประมาณค่าคาดการณ์
- การปรับขนาดความละเอียด, อัตราเฟรมสูงสุด, FSR 1.0 การเพิ่มขนาด, แคชเชเดอร์ GLSL และการปรับแต่งต่อการแสดงผล
- HUD ประสิทธิภาพพร้อม FPS, CPU, GPU, RAM, อุณหภูมิ, แบตเตอรี่, นาฬิกา และวิดเจ็ต FPS ที่สร้างเฟรมที่กำหนดค่าได้
- การบันทึกประสิทธิภาพในตัวพร้อมแผนภูมิ PNG/PDF การส่งออก และการแชร์

### การควบคุม

- รูปแบบการควบคุมบนหน้าจอ ขนาดปุ่ม และความโปร่งใสที่ปรับแต่งได้อย่างเต็มที่
- รองรับ**แป้นพิมพ์และเมาส์** รวมถึงเมาส์เสมือนและความเร็วของตัวชี้ที่ปรับได้
- รองรับ **ตัวควบคุมเกม** ด้วยรูปแบบและความไวที่กำหนดค่าได้
- **ไจโรสโคป** เล็งด้วยความไวที่ปรับได้และการกลับแกน
- ท่าทางเมาส์ การเลื่อน และแถบลัด
- พฤติกรรมทางเลือก: แตะเพื่อวางบล็อก กดค้างไว้เพื่อทำลายบล็อก
- แตะแถบลัดสองครั้งเพื่อสลับไอเทมที่ถือไว้เป็นไอเทมรอง
- แถบลัดแบบเลื่อนได้และการตั้งเวลากดแบบยาวที่ปรับได้

### ตัวเรียกใช้และบัญชี

- การสนับสนุนบัญชี **Microsoft**, **ท้องถิ่น/ออฟไลน์**, **สาธิต** และ **Ely.by**
- จัดการรันไทม์ **Java 8, 17, 21 และ 25** ดาวน์โหลดในแอป หรือนำเข้าของคุณเอง
- เลือกเวอร์ชัน LWJGL และปรับแต่งอาร์กิวเมนต์ JVM ตัวแปรสภาพแวดล้อม และการจัดสรรหน่วยความจำ
- การจัดการ RAM อัตโนมัติสำหรับอุปกรณ์ที่มีหน่วยความจำจำกัด
- ธีม สีเฉพาะจุด ความเบลอ เส้นขอบ รัศมีมุม แบบอักษร Launcher แบบกำหนดเอง และไอคอนแอป
- **F3 ข้อมูลอุปกรณ์**ในเกม: ชิปอุปกรณ์ เวอร์ชัน iOS ชื่อ/เวอร์ชันตัวเรียกใช้งาน หมายเลขบิลด์ และประเภทบิลด์
- การรวม **Witch เซิร์ฟเวอร์**, CurseForge และ AI เพิ่มเติมสำหรับการตั้งค่าขั้นสูง
- **52 ภาษาในแอป** รวมถึงชุดภาษาที่อ่านจากขวาไปซ้ายและสถานที่สนุกๆ

---

<a id="screenshots"></a>
## ภาพหน้าจอ

ภาพหน้าจอจากรุ่นการพัฒนาของ Witch Launcher 0.0.4 อินเทอร์เฟซสามารถเปลี่ยนระหว่างเวอร์ชันและธีมได้

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
## ข้อกำหนด

| ข้อกำหนด | รายละเอียด |
|---|---|
| **อุปกรณ์** | iPhone หรือ iPad พร้อมตัวประมวลผล arm64 และการสนับสนุน Metal |
| **ระบบ** | iOS หรือ iPadOS **14.0 หรือใหม่กว่า** |
| **JIT** | ที่จำเป็น. เปิดใช้งาน JIT ถึง StikDebug, SideStore, TrollStore หรือการตั้งค่าการเจลเบรค |
| **บัญชี** | บัญชี Microsoft ที่เป็นเจ้าของ Minecraft สำหรับการดาวน์โหลดอย่างเป็นทางการ นอกจากนี้ยังมีโหมดท้องถิ่นและโหมดสาธิต |
| **ที่เก็บข้อมูล** | พื้นที่สำหรับตัวเรียกใช้งาน Java รันไทม์ เวอร์ชันเกม ม็อด และโลก |
| **เครือข่าย** | จำเป็นสำหรับการลงชื่อเข้าใช้ การดาวน์โหลดเวอร์ชัน เบราว์เซอร์เนื้อหา และบริการออนไลน์เสริม |

Witch **ไม่** รวมไฟล์เกม Minecraft ไฟล์เกมจะถูกดาวน์โหลดผ่าน Launcher หลังจากลงชื่อเข้าใช้บัญชีที่มีสิทธิ์

### JIT หมายเหตุ

Minecraft: Java Edition ต้องการ JIT และ Witch ไม่สามารถเปิดเกมได้หากไม่มี

- **SideStore / AltStore-การติดตั้งสไตล์:** เปิดใช้งาน JIT สำหรับ Witch และให้การเชื่อมต่อ VPN/ดีบักเกอร์ที่จำเป็นทำงานต่อไป ข้อความในแอปอ้างถึง **LocalDevVPN** และ `CS_DEBUGGED`
- **StikDebug:** แนบ StikDebug กับ Witch และเปิดใช้งาน JIT ในวันที่ **iOS 26/27** StikDebug จะต้องติดอยู่ในขณะที่เกมกำลังทำงานอยู่ `UniversalJIT26.js` จะถูกคัดลอกไปยังคลิปบอร์ดเมื่อจำเป็น
- **TrollStore:** เปิดใช้งาน **URL Scheme** ใน TrollStore หาก Witch รอ JIT ต่อไป
- **อุปกรณ์ที่เจลเบรคแล้ว:** ใช้ตัวเปิดใช้งาน JIT ที่คุณต้องการ
- หากตัวเรียกใช้งานยังคงอยู่บนหน้าจอ **กำลังรอ JIT** ให้ตรวจสอบการเชื่อมต่อดีบักเกอร์ การตั้งค่า VPN และ TrollStore URL Scheme ก่อนเปิดใช้งานอีกครั้ง

ลักษณะการทำงานของ JIT ขึ้นอยู่กับเวอร์ชัน iOS และวิธีการติดตั้ง การอัปเดตระบบอาจทำให้การตั้งค่า JIT ที่มีอยู่เสียหายได้

---

<a id="installation"></a>
## การติดตั้ง

Witchต้องลงนามสำหรับอุปกรณ์ของคุณ พื้นที่เก็บข้อมูลนี้ไม่ได้จัดส่งใบรับรองหรือ IPA ที่ลงนามล่วงหน้า

### ใช้บิลด์

1. ดาวน์โหลดบิลด์การพัฒนาจาก [เวิร์กโฟลว์การพัฒนา](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) หรือใช้บิลด์ที่ลงนามจากแหล่งที่คุณเชื่อถือ
2. ลงนามและติดตั้งด้วย **SideStore**, **AltStore**, **TrollStore** หรือวิธีการไซด์โหลดที่คุณต้องการ
3. เปิดใช้งาน JIT ตามที่อธิบายไว้ข้างต้นก่อนเริ่มเกม

TrollStore บิลด์ใช้การให้สิทธิ์เพิ่มเติม และไม่ควรติดตั้งร่วมกับผู้ลงนามไซด์โหลดปกติ

### สร้างจากแหล่งที่มา

การคอมไพล์ Witch ต้องใช้ macOS ด้วยเครื่องมือบรรทัดคำสั่ง Xcode, iOS SDK 14.0 หรือใหม่กว่า, CMake, JDK 8, `ldid`, `wget`, `zip` และ Git

```bash
git clone --https://github.com/Witch-Launcher/Witch_launcher.git แบบเรียกซ้ำ
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

บิลด์แบบแพ็กเกจเขียนถึง `artifacts/`

หากต้องการสร้างแพ็คเกจ TrollStore แทน:

```bash
make package TROLLSTORE_JIT_ENT=1
```

สำหรับลิงก์แหล่งที่มาของตัวแสดงผลและบันทึกการสร้าง โปรดดูที่ [`note.md`](../../note.md)

---

<a id="languages"></a>
## ภาษา

Witch Launcher มาพร้อมกับ **52 ชุดภาษา** เปิด **การตั้งค่า → ทั่วไป → ภาษา** และเลือกภาษา หรือใช้ **อัตโนมัติ** เพื่อทำตามภาษาของอุปกรณ์

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

แอปนี้จัดส่ง **52 ชุดภาษา** ทั้งหมด การแปล README มีให้บริการสำหรับ **ทั้งหมด 52 ภาษา** รวมถึงภาษาอังกฤษ

การแปลบางรายการใช้เครื่องช่วยและอาจมีคำศัพท์ทางเทคนิคที่น่าอึดอัดใจ การแก้ไขยินดีต้อนรับ

ภาษาอังกฤษเป็นภาษาต้นฉบับสำหรับ README นี้ README ที่แปลแล้วมีอยู่ในตัวเลือกภาษาที่ด้านบนของหน้านี้และในไดเรกทอรี [`docs/readme/`](./)

---

<a id="notes-and-limitations"></a>
## หมายเหตุและข้อจำกัด

- **JIT เป็นข้อบังคับ** หากไม่มีการตั้งค่า JIT ที่ใช้งานได้ Minecraft จะไม่เริ่มทำงาน
- **iOS 26/27 JIT นั้นเปราะบาง** StikDebug จะต้องแนบมาด้วย และการอัปเดตระบบปฏิบัติการในอนาคตอาจเปลี่ยนแปลงการทำงาน
- ตัวแสดงผลที่ทำเครื่องหมายว่า**ทดลอง**อาจขัดข้องหรือแสดงผลไม่ถูกต้อง เริ่มต้นด้วย **อัตโนมัติ** หากคุณไม่แน่ใจ
- **การสร้างเฟรม** ต้องใช้ตัวเรนเดอร์ MoltenVK และการสนับสนุนการประมวลผล Metal สามารถเพิ่มการใช้งานแบตเตอรี่และอุณหภูมิของอุปกรณ์ได้
- Mods, Modpacks, Shaders และ Worlds บางตัวอาจต้องใช้เวอร์ชัน Minecraft ตัวโหลด ตัวเรนเดอร์ หรือหน่วยความจำเพิ่มเติมโดยเฉพาะ
- CurseForge modpacks ใช้ `manifest.json`; หากไม่มีการติดตั้งด้วยการแตะเพียงครั้งเดียวสำหรับแพ็ค ให้นำเข้าไฟล์เก็บถาวรด้วยตนเอง
- คุณสมบัติออนไลน์ขึ้นอยู่กับบริการของบุคคลที่สามและอาจไม่พร้อมใช้งาน
- ภาพหน้าจอมาจากรุ่นการพัฒนาและอาจไม่ตรงกับรุ่นปัจจุบันทุกประการ

---

<a id="project-lineage"></a>
## เชื้อสายโครงการ

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

### โครงการที่เกี่ยวข้อง

- [Amethyst แอนดรอยด์](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## มีส่วนร่วม

ยินดีรายงานข้อผิดพลาดและประชาสัมพันธ์ เมื่อรายงานปัญหา ให้รวม:

- รุ่นอุปกรณ์และเวอร์ชัน iOS/iPadOS
- เวอร์ชันWitch Launcher
- ตัวเรนเดอร์และเวอร์ชัน Minecraft
- mod loader และรายการ mods ที่ติดตั้ง
- ขั้นตอนในการสืบพันธุ์
- บันทึกที่เกี่ยวข้องหรือรายงานข้อขัดข้อง

กรุณาอย่าลงนามใบรับรอง การจัดเตรียมโปรไฟล์ คีย์ API หรือความลับอื่นๆ

---

<a id="credits"></a>
## เครดิต

**Witch Launcher** ได้รับการดูแลโดย **DuyAnh662 (Za_d626)**

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### ต้นน้ำและชุมชน

Witch Launcher และโครงการต้นน้ำถูกสร้างขึ้นจากผลงานของผู้ร่วมให้ข้อมูลจำนวนมาก รวมไปถึง:

- **@crystall1nedev** — Amethyst ผู้จัดการโครงการ และ iOS ผู้พัฒนาพอร์ต
- **@khanhduytran0** — iOS ผู้พัฒนาพอร์ต
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

ขอขอบคุณเพิ่มเติมสำหรับ **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla และชุมชน Minecraft

ขอขอบคุณเป็นพิเศษสำหรับ [MCHeads](https://mc-heads.net) สำหรับการให้บริการอวาตาร์ Minecraft

รายการส่วนประกอบและใบอนุญาตของบุคคลที่สามฉบับสมบูรณ์มีอยู่ใน[`credits.md`](../../credits.md)

---

<a id="license"></a>
## ใบอนุญาต

Witch Launcher ได้รับการเผยแพร่ภายใต้ **GNU General Public License v3.0** ภายใต้ใบอนุญาตและข้อกำหนดด้านลิขสิทธิ์ของส่วนประกอบของบุคคลที่สามที่ระบุไว้ใน [`credits.md`](../../credits.md)

ดู[`LICENSE`](../../LICENSE) สำหรับข้อความใบอนุญาตฉบับสมบูรณ์

---

<p align="center">
<sub>Minecraft เป็นเครื่องหมายการค้าของ Mojang Studios Witch Launcher ไม่มีส่วนเกี่ยวข้องกับ Mojang Studios, Microsoft หรือโครงการ Amethyst </sub>
</p>
