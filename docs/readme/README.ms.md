<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition pada iPhone dan iPad.</strong><br>
Garpu iOS dan iPadOS binaan komuniti Amethyst, diselenggara oleh DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Ciri](#features) · [Tangkapan skrin](#screenshots) · [Keperluan](#requirements) · [Pemasangan](#installation) · [Bahasa](#languages) · [Kredit](#credits) · [Lesen](#license)

<details>
<summary><strong>Bahasa</strong></summary>

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
## Tentang

**Witch Launcher** ialah garpu bebas yang diselenggara oleh komuniti [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) yang membawa **Minecraft: Java Edition** kepada iPhone dan iPad. Ia menggabungkan UI pelancar sentuhan pertama dengan pengurus masa jalan Java penuh, LWJGL dan tindanan grafik yang dibina di sekitar lapisan terjemahan Metal, MoltenVK dan OpenGL.

Witch dibina atas kerja [Boardwalk](https://github.com/zhuowei/Boardwalk), komuniti [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS, dan Amethyst-iOS-25. Ia adalah projek bebas dan tidak bergabung dengan Mojang Studios, Microsoft, atau pasukan Amethyst huluan.

> **Versi semasa:** 0.0.4 · Lihat [`news.md`](../../news.md) untuk nota keluaran.

---

<a id="features"></a>
## Ciri-ciri

### Minecraft dan mod

- Menjalankan kebanyakan versi **Minecraft: Java Edition**, daripada keluaran Beta awal hingga syot kilat terkini.
- Menyokong **Vanila, Fabric, Quilt, Forge, NeoForge dan OptiFine**.
- Cipta **profil permainan** terpencil dengan tetapan, mod, shader, pek sumber dan dunia mereka sendiri.
- Semak imbas dan pasang kandungan daripada **Modrinth dan CurseForge** tanpa meninggalkan pelancar:
  - mod
  - modpacks
  - pek shader
  - pek sumber
  - peta pengembaraan dan dunia
- Selesaikan dan pasang kebergantungan mod di mana sumber menyediakannya.
- Import Forge/NeoForge JAR pemasang dan pasang Fabric/Quilt pemuat terus daripada pemilih versi.

### Grafik dan prestasi

- Beralih antara berbilang pemapar daripada **Tetapan → Penyampai & Paparan**:
  - **gl4es** — OpenGL 2.1 laluan keserasian
  - **ANGLE** — OpenGL ES hingga Metal atau Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, percubaan
  - **Zink** — OpenGL 4.1 hingga Mesa 25 dan MoltenVK
  - **LTW** — OpenGL 3.3 hingga OpenGL ES/Metal, Minecraft 1.17+, percubaan
  - **TGLMT** — OpenGL 4.6 Teras hingga Metal, A11 Bionic atau lebih baharu
- **TGLMT dengan sokongan Sodium dan Iris** untuk persediaan berasaskan shader moden.
- **Penjanaan Bingkai** dengan GPU Penyesuai Pergerakan (MADI) dan mod Projek Semula 3D Kamera, termasuk interpolasi temporal dan ekstrapolasi ramalan.
- Penskalaan resolusi, kadar bingkai maksimum, FSR 1.0 peningkatan, cache shader GLSL dan penalaan setiap pemapar.
- Prestasi HUD dengan FPS, CPU, GPU, RAM, suhu, bateri, jam dan widget FPS penjanaan bingkai yang boleh dikonfigurasikan.
- Rakaman prestasi terbina dalam dengan carta, PNG/PDF eksport dan perkongsian.

### Kawalan

- Reka letak kawalan pada skrin yang boleh disesuaikan sepenuhnya, saiz butang dan ketelusan.
- Sokongan **Papan kekunci dan tetikus**, termasuk tetikus maya dan kelajuan penunjuk boleh laras.
- Sokongan **Pengawal permainan** dengan reka letak dan sensitiviti yang boleh dikonfigurasikan.
- **Gyroskop** menyasar dengan kepekaan boleh laras dan penyongsangan paksi.
- Gerak isyarat tetikus, tatal dan bar panas.
- Tingkah laku pilihan: ketik untuk meletakkan blok, tahan untuk memecahkan blok.
- Ketik dua kali bar panas untuk menukar item yang dipegang ke luar tangan.
- Bar panas boleh luncur dan pemasaan tekan lama boleh laras.

### Pelancar dan akaun

- Sokongan akaun **Microsoft**, **tempatan/luar talian**, **demo** dan **Ely.by**.
- Urus masa jalan **Java 8, 17, 21 dan 25**, muat turun dalam apl atau import anda sendiri.
- Pilih versi LWJGL dan sesuaikan hujah JVM, pembolehubah persekitaran dan peruntukan memori.
- Pengurusan RAM automatik untuk peranti dengan memori terhad.
- Tema, warna aksen, kabur, jidar, jejari sudut, fon pelancar tersuai dan ikon apl.
- Dalam permainan **F3 maklumat peranti**: cip peranti, iOS versi, nama/versi pelancar, nombor binaan dan jenis binaan.
- Pilihan **Witch Pelayan**, CurseForge dan AI penyepaduan untuk tetapan lanjutan.
- **52 bahasa dalam apl**, termasuk pek bahasa kanan ke kiri dan tempat yang menyeronokkan.

---

<a id="screenshots"></a>
## Tangkapan skrin

Tangkapan skrin daripada binaan pembangunan Witch Launcher 0.0.4. Antara muka boleh bertukar antara versi dan tema.

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
## Keperluan

| Keperluan | Butiran |
|---|---|
| **Peranti** | iPhone atau iPad dengan pemproses arm64 dan sokongan Metal |
| **Sistem** | iOS atau iPadOS **14.0 atau lebih baharu** |
| **JIT** | Diperlukan. Dayakan JIT hingga StikDebug, SideStore, TrollStore, atau persediaan jailbreak |
| **Akaun** | Akaun Microsoft yang memiliki Minecraft untuk muat turun rasmi; mod tempatan dan demo juga tersedia |
| **Storan** | Ruang untuk pelancar, Java masa jalan, versi permainan, mod dan dunia |
| **Rangkaian** | Diperlukan untuk log masuk, muat turun versi, penyemak imbas kandungan dan perkhidmatan dalam talian pilihan |

Witch tidak **tidak** termasuk Minecraft fail permainan. Fail permainan dimuat turun melalui pelancar selepas log masuk ke akaun yang layak.

### JIT nota

Minecraft: Java Edition memerlukan JIT, dan Witch tidak boleh melancarkan permainan tanpanya.

- **SideStore / pemasangan gaya AltStore:** dayakan JIT untuk Witch dan pastikan sambungan VPN/debugger yang diperlukan aktif. Mesej dalam apl merujuk kepada **LocalDevVPN** dan `CS_DEBUGGED`.
- **StikDebug:** lampirkan StikDebug pada Witch dan dayakan JIT. Pada **iOS 26/27**, StikDebug mesti kekal melekat semasa permainan berjalan. `UniversalJIT26.js` disalin ke papan keratan apabila diperlukan.
- **TrollStore:** dayakan **URL Scheme** dalam TrollStore jika Witch terus menunggu JIT.
- **Peranti Jailbreak:** gunakan pemboleh JIT pilihan anda.
- Jika pelancar kekal pada skrin **Menunggu JIT**, semak sambungan penyahpepijat, tetapan VPN dan TrollStore URL Scheme sebelum melancarkan semula.

JIT tingkah laku bergantung pada versi iOS dan kaedah pemasangan. Kemas kini sistem boleh memecahkan persediaan JIT sedia ada.

---

<a id="installation"></a>
## Pemasangan

Witch mesti ditandatangani untuk peranti anda. Repositori ini tidak menghantar sijil atau IPA yang telah ditandatangani sebelumnya.

### Gunakan binaan

1. Muat turun binaan pembangunan daripada [aliran kerja pembangunan](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), atau gunakan binaan bertandatangan daripada sumber yang anda percayai.
2. Tandatangani dan pasangnya dengan **SideStore**, **AltStore**, **TrollStore** atau kaedah pemuatan sisi pilihan anda.
3. Dayakan JIT seperti yang diterangkan di atas sebelum melancarkan permainan.

TrollStore binaan menggunakan hak tambahan dan tidak boleh dipasang dengan penandatangan pemuatan sisi biasa.

### Bina daripada sumber

Menyusun Witch memerlukan macOS dengan Xcode alatan baris perintah, iOS SDK 14.0 atau lebih baru, CMake, JDK 8, `ldid`, `wget`, `zip` dan Git.

```bash
git clone --rekursif https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Binaan berpakej ditulis kepada `artifacts/`.

Untuk membina pakej TrollStore sebaliknya:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Untuk pautan sumber pemapar dan nota binaan, lihat [`note.md`](../../note.md).

---

<a id="languages"></a>
## Bahasa

Witch Launcher dihantar dengan **52 pek bahasa**. Buka **Tetapan → Umum → Bahasa** dan pilih bahasa, atau gunakan **Auto** untuk mengikuti bahasa peranti.

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

Apl menghantar semua **52 pek bahasa**. Terjemahan README tersedia untuk **semua 52 bahasa**, termasuk bahasa Inggeris.

Sesetengah terjemahan adalah dibantu mesin dan mungkin mengandungi istilah teknikal yang janggal. Pembetulan dialu-alukan.

Bahasa Inggeris ialah bahasa sumber untuk README ini. README yang disetempatkan tersedia daripada pemilih bahasa di bahagian atas halaman ini dan dalam direktori [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Nota dan batasan

- **JIT adalah wajib.** Tanpa persediaan JIT yang berfungsi, Minecraft tidak akan dilancarkan.
- **iOS 26/27 JIT rapuh.** StikDebug mesti kekal dilampirkan dan kemas kini OS masa hadapan mungkin mengubah perkara yang berfungsi.
- Penyampai yang ditandakan **percubaan** boleh ranap atau dipaparkan secara tidak betul. Mulakan dengan **Auto** jika anda tidak pasti.
- **Penjanaan Bingkai** memerlukan MoltenVK pemapar dan Metal sokongan pengiraan. Ia boleh meningkatkan penggunaan bateri dan suhu peranti.
- Sesetengah mod, modpack, shader dan dunia mungkin memerlukan versi Minecraft tertentu, pemuat, pemapar atau memori tambahan.
- CurseForge modpacks menggunakan `manifest.json`; jika pemasangan sekali ketik tidak tersedia untuk satu pek, import arkib secara manual.
- Ciri dalam talian bergantung pada perkhidmatan pihak ketiga dan mungkin tidak tersedia.
- Tangkapan skrin adalah daripada binaan pembangunan dan mungkin tidak sepadan dengan keluaran semasa dengan tepat.

---

<a id="project-lineage"></a>
## Keturunan projek

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

### Projek berkaitan

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Menyumbang

Laporan pepijat dan PR dialu-alukan. Apabila melaporkan masalah, sertakan:

- model peranti dan versi iOS/iPadOS
- Witch Launcher versi
- renderer dan versi Minecraft
- pemuat mod dan senarai mod yang dipasang
- langkah untuk membiak
- log atau laporan ranap sistem yang berkaitan

Tolong jangan menandatangani sijil, profil peruntukan, kunci API atau rahsia lain.

---

<a id="credits"></a>
## Kredit

**Witch Launcher** dikekalkan oleh **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Hulu dan masyarakat

Witch Launcher dan projek huluannya dibina atas kerja ramai penyumbang, termasuk:

- **@crystall1nedev** — Amethyst pengurus projek dan iOS pembangun pelabuhan
- **@khanhduytran0** — iOS pembangun pelabuhan
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Terima kasih tambahan kepada **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, Projek ANGLE, Kumpulan Khronos, Projek Mesa, Pasukan PojavLauncher, Mozilla dan komuniti Minecraft.

Terima kasih khas kepada [MCHeads](https://mc-heads.net) kerana menyediakan perkhidmatan avatar Minecraft.

Senarai komponen dan lesen pihak ketiga yang lengkap tersedia dalam [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lesen

Witch Launcher diedarkan di bawah **GNU General Public License v3.0**, tertakluk pada lesen dan keperluan hak cipta komponen pihak ketiga yang disenaraikan dalam [`credits.md`](../../credits.md).

Lihat [`LICENSE`](../../LICENSE) untuk teks lesen yang lengkap.

---

<p align="center">
<sub>Minecraft ialah tanda dagangan Mojang Studios. Witch Launcher tidak bergabung dengan Mojang Studios, Microsoft, atau projek Amethyst.</sub>
</p>
