<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition pada iPhone dan iPad.</strong><br>
Garpu iOS dan iPadOS buatan komunitas dari Amethyst, dikelola oleh DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Fitur](#features) · [Tangkapan Layar](#screenshots) · [Persyaratan](#requirements) · [Instalasi](#installation) · [Bahasa](#languages) · [Kredit](#credits) · [Lisensi](#license)

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

**Witch Launcher** adalah fork [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) independen yang dikelola komunitas yang membawa **Minecraft: Java Edition** ke iPhone dan iPad. Ini menggabungkan UI peluncur sentuh pertama dengan manajer runtime Java penuh, LWJGL, dan tumpukan grafis yang dibangun di sekitar lapisan terjemahan Metal, MoltenVK, dan OpenGL.

Witch dibangun di atas karya [Boardwalk](https://github.com/zhuowei/Boardwalk), komunitas [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS, dan Amethyst-iOS-25. Ini adalah proyek independen dan tidak berafiliasi dengan Mojang Studios, Microsoft, atau tim hulu Amethyst.

> **Versi saat ini:** 0.0.4 · Lihat [`news.md`](../../news.md) untuk catatan rilis.

---

<a id="features"></a>
## Fitur

### Minecraft dan mod

- Menjalankan sebagian besar versi **Minecraft: Java Edition**, mulai dari rilis Beta awal hingga snapshot terbaru.
- Mendukung **Vanila, Fabric, Quilt, Forge, NeoForge, dan OptiFine**.
- Buat **profil game** terisolasi dengan pengaturan, mod, shader, paket sumber daya, dan dunianya sendiri.
- Jelajahi dan instal konten dari **Modrinth dan CurseForge** tanpa meninggalkan peluncur:
  - mod
  - modpack
  - paket shader
  - paket sumber daya
  - peta petualangan dan dunia
- Selesaikan dan instal dependensi mod jika sumber menyediakannya.
- Impor JAR penginstal Forge/NeoForge dan instal pemuat Fabric/Quilt langsung dari pemilih versi.

### Grafik dan kinerja

- Beralih di antara beberapa perender dari **Pengaturan → Perender & Tampilan**:
  - **gl4es** — OpenGL jalur kompatibilitas 2.1
  - **ANGLE** — OpenGL ES hingga Metal atau Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimental
  - **Zink** — OpenGL 4.1 hingga Mesa 25 dan MoltenVK
  - **LTW** — OpenGL 3.3 hingga OpenGL ES/Metal, Minecraft 1.17+, eksperimental
  - **TGLMT** — OpenGL 4.6 Inti hingga Metal, A11 Bionic atau yang lebih baru
- **TGLMT dengan dukungan Sodium dan Iris** untuk pengaturan berbasis shader modern.
- **Pembuatan Bingkai** dengan GPU Adaptif Gerakan (MADI) dan mode Proyeksi Ulang 3D Kamera, termasuk interpolasi temporal dan ekstrapolasi prediktif.
- Penskalaan resolusi, kecepatan bingkai maksimum, peningkatan FSR 1.0, cache shader GLSL, dan penyetelan per perender.
- Performa HUD dengan widget FPS, CPU, GPU, RAM, suhu, baterai, jam, dan pembuatan bingkai yang dapat dikonfigurasi.
- Perekaman kinerja bawaan dengan grafik, PNG/PDF ekspor, dan berbagi.

### Kontrol

- Tata letak kontrol di layar, ukuran tombol, dan transparansi yang dapat disesuaikan sepenuhnya.
- Dukungan **keyboard dan mouse**, termasuk mouse virtual dan kecepatan penunjuk yang dapat disesuaikan.
- Dukungan **Pengontrol game** dengan tata letak dan sensitivitas yang dapat dikonfigurasi.
- **Giroskop** membidik dengan sensitivitas yang dapat disesuaikan dan inversi sumbu.
- Gerakan mouse, gulir, dan hotbar.
- Perilaku opsional: ketuk untuk menempatkan balok, tahan untuk memecahkan balok.
- Ketuk dua kali hotbar untuk menukar item yang disimpan ke dalam barang yang sudah tidak ada lagi.
- Hotbar yang dapat digeser dan waktu tekan lama yang dapat disesuaikan.

### Peluncur dan akun

- **Microsoft**, **lokal/offline**, **demo**, dan **Ely.by** dukungan akun.
- Kelola runtime **Java 8, 17, 21, dan 25**, unduh dalam aplikasi, atau impor milik Anda sendiri.
- Pilih versi LWJGL dan sesuaikan argumen JVM, variabel lingkungan, dan alokasi memori.
- Manajemen RAM otomatis untuk perangkat dengan memori terbatas.
- Tema, warna aksen, blur, batas, radius sudut, font peluncur khusus, dan ikon aplikasi.
- **F3 informasi perangkat** dalam game: chip perangkat, versi iOS, nama/versi peluncur, nomor build, dan jenis build.
- Integrasi **Witch Server**, CurseForge, dan AI opsional untuk penyiapan tingkat lanjut.
- **52 bahasa dalam aplikasi**, termasuk paket bahasa dari kanan ke kiri dan bahasa lokal yang menyenangkan.

---

<a id="screenshots"></a>
## Tangkapan layar

Tangkapan layar dari pengembangan Witch Launcher 0.0.4. Antarmuka dapat berubah antara versi dan tema.

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
## Persyaratan

| Persyaratan | Detail |
|---|---|
| **Perangkat** | iPhone atau iPad dengan prosesor arm64 dan dukungan Metal |
| **Sistem** | iOS atau iPadOS **14.0 atau lebih baru** |
| **JIT** | Diperlukan. Aktifkan JIT melalui StikDebug, SideStore, TrollStore, atau pengaturan yang sudah di-jailbreak |
| **Akun** | Akun Microsoft yang memiliki Minecraft untuk unduhan resmi; mode lokal dan demo juga tersedia |
| **Penyimpanan** | Ruang untuk peluncur, Java runtime, versi game, mod, dan dunia |
| **Jaringan** | Diperlukan untuk masuk, pengunduhan versi, browser konten, dan layanan online opsional |

Witch **tidak** menyertakan Minecraft file game. File game diunduh melalui peluncur setelah masuk ke akun yang memenuhi syarat.

### JIT catatan

Minecraft: Java Edition membutuhkan JIT, dan Witch tidak dapat meluncurkan game tanpanya.

- **Penginstalan bergaya SideStore / AltStore:** aktifkan JIT untuk Witch dan pertahankan koneksi VPN/debugger yang diperlukan tetap aktif. Pesan dalam aplikasi mengacu pada **LocalDevVPN** dan `CS_DEBUGGED`.
- **StikDebug:** lampirkan StikDebug ke Witch dan aktifkan JIT. Pada **iOS 26/27**, StikDebug harus tetap terpasang selama game sedang berjalan. `UniversalJIT26.js` disalin ke clipboard bila diperlukan.
- **TrollStore:** aktifkan **URL Scheme** di TrollStore jika Witch terus menunggu JIT.
- **Perangkat yang sudah di-jailbreak:** gunakan pengaktif JIT pilihan Anda.
- Jika peluncur tetap berada di layar **Menunggu JIT**, periksa koneksi debugger, pengaturan VPN, dan TrollStore URL Scheme sebelum diluncurkan kembali.

Perilaku JIT bergantung pada versi iOS dan metode instalasi. Pembaruan sistem dapat merusak pengaturan JIT yang ada.

---

<a id="installation"></a>
## Instalasi

Witch harus ditandatangani untuk perangkat Anda. Repositori ini tidak mengirimkan sertifikat atau IPA yang telah ditandatangani sebelumnya.

### Gunakan bangunan

1. Unduh versi pengembangan dari [alur kerja pengembangan](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), atau gunakan versi yang ditandatangani dari sumber yang Anda percayai.
2. Masuk dan instal dengan **SideStore**, **AltStore**, **TrollStore**, atau metode sideload pilihan Anda.
3. Aktifkan JIT seperti dijelaskan di atas sebelum meluncurkan game.

TrollStore build menggunakan hak tambahan dan tidak boleh diinstal dengan penandatangan sideload normal.

### Bangun dari sumber

Kompilasi Witch memerlukan macOS dengan Xcode alat baris perintah, iOS SDK 14.0 atau lebih baru, CMake, JDK 8, `ldid`, `wget`, `zip`, dan Git.

```bash
git clone --https://github.com/Witch-Launcher/Witch_launcher.git rekursif
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Build yang dikemas ditulis ke `artifacts/`.

Untuk membuat paket TrollStore sebagai gantinya:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Untuk tautan sumber penyaji dan catatan pembuatan, lihat [`note.md`](../../note.md).

---

<a id="languages"></a>
## Bahasa

Witch Launcher dikirimkan dengan **52 paket bahasa**. Buka **Pengaturan → Umum → Bahasa** dan pilih bahasa, atau gunakan **Otomatis** untuk mengikuti bahasa perangkat.

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

Aplikasi ini mengirimkan semua **52 paket bahasa**. Terjemahan README tersedia untuk **semua 52 bahasa**, termasuk bahasa Inggris.

Beberapa terjemahan dibantu oleh mesin dan mungkin mengandung istilah teknis yang janggal. Koreksi dipersilakan.

Bahasa Inggris adalah bahasa sumber untuk README ini. README yang dilokalkan tersedia dari pemilih bahasa di bagian atas halaman ini dan di direktori [`docs/readme/`](./) direktori.

---

<a id="notes-and-limitations"></a>
## Catatan dan batasan

- **JIT adalah wajib.** Tanpa pengaturan JIT yang berfungsi, Minecraft tidak akan diluncurkan.
- **iOS 26/27 JIT bersifat rapuh.** StikDebug harus tetap terpasang, dan pembaruan OS di masa mendatang dapat mengubah cara kerjanya.
- Perender yang ditandai sebagai **eksperimental** dapat mogok atau tidak dirender dengan benar. Mulailah dengan **Otomatis** jika Anda tidak yakin.
- **Pembuatan Bingkai** memerlukan MoltenVK perender dan Metal dukungan komputasi. Ini dapat meningkatkan penggunaan baterai dan suhu perangkat.
- Beberapa mod, modpack, shader, dan dunia mungkin memerlukan versi Minecraft, pemuat, penyaji, atau memori tambahan tertentu.
- CurseForge modpack menggunakan `manifest.json`; jika instalasi satu ketukan tidak tersedia untuk paket, impor arsip secara manual.
- Fitur online bergantung pada layanan pihak ketiga dan mungkin tidak tersedia.
- Tangkapan layar berasal dari versi pengembangan dan mungkin tidak sama persis dengan rilis saat ini.

---

<a id="project-lineage"></a>
## Silsilah proyek

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

### Proyek terkait

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Berkontribusi

Laporan bug dan PR dipersilakan. Saat melaporkan masalah, sertakan:

- model perangkat dan versi iOS/iPadOS
- Witch Launcher versi
- penyaji dan versi Minecraft
- mod loader dan daftar mod yang diinstal
- langkah-langkah untuk mereproduksi
- log atau laporan kerusakan yang relevan

Harap jangan melakukan penandatanganan sertifikat, penyediaan profil, kunci API, atau rahasia lainnya.

---

<a id="credits"></a>
## Kredit

**Witch Launcher** dikelola oleh **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Hulu dan komunitas

Witch Launcher dan proyek-proyek hulunya dibangun berdasarkan karya banyak kontributor, termasuk:

- **@crystall1nedev** — Amethyst manajer proyek dan iOS pengembang port
- **@khanhduytran0** — iOS pengembang pelabuhan
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Terima kasih tambahan kepada **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, Proyek ANGLE, Grup Khronos, Proyek Mesa, Tim PojavLauncher, Mozilla, dan komunitas Minecraft.

Terima kasih khusus kepada [MCHeads](https://mc-heads.net) yang telah menyediakan layanan avatar Minecraft.

Komponen pihak ketiga lengkap dan daftar lisensi tersedia di [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lisensi

Witch Launcher didistribusikan di bawah **GNU General Public License v3.0**, tunduk pada persyaratan lisensi dan hak cipta dari komponen pihak ketiga yang tercantum dalam [`credits.md`](../../credits.md).

Lihat [`LICENSE`](../../LICENSE) untuk teks lisensi lengkap.

---

<p align="center">
<sub>Minecraft adalah merek dagang dari Mojang Studios. Witch Launcher tidak berafiliasi dengan Mojang Studios, Microsoft, atau proyek Amethyst.</sub>
</p>
