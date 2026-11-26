<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition, iPhone ve iPad.</strong><br> üzerinde
DuyAnh662 (Za_d626) tarafından sürdürülen, topluluk tarafından oluşturulmuş Amethyst iOS ve iPadOS çatalı.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Özellikler](#features) · [Ekran görüntüleri](#screenshots) · [Gereksinimler](#requirements) · [Kurulum](#installation) · [Diller](#languages) · [Krediler](#credits) · [Lisans](#license)

<details>
<summary><strong>Diller</strong></summary>

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
## Hakkında

**Witch Launcher**, **Minecraft: Java Edition**'ü iPhone ve iPad'e getiren, [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS)'ın bağımsız, topluluk tarafından sürdürülen bir çatalıdır. Dokunma öncelikli başlatıcı kullanıcı arayüzünü tam bir Java çalışma zamanı yöneticisi, LWJGL ve Metal, MoltenVK ve OpenGL çeviri katmanları etrafında oluşturulmuş bir grafik yığınıyla birleştirir.

Witch, [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) topluluğunun, Amethyst-iOS ve Amethyst-iOS-25'ün çalışmaları üzerine inşa edilmiştir. Bağımsız bir projedir ve Mojang Studios, Microsoft veya upstream Amethyst ekibine bağlı değildir.

> **Mevcut sürüm:** 0.0.4 · Sürüm notları için bkz. [`news.md`](../../news.md).

---

<a id="features"></a>
## Özellikler

### Minecraft ve modlar

- Erken Beta sürümlerinden en son anlık görüntülere kadar çoğu **Minecraft: Java Edition** sürümünü çalıştırır.
- **Vanilya, Fabric, Quilt, Forge, NeoForge ve OptiFine**'i destekler.
- Kendi ayarları, modları, gölgelendiricileri, kaynak paketleri ve dünyalarıyla yalıtılmış **oyun profilleri** oluşturun.
- Başlatıcıdan ayrılmadan **Modrinth ve CurseForge** içeriğine göz atın ve yükleyin:
  - modlar
  - mod paketleri
  - gölgelendirici paketleri
  - kaynak paketleri
  - macera haritaları ve dünyalar
- Kaynağın sağladığı mod bağımlılıklarını çözümleyin ve yükleyin.
- Forge/NeoForge yükleyici JAR'larını içe aktarın ve Fabric/Quilt yükleyicileri doğrudan sürüm seçiciden yükleyin.

### Grafikler ve performans

- **Ayarlar → Oluşturucu ve Görüntüleme**'den birden fazla oluşturucu arasında geçiş yapın:
  - **gl4es** — OpenGL 2.1 uyumluluk yolu
  - **ANGLE** — OpenGL ES ila Metal veya Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, deneysel
  - **Zink** — OpenGL 4.1 ila Mesa 25 ve MoltenVK
  - **LTW** — OpenGL 3.3 ila OpenGL ES/Metal, Minecraft 1.17+, deneysel
  - **TGLMT** — OpenGL 4.6 Temel ila Metal, A11 Bionic veya daha yenisi
- Modern gölgelendirici tabanlı kurulumlar için **Sodium ve Iris desteğiyle TGLMT**.
- Harekete Uyarlanabilir GPU (MADI) ve Kamera 3D Yeniden Projeksiyon modlarıyla **Çerçeve Oluşturma**, zamansal enterpolasyon ve tahmine dayalı ekstrapolasyon dahil.
- Çözünürlük ölçeklendirme, maksimum kare hızı, FSR 1.0 ölçeklendirme, GLSL gölgelendirici önbellekleri ve oluşturucu başına ayarlama.
- Yapılandırılabilir FPS, CPU, GPU, RAM, sıcaklık, pil, saat ve kare oluşturma FPS widget'larına sahip Performans HUD'u.
- Grafiklerle yerleşik performans kaydı, PNG/PDF dışa aktarma ve paylaşım.

### Kontroller

- Tamamen özelleştirilebilir ekran kontrol düzenleri, düğme boyutları ve şeffaflık.
- **Klavye ve fare** desteği, sanal fare ve ayarlanabilir işaretçi hızı dahil.
- Yapılandırılabilir düzen ve hassasiyetle **Oyun kumandası** desteği.
- Ayarlanabilir hassasiyet ve eksen çevirme ile hedefleme yapan **Jiroskop**.
- Fare, kaydırma ve kısayol çubuğu hareketleri.
- İsteğe bağlı davranış: Blokları yerleştirmek için dokunun, blokları kırmak için basılı tutun.
- Tutulan öğeyi ikinci elinize geçirmek için kısayol çubuğuna iki kez dokunun.
- Kaydırılabilir sıcak çubuk ve ayarlanabilir uzun basma zamanlaması.

### Başlatıcı ve hesaplar

- **Microsoft**, **yerel/çevrimdışı**, **demo** ve **Ely.by** hesap desteği.
- **Java 8, 17, 21 ve 25** çalışma zamanlarını yönetin, bunları uygulama içinden indirin veya kendinizinkini içe aktarın.
- LWJGL sürümlerini seçin ve JVM bağımsız değişkenlerini, ortam değişkenlerini ve bellek ayırmayı ayarlayın.
- Sınırlı belleğe sahip cihazlar için otomatik RAM yönetimi.
- Temalar, vurgu renkleri, bulanıklaştırma, kenarlıklar, köşe yarıçapı, özel başlatıcı yazı tipleri ve uygulama simgeleri.
- Oyun içi **F3 cihaz bilgileri**: cihaz çipi, iOS sürümü, başlatıcı adı/versiyonu, yapı numarası ve yapı türü.
- Gelişmiş kurulumlar için isteğe bağlı **Witch Sunucu**, CurseForge ve AI entegrasyonları.
- Sağdan sola dil paketleri ve eğlenceli yerel ayarlar dahil **52 uygulama içi dil**.

---

<a id="screenshots"></a>
## Ekran görüntüleri

Witch Launcher 0.0.4'ün geliştirme yapısından ekran görüntüleri. Arayüz versiyonlar ve temalar arasında değişebilir.

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
## Gereksinimler

| Gereksinim | Ayrıntılar |
|---|---|
| **Cihaz** | iPhone veya iPad, arm64 işlemcili ve Metal destekli |
| **Sistem** | iOS veya iPadOS **14.0 veya daha yenisi** |
| **JIT** | Gerekli. JIT ila StikDebug, SideStore, TrollStore veya jailbreakli kurulumu etkinleştirin |
| **Hesap** | Resmi indirmeler için Minecraft'e sahip bir Microsoft hesabı; yerel ve demo modları da mevcuttur |
| **Depolama** | Başlatıcı için alan, Java çalışma süreleri, oyun sürümleri, modlar ve dünyalar |
| **Ağ** | Oturum açma, sürüm indirme, içerik tarayıcı ve isteğe bağlı çevrimiçi hizmetler için gereklidir |

Witch, Minecraft oyun dosyalarını **içermez**. Oyun dosyaları, uygun bir hesapta oturum açıldıktan sonra başlatıcı aracılığıyla indirilir.

### JIT notları

Minecraft: Java Edition için JIT gerekiyor ve Witch bu olmadan oyunu başlatamaz.

- **SideStore / AltStore tarzı kurulumlar:** Witch için JIT'yi etkinleştirin ve gerekli VPN/hata ayıklayıcı bağlantısını aktif tutun. Uygulama içi mesaj **LocalDevVPN** ve `CS_DEBUGGED`'a atıfta bulunur.
- **StikDebug:** StikDebug'yi Witch'a ekleyin ve JIT'yi etkinleştirin. **iOS 26/27** tarihinde, StikDebug oyun çalışırken bağlı kalmalıdır. Gerektiğinde `UniversalJIT26.js` panoya kopyalanır.
- **TrollStore:** Witch JIT'yi beklemeye devam ederse TrollStore'te **URL Scheme**'yi etkinleştirin.
- **Jailbreak'li cihazlar:** tercih ettiğiniz JIT etkinleştiriciyi kullanın.
- Başlatıcı **JIT bekleniyor** ekranında kalırsa yeniden başlatmadan önce hata ayıklayıcı bağlantısını, VPN ve TrollStore URL Scheme ayarını kontrol edin.

JIT davranışı iOS sürümüne ve kurulum yöntemine bağlıdır. Sistem güncellemeleri mevcut JIT kurulumlarını bozabilir.

---

<a id="installation"></a>
## Kurulum

Cihazınız için Witch imzalanmış olmalıdır. Bu veri havuzu, sertifikaları veya önceden imzalanmış IPA'ları göndermez.

### Bir yapı kullan

1. [Geliştirme iş akışından](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) bir geliştirme derlemesi indirin veya güvendiğiniz bir kaynaktan imzalı bir derleme kullanın.
2. **SideStore**, **AltStore**, **TrollStore** veya tercih ettiğiniz yan yükleme yöntemiyle imzalayın ve yükleyin.
3. Oyunu başlatmadan önce yukarıda açıklandığı gibi JIT'i etkinleştirin.

TrollStore yapıları ek yetkiler kullanır ve normal bir yandan yükleme imzalayanla kurulmamalıdır.

### Kaynaktan derle

Witch'ın derlenmesi için macOS'nin Xcode komut satırı araçlarıyla, iOS SDK 14.0 veya daha yenisinin, CMake, JDK 8, `ldid`, `wget`, `zip` ve Git'in kullanılması gerekir.

```bash
git klonu --özyinelemeli https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Paketlenmiş yapılar `artifacts/`'e yazılır.

Bunun yerine TrollStore paketi oluşturmak için:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Oluşturucu kaynak bağlantıları ve derleme notları için bkz. [`note.md`](../../note.md).

---

<a id="languages"></a>
## Diller

Witch Launcher **52 dil paketi** ile birlikte gelir. **Ayarlar → Genel → Dil**'i açın ve bir dil seçin veya cihazın dilini takip etmek için **Otomatik**'i kullanın.

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

Uygulama **52 dil paketinin** tamamını gönderir. README çevirileri İngilizce dahil **52 dilin tümü** için mevcuttur.

Bazı çeviriler makine desteklidir ve garip teknik terimler içerebilir. Düzeltmeler memnuniyetle karşılanır.

Bu README'nin kaynak dili İngilizcedir. Yerelleştirilmiş README'lere bu sayfanın üst kısmındaki dil seçiciden ve [`docs/readme/`](./) dizininden ulaşılabilir.

---

<a id="notes-and-limitations"></a>
## Notlar ve sınırlamalar

- **JIT zorunludur.** Çalışan bir JIT kurulumu olmadan Minecraft başlatılmayacaktır.
- **iOS 26/27 JIT hassastır.** StikDebug bağlı kalmalıdır ve gelecekteki işletim sistemi güncellemeleri, neyin çalıştığını değiştirebilir.
- **Deneysel** olarak işaretlenen oluşturucular çökebilir veya hatalı şekilde oluşturulabilir. Emin değilseniz **Otomatik** ile başlayın.
- **Çerçeve Oluşturma**, MoltenVK oluşturucuyu ve Metal bilgi işlem desteğini gerektirir. Pil kullanımını ve cihaz sıcaklığını artırabilir.
- Bazı modlar, mod paketleri, gölgelendiriciler ve dünyalar belirli bir Minecraft sürümü, yükleyici, oluşturucu veya ek bellek gerektirebilir.
- CurseForge mod paketleri `manifest.json`'u kullanır; Bir paket için tek dokunuşla kurulum mevcut değilse arşivi manuel olarak içe aktarın.
- Çevrimiçi özellikler üçüncü taraf hizmetlerine bağlıdır ve kullanılamayabilir.
- Ekran görüntüleri bir geliştirme sürümünden alınmıştır ve mevcut sürümle tam olarak eşleşmeyebilir.

---

<a id="project-lineage"></a>
## Proje kökeni

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

### İlgili projeler

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Katkıda Bulunmak

Hata raporları ve halkla ilişkiler memnuniyetle karşılanmaktadır. Bir sorunu bildirirken şunları ekleyin:

- cihaz modeli ve iOS/iPadOS sürümü
- Witch Launcher versiyonu
- oluşturucu ve Minecraft sürümü
- mod yükleyici ve yüklü modların listesi
- çoğaltma adımları
- ilgili günlük veya kilitlenme raporu

Lütfen imzalama sertifikalarını, ön hazırlık profillerini, API anahtarlarını veya diğer sırları teslim etmeyin.

---

<a id="credits"></a>
## Kredi

**Witch Launcher**, **DuyAnh662 (Za_d626)** tarafından korunur.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Yukarı akış ve topluluk

Witch Launcher ve onun yukarı yönlü projeleri, aşağıdakiler de dahil olmak üzere birçok katkıda bulunanın çalışmaları üzerine inşa edilmiştir:

- **@crystall1nedev** — Amethyst proje yöneticisi ve iOS bağlantı noktası geliştiricisi
- **@khanhduytran0** — iOS bağlantı noktası geliştiricisi
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla ve Minecraft topluluğuna ayrıca teşekkür ederiz.

Minecraft avatar hizmetlerini sağladığı için [MCHeads](https://mc-heads.net)'a özellikle teşekkür ederiz.

Üçüncü taraf bileşenin ve lisans listesinin tamamı [`credits.md`](../../credits.md) adresinde mevcuttur.

---

<a id="license"></a>
## Lisans

Witch Launcher, **GNU Genel Kamu Lisansı v3.0** kapsamında dağıtılır ve [`credits.md`](../../credits.md)'da listelenen üçüncü taraf bileşenlerin lisanslarına ve telif hakkı gereksinimlerine tabidir.

Lisans metninin tamamı için bkz. [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft, Mojang Studios'nin ticari markasıdır. Witch Launcher, Mojang Studios, Microsoft veya Amethyst projesiyle bağlantılı değildir.</sub>
</p>
