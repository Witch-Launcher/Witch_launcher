<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone və iPad tarixlərində.</strong><br>
DuyAnh662 (Za_d626) tərəfindən idarə olunan iOS və Amethyst icma tərəfindən yaradılmış iPadOS çəngəl.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Xüsusiyyətlər](#features) · [Ekran görüntüləri](#screenshots) · [Tələblər](#requirements) · [Quraşdırma](#installation) · [Dillər](#languages) · [Kreditlər](#credits) · [Lisenziya](#license)

<details>
<summary><strong>Dillər</strong></summary>

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
## Haqqında

**Witch Launcher** müstəqil, icma tərəfindən idarə olunan [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) çəngəlidir və **Minecraft: Java Edition**-u iPhone və iPad-ə gətirir. O, ilk toxunan başlatma interfeysini tam Java icra vaxtı meneceri, LWJGL və Metal, MoltenVK və OpenGL tərcümə təbəqələri ətrafında qurulmuş qrafik yığını ilə birləşdirir.

Witch Boardwalk](https://github.com/zhuowei/Boardwalk), PojavLauncher](https://github.com/PojavLauncherTeam) icmasının, Amethyst-iOS və Amethyst-iOS-25-ün işi üzərində qurulmuşdur. Bu, müstəqil layihədir və Mojang Studios, Microsoft və ya yuxarı Amethyst komandası ilə əlaqəli deyil.

> **Cari versiya:** 0.0.4 · Buraxılış qeydləri üçün [`news.md`](../../news.md)-ə baxın.

---

<a id="features"></a>
## Xüsusiyyətlər

### Minecraft və mods

- Erkən Beta buraxılışlarından ən son snapşotlara qədər **Minecraft: Java Edition** versiyalarının əksəriyyətini işlədir.
- **Vanil, Fabric, Quilt, Forge, NeoForge və OptiFine** dəstəkləyir.
- Öz parametrləri, modları, şaderləri, resurs paketləri və dünyaları ilə təcrid olunmuş **oyun profilləri** yaradın.
- Başlatıcıdan çıxmadan **Modrinth və CurseForge** məzmununu nəzərdən keçirin və quraşdırın:
  - mods
  - modpaketlər
  - şeyder paketləri
  - resurs paketləri
  - macəra xəritələri və dünyalar
- Mod asılılıqlarını mənbənin təmin etdiyi yerdə həll edin və quraşdırın.
- Forge/NeoForge quraşdırıcı JAR-larını idxal edin və Fabric/Quilt yükləyicilərini birbaşa versiya seçicisindən quraşdırın.

### Qrafika və performans

- **Parametrlər → Render və Displey**-dən çoxlu rendererlər arasında keçid edin:
  - **gl4es** — OpenGL 2.1 uyğunluq yolu
  - **ANGLE** — OpenGL ES - Metal və ya Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimental
  - **Zink** — OpenGL 4.1 - Mesa 25 və MoltenVK
  - **LTW** — OpenGL 3.3 - OpenGL ES/Metal, Minecraft 1.17+, eksperimental
  - **TGLMT** — OpenGL 4.6 Əsas - Metal, A11 Bionic və ya daha yeni
- Müasir şeyder əsaslı quraşdırmalar üçün **TGLMT Sodium və Iris dəstəyi ilə**.
- Hərəkətə Uyğunlaşan GPU (MADI) və müvəqqəti interpolyasiya və proqnozlaşdırıcı ekstrapolyasiya daxil olmaqla, Kamera 3D Yenidən Layihə rejimləri ilə **Çərçivə Yaradılması**.
- Qətnamənin miqyası, maksimum kadr sürəti, FSR 1.0 miqyasının yüksəldilməsi, GLSL şeyder keşləri və hər bir renderer tənzimləməsi.
- Konfiqurasiya edilə bilən FPS, CPU, GPU, RAM, temperatur, batareya, saat və çərçivə nəsil FPS vidjetləri ilə performans HUD.
- Diaqramlar, PNG/PDF ixrac və paylaşma ilə daxili performans qeydi.

### Nəzarətlər

- Tamamilə fərdiləşdirilə bilən ekran idarəetmə planları, düymələrin ölçüləri və şəffaflıq.
- **Klaviatura və siçan** dəstəyi, o cümlədən virtual siçan və tənzimlənən göstərici sürəti.
- Konfiqurasiya edilə bilən planlar və həssaslıqla **Oyun nəzarətçisi** dəstəyi.
- Tənzimlənən həssaslıq və oxun çevrilməsi ilə hədəflənən **Giroskop**.
- Siçan, sürüşdürmə və isti panel jestləri.
- Könüllü davranış: blokları yerləşdirmək üçün toxunun, blokları qırmaq üçün basıb saxlayın.
- Saxlanılan elementi əlinizdən kənara dəyişdirmək üçün qaynar panelə iki dəfə toxunun.
- Sürüşən hotbar və tənzimlənən uzun basma vaxtı.

### Başlatıcı və hesablar

- **Microsoft**, **yerli/oflayn**, **demo** və **Ely.by** hesab dəstəyi.
- **Java 8, 17, 21 və 25** iş vaxtlarını idarə edin, onları tətbiqdaxili endirin və ya özünüzə idxal edin.
- LWJGL versiyaları seçin və JVM arqumentlərini, mühit dəyişənlərini və yaddaşın ayrılmasını sazlayın.
- Məhdud yaddaşa malik cihazlar üçün avtomatik RAM idarəetməsi.
- Mövzular, vurğu rəngləri, bulanıqlıq, haşiyələr, künc radiusu, fərdi başlatma şriftləri və proqram nişanları.
- Oyundaxili **F3 cihaz məlumatı**: cihaz çipi, iOS versiyası, başlatma cihazının adı/versiyasi, quruluş nömrəsi və quruluş növü.
- Təkmil quraşdırmalar üçün əlavə **Witch Server**, CurseForge və AI inteqrasiyaları.
- **52 tətbiqdaxili dil**, o cümlədən sağdan sola dil paketləri və əyləncəli dillər.

---

<a id="screenshots"></a>
## Ekran görüntüləri

Witch Launcher 0.0.4 inkişaf quruluşundan skrinşotlar. İnterfeys versiyalar və mövzular arasında dəyişə bilər.

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
## Tələblər

| Tələb | Təfərrüatlar |
|---|---|
| **Cihaz** | iPhone və ya iPad prosessoru arm64 və Metal dəstəyi ilə |
| **Sistem** | iOS və ya iPadOS **14.0 və ya daha yeni** |
| **JIT** | Tələb olunur. JIT vasitəsilə StikDebug, SideStore, TrollStore və ya jailbroken quraşdırma |
| **Hesab** | Rəsmi yükləmələr üçün Minecraft sahibi olan Microsoft hesabı; yerli və demo rejimləri də mövcuddur |
| **Yaddaş** | Başlatıcı üçün yer, Java iş vaxtları, oyun versiyaları, modlar və dünyalar |
| **Şəbəkə** | Daxil olmaq, versiya yükləmələri, məzmun brauzeri və əlavə onlayn xidmətlər üçün tələb olunur |

Witch Minecraft oyun fayllarını **daxil etmir**. Oyun faylları uyğun hesaba daxil olduqdan sonra başlatma vasitəsi ilə endirilir.

### JIT qeyd edir

Minecraft: Java Edition üçün JIT lazımdır və Witch onsuz oyunu işə sala bilməz.

- **SideStore / AltStore-tipli quraşdırmalar:** Witch üçün JIT-ni aktivləşdirin və tələb olunan VPN/sazlayıcı bağlantını aktiv saxlayın. Tətbiqdaxili mesaj **LocalDevVPN** və `CS_DEBUGGED`-a aiddir.
- **StikDebug:** StikDebug-ni Witch-a əlavə edin və JIT-ni aktivləşdirin. **iOS 26/27** tarixində StikDebug oyun işləyərkən bağlı qalmalıdır. `UniversalJIT26.js` lazım olduqda buferə kopyalanır.
- **TrollStore:** Witch JIT-ni gözləməyə davam edərsə, TrollStore-də **URL Scheme**-ni aktivləşdirin.
- **Ceylbroken cihazlar:** üstünlük verdiyiniz JIT aktivləşdiricidən istifadə edin.
- Başlatıcı **JIT gözlənilir** ekranında qalsa, yenidən işə salmazdan əvvəl sazlayıcı bağlantını, VPN və TrollStore URL Scheme ayarını yoxlayın.

JIT davranışı iOS versiyasından və quraşdırma metodundan asılıdır. Sistem yeniləmələri mövcud JIT quraşdırmaları poza bilər.

---

<a id="installation"></a>
## Quraşdırma

Witch cihazınız üçün imzalanmalıdır. Bu depo sertifikatları və ya əvvəlcədən imzalanmış İPA-ları göndərmir.

### Quraşdırma istifadə edin

1. [inkişaf iş axını](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)-dən inkişaf quruluşunu endirin və ya etibar etdiyiniz mənbədən imzalanmış quruluşdan istifadə edin.
2. Onu **SideStore**, **AltStore**, **TrollStore** və ya seçdiyiniz yan yükləmə metodu ilə imzalayın və quraşdırın.
3. Oyuna başlamazdan əvvəl yuxarıda təsvir edildiyi kimi JIT-ni aktivləşdirin.

TrollStore konstruksiyaları əlavə hüquqlardan istifadə edir və normal yan yükləmə imzalayıcısı ilə quraşdırılmamalıdır.

### Mənbədən qurun

Witch-nı tərtib etmək üçün macOS Xcode əmr xətti alətləri, iOS SDK 14.0 və ya daha yeni, CMake, JDK 8, `ldid`, `wget`, `zip` tələb olunur.

```bash
git clone --rekursiv https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Paketlənmiş quruluşlar `artifacts/`-ə yazılır.

Bunun əvəzinə TrollStore paketi yaratmaq üçün:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Renderer mənbə keçidləri və tərtib qeydləri üçün bax [`note.md`](../../note.md).

---

<a id="languages"></a>
## Dillər

Witch Launcher **52 dil paketi** ilə göndərilir. **Parametrlər → Ümumi → Dil**-i açın və dil seçin və ya cihazın dilini izləmək üçün **Avtomatik**-dən istifadə edin.

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

Tətbiq bütün **52 dil paketini** göndərir. README tərcümələri ingilis dili də daxil olmaqla **bütün 52 dildə** mövcuddur.

Bəzi tərcümələr maşınla işləyir və yöndəmsiz texniki terminlər ehtiva edə bilər. Düzəlişlər xoşdur.

İngilis dili bu README üçün mənbə dilidir. Lokallaşdırılmış README-lər bu səhifənin yuxarısındakı dil seçicisindən və [`docs/readme/`](./) kataloqunda mövcuddur.

---

<a id="notes-and-limitations"></a>
## Qeydlər və məhdudiyyətlər

- **JIT məcburidir.** İşləyən JIT quraşdırması olmadan Minecraft işə salınmayacaq.
- **iOS 26/27 JIT kövrəkdir.** StikDebug bağlı qalmalıdır və gələcək ƏS yeniləmələri nə işlədiyini dəyişə bilər.
- **eksperimental** olaraq işarələnmiş rendererlər qəzaya uğraya və ya səhv göstərə bilər. Əmin deyilsinizsə, **Avtomatik** ilə başlayın.
- **Frame Generation** MoltenVK renderer və Metal hesablama dəstəyi tələb edir. Batareyanın istifadəsini və cihazın temperaturunu artıra bilər.
- Bəzi modlar, modpaketlər, şaderlər və dünyalar xüsusi Minecraft versiya, yükləyici, renderer və ya əlavə yaddaş tələb edə bilər.
- CurseForge modpaketlər `manifest.json` istifadə edir; paket üçün bir kliklə quraşdırma mümkün deyilsə, arxivi əl ilə idxal edin.
- Onlayn funksiyalar üçüncü tərəf xidmətlərindən asılıdır və əlçatan olmaya bilər.
- Ekran görüntüləri inkişaf quruluşundandır və cari buraxılışa tam uyğun gəlməyə bilər.

---

<a id="project-lineage"></a>
## Layihə nəsli

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

### Əlaqədar layihələr

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Töhfə vermək

Səhv hesabatları və PR-lər qəbul edilir. Problemi bildirərkən aşağıdakıları daxil edin:

- cihaz modeli və iOS/iPadOS versiyası
- Witch Launcher versiyası
- renderer və Minecraft versiyası
- mod yükləyicisi və quraşdırılmış modların siyahısı
- çoxalmaq üçün addımlar
- müvafiq jurnal və ya qəza hesabatı

Zəhmət olmasa, imza sertifikatları, təminat profilləri, API açarları və ya digər sirləri öhdəsinə götürməyin.

---

<a id="credits"></a>
## Kreditlər

**Witch Launcher** **DuyAnh662 (Za_d626)** tərəfindən saxlanılır.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream və icma

Witch Launcher və onun yuxarı layihələri bir çox töhfə verənlərin əməyi əsasında qurulur, o cümlədən:

- **@crystall1nedev** — Amethyst layihə meneceri və iOS port tərtibçisi
- **@khanhduytran0** — iOS port tərtibçisi
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Layihəsi, Khronos Qrupu, Mesa Layihəsi, PojavLauncher Komandası, Mozilla və Minecraft icmasına əlavə təşəkkürlər.

[MCHeads](https://mc-heads.net)-a Minecraft avatar xidmətləri təqdim etdiyinə görə xüsusi təşəkkürlər.

Tam üçüncü tərəf komponenti və lisenziya siyahısı [`credits.md`](../../credits.md)-də mövcuddur.

---

<a id="license"></a>
## Lisenziya

Witch Launcher, [`credits.md`](../../credits.md)-də sadalanan üçüncü tərəf komponentlərinin lisenziyaları və müəllif hüquqları tələblərinə uyğun olaraq **GNU General Public License v3.0** altında paylanır.

Tam lisenziya mətni üçün [`LICENSE`](../../LICENSE) baxın.

---

<p align="center">
<sub>Minecraft Mojang Studios şirkətinin ticarət nişanıdır. Witch Launcher Mojang Studios, Microsoft və ya Amethyst layihəsi ilə əlaqəli deyil.</sub>
</p>
