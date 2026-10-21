<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition trên iPhone và iPad.</strong><br>
Một nhánh iOS và iPadOS do cộng đồng xây dựng của Amethyst, được duy trì bởi DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Tính năng](#features) · [Ảnh chụp màn hình](#screenshots) · [Yêu cầu](#requirements) · [Cài đặt](#installation) · [Ngôn ngữ](#languages) · [Tín dụng](#credits) · [Giấy phép](#license)

<details>
<summary><strong>Ngôn ngữ</strong></summary>

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
## Giới thiệu

**Witch Launcher** là một nhánh phân nhánh độc lập, do cộng đồng duy trì của [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) đưa **Minecraft: Java Edition** lên iPhone và iPad. Nó kết hợp giao diện người dùng trình khởi chạy cảm ứng đầu tiên với trình quản lý thời gian chạy Java đầy đủ, LWJGL và ngăn xếp đồ họa được xây dựng xung quanh các lớp dịch Metal, MoltenVK và OpenGL.

Witch được xây dựng dựa trên công việc của [Boardwalk](https://github.com/zhuowei/Boardwalk), cộng đồng [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS và Amethyst-iOS-25. Đây là một dự án độc lập và không liên kết với Mojang Studios, Microsoft hoặc nhóm Amethyst thượng nguồn.

> **Phiên bản hiện tại:** 0.0.4 · Xem [`news.md`](../../news.md) để biết ghi chú phát hành.

---

<a id="features"></a>
## Tính năng

### Minecraft và các mod

- Chạy hầu hết các phiên bản **Minecraft: Java Edition**, từ bản Beta đầu tiên cho đến bản chụp nhanh mới nhất.
- Hỗ trợ **Vanilla, Fabric, Quilt, Forge, NeoForge và OptiFine**.
- Tạo **hồ sơ trò chơi** riêng biệt với cài đặt, mod, trình đổ bóng, gói tài nguyên và thế giới của riêng chúng.
- Duyệt và cài đặt nội dung từ **Modrinth và CurseForge** mà không cần rời khỏi trình khởi chạy:
  - mod
  - modpack
  - gói đổ bóng
  - gói tài nguyên
  - bản đồ phiêu lưu và thế giới
- Giải quyết và cài đặt các phần phụ thuộc của mod ở nơi nguồn cung cấp chúng.
- Nhập JAR trình cài đặt Forge/NeoForge và cài đặt trình tải Fabric/Quilt trực tiếp từ bộ chọn phiên bản.

### Đồ họa và hiệu suất

- Chuyển đổi giữa nhiều trình kết xuất từ **Cài đặt → Trình kết xuất & Hiển thị**:
  - **gl4es** — đường dẫn tương thích OpenGL 2.1
  - **ANGLE** — OpenGL ES đến Metal hoặc Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, thử nghiệm
  - **Zink** — OpenGL 4.1 đến Mesa 25 và MoltenVK
  - **LTW** — OpenGL 3.3 đến OpenGL ES/Metal, Minecraft 1.17+, thử nghiệm
  - **TGLMT** — OpenGL 4.6 Cốt lõi đến Metal, A11 Bionic hoặc mới hơn
- **TGLMT có hỗ trợ Sodium và Iris** cho các thiết lập dựa trên shader hiện đại.
- **Tạo khung hình** với chế độ GPU thích ứng với chuyển động (MADI) và Camera 3D Reproject, bao gồm phép nội suy theo thời gian và phép ngoại suy dự đoán.
- Chia tỷ lệ độ phân giải, tốc độ khung hình tối đa, nâng cấp FSR 1.0, bộ nhớ đệm đổ bóng GLSL và điều chỉnh trên mỗi trình kết xuất.
- HUD hiệu suất với FPS, CPU, GPU, RAM, nhiệt độ, pin, đồng hồ và các tiện ích FPS tạo khung có thể định cấu hình.
- Ghi lại hiệu suất tích hợp với biểu đồ, xuất PNG/PDF và chia sẻ.

### Điều khiển

- Bố cục điều khiển trên màn hình, kích thước nút và độ trong suốt có thể tùy chỉnh hoàn toàn.
- **Hỗ trợ bàn phím và chuột**, bao gồm chuột ảo và tốc độ con trỏ có thể điều chỉnh.
- **Hỗ trợ bộ điều khiển trò chơi** với bố cục và độ nhạy có thể định cấu hình.
- **Con quay hồi chuyển** nhắm mục tiêu có độ nhạy và khả năng đảo ngược trục có thể điều chỉnh được.
- Cử chỉ chuột, cuộn và thanh hotbar.
- Hành vi tùy chọn: chạm để đặt khối, giữ để phá vỡ khối.
- Nhấn đúp vào thanh nóng để hoán đổi vật phẩm đang giữ vào tay trái.
- Thanh hotbar có thể trượt và thời gian nhấn lâu có thể điều chỉnh được.

### Trình khởi chạy và tài khoản

- Hỗ trợ tài khoản **Microsoft**, **cục bộ/ngoại tuyến**, **demo** và **Ely.by**.
- Quản lý thời gian chạy **Java 8, 17, 21 và 25**, tải xuống trong ứng dụng hoặc nhập thời gian chạy của riêng bạn.
- Chọn phiên bản LWJGL và điều chỉnh các đối số JVM, biến môi trường và phân bổ bộ nhớ.
- Quản lý RAM tự động cho các thiết bị có bộ nhớ hạn chế.
- Chủ đề, màu nhấn, độ mờ, đường viền, bán kính góc, phông chữ trình khởi chạy tùy chỉnh và biểu tượng ứng dụng.
- **F3 thông tin thiết bị** trong trò chơi: chip thiết bị, phiên bản iOS, tên/phiên bản trình khởi chạy, số bản dựng và loại bản dựng.
- Tích hợp **Witch Máy chủ**, CurseForge và AI tùy chọn cho các thiết lập nâng cao.
- **52 ngôn ngữ trong ứng dụng**, bao gồm các gói ngôn ngữ từ phải sang trái và các ngôn ngữ thú vị.

---

<a id="screenshots"></a>
## Ảnh chụp màn hình

Ảnh chụp màn hình từ bản dựng phát triển của Witch Launcher 0.0.4. Giao diện có thể thay đổi giữa các phiên bản và chủ đề.

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
## Yêu cầu

| Yêu cầu | Chi tiết |
|---|---|
| **Thiết bị** | iPhone hoặc iPad với bộ xử lý arm64 và hỗ trợ Metal |
| **Hệ thống** | iOS hoặc iPadOS **14.0 hoặc mới hơn** |
| **JIT** | Yêu cầu. Kích hoạt JIT đến StikDebug, SideStore, TrollStore hoặc thiết lập đã bẻ khóa |
| **Tài khoản** | Tài khoản Microsoft sở hữu Minecraft để tải xuống chính thức; chế độ cục bộ và demo cũng có sẵn |
| **Lưu trữ** | Không gian cho trình khởi chạy, thời gian chạy Java, phiên bản trò chơi, bản mod và thế giới |
| **Mạng** | Cần thiết để đăng nhập, tải xuống phiên bản, trình duyệt nội dung và các dịch vụ trực tuyến tùy chọn |

Witch **không** bao gồm các tệp trò chơi Minecraft. Các tệp trò chơi được tải xuống thông qua trình khởi chạy sau khi đăng nhập vào tài khoản đủ điều kiện.

### ghi chú JIT

Minecraft: Java Edition cần JIT và Witch không thể khởi chạy trò chơi nếu không có nó.

- **SideStore / AltStore cài đặt kiểu:** bật JIT cho Witch và duy trì hoạt động kết nối VPN/trình gỡ lỗi bắt buộc. Thông báo trong ứng dụng đề cập đến **LocalDevVPN** và `CS_DEBUGGED`.
- **StikDebug:** đính kèm StikDebug vào Witch và kích hoạt JIT. Vào **iOS 26/27**, StikDebug phải được gắn trong khi trò chơi đang chạy. `UniversalJIT26.js` được sao chép vào bảng tạm khi cần.
- **TrollStore:** bật **URL Scheme** trong TrollStore nếu Witch tiếp tục chờ JIT.
- **Thiết bị đã bẻ khóa:** sử dụng trình kích hoạt JIT ưa thích của bạn.
- Nếu trình khởi chạy vẫn ở màn hình **Đang chờ JIT**, hãy kiểm tra kết nối trình gỡ lỗi, cài đặt VPN và TrollStore URL Scheme trước khi khởi chạy lại.

Hành vi JIT phụ thuộc vào phiên bản iOS và phương pháp cài đặt. Các bản cập nhật hệ thống có thể phá vỡ các thiết lập JIT hiện có.

---

<a id="installation"></a>
## Cài đặt

Witch phải được ký cho thiết bị của bạn. Kho lưu trữ này không gửi chứng chỉ hoặc IPA được ký trước.

### Sử dụng bản dựng

1. Tải xuống bản dựng phát triển từ [quy trình phát triển](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) hoặc sử dụng bản dựng đã ký từ nguồn mà bạn tin cậy.
2. Ký và cài đặt nó bằng **SideStore**, **AltStore**, **TrollStore** hoặc phương pháp tải phụ ưa thích của bạn.
3. Kích hoạt JIT như mô tả ở trên trước khi khởi chạy trò chơi.

Các bản dựng TrollStore sử dụng các quyền bổ sung và không nên cài đặt bằng trình ký hiệu tải bên ngoài thông thường.

### Xây dựng từ nguồn

Biên dịch Witch yêu cầu macOS với các công cụ dòng lệnh Xcode, iOS SDK 14.0 hoặc mới hơn, CMake, JDK 8, `ldid`, `wget`, `zip` và Git.

```bash
bản sao git --đệ quy https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Các bản dựng đóng gói được ghi vào `artifacts/`.

Thay vào đó, để xây dựng gói TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Để biết các liên kết nguồn của trình kết xuất và ghi chú bản dựng, hãy xem [`note.md`](../../note.md).

---

<a id="languages"></a>
## Ngôn ngữ

Witch Launcher đi kèm với **52 gói ngôn ngữ**. Mở **Cài đặt → Cài đặt chung → Ngôn ngữ** và chọn ngôn ngữ hoặc sử dụng **Tự động** để tuân theo ngôn ngữ của thiết bị.

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

Ứng dụng này cung cấp tất cả **52 gói ngôn ngữ**. Bản dịch README có sẵn cho **tất cả 52 ngôn ngữ**, bao gồm cả tiếng Anh.

Một số bản dịch được máy hỗ trợ và có thể chứa các thuật ngữ kỹ thuật khó hiểu. Sửa chữa được chào đón.

Tiếng Anh là ngôn ngữ nguồn của README này. README được bản địa hóa có sẵn từ bộ chọn ngôn ngữ ở đầu trang này và trong thư mục [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Lưu ý và hạn chế

- **JIT là bắt buộc.** Nếu không thiết lập JIT hoạt động, Minecraft sẽ không khởi chạy.
- **iOS 26/27 JIT rất dễ hỏng.** StikDebug phải được đính kèm và các bản cập nhật hệ điều hành trong tương lai có thể thay đổi những gì hoạt động.
- Trình kết xuất được đánh dấu là **thử nghiệm** có thể bị lỗi hoặc hiển thị không chính xác. Bắt đầu với **Tự động** nếu bạn không chắc chắn.
- **Tạo khung** yêu cầu trình kết xuất MoltenVK và hỗ trợ tính toán Metal. Nó có thể làm tăng mức sử dụng pin và nhiệt độ thiết bị.
- Một số mod, modpack, shader và thế giới có thể yêu cầu phiên bản Minecraft, trình tải, trình kết xuất hoặc bộ nhớ bổ sung cụ thể.
- CurseForge modpack sử dụng `manifest.json`; nếu cài đặt một chạm không có sẵn cho một gói, hãy nhập kho lưu trữ theo cách thủ công.
- Các tính năng trực tuyến phụ thuộc vào dịch vụ của bên thứ ba và có thể không khả dụng.
- Ảnh chụp màn hình là từ bản dựng đang phát triển và có thể không khớp chính xác với bản phát hành hiện tại.

---

<a id="project-lineage"></a>
## Dòng dự án

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

### Dự án liên quan

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Đóng góp

Báo cáo lỗi và PR đều được chào đón. Khi báo cáo một vấn đề, hãy bao gồm:

- kiểu thiết bị và phiên bản iOS/iPadOS
- phiên bản Witch Launcher
- trình kết xuất và phiên bản Minecraft
- trình tải mod và danh sách các mod đã cài đặt
- các bước tái tạo
- nhật ký liên quan hoặc báo cáo sự cố

Vui lòng không cam kết ký chứng chỉ, cung cấp hồ sơ, khóa API hoặc các bí mật khác.

---

<a id="credits"></a>
## Ghi công

**Witch Launcher** được duy trì bởi **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Thượng nguồn và cộng đồng

Witch Launcher và các dự án thượng nguồn của nó được xây dựng dựa trên công sức của nhiều người đóng góp, bao gồm:

- **@crystall1nedev** — người quản lý dự án Amethyst và nhà phát triển cổng iOS
- **@khanhduytran0** — nhà phát triển cổng iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Xin gửi lời cảm ơn sâu sắc hơn tới **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, Dự án ANGLE, Nhóm Khronos, Dự án Mesa, Nhóm PojavLauncher, Mozilla và cộng đồng Minecraft.

Đặc biệt cảm ơn [MCHeads](https://mc-heads.net) vì đã cung cấp dịch vụ hình đại diện Minecraft.

Danh sách giấy phép và thành phần đầy đủ của bên thứ ba có sẵn trong [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Giấy phép

Witch Launcher được phân phối theo **Giấy phép Công cộng GNU v3.0**, tuân theo các giấy phép và yêu cầu bản quyền của các thành phần bên thứ ba được liệt kê trong [`credits.md`](../../credits.md).

Xem [`LICENSE`](../../LICENSE) để biết văn bản giấy phép đầy đủ.

---

<p align="center">
<sub>Minecraft là thương hiệu của Mojang Studios. Witch Launcher không liên kết với Mojang Studios, Microsoft hoặc dự án Amethyst.</sub>
</p>
