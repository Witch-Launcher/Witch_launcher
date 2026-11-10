# Java runtimes

## Tổng quan {#overview}

Runtime về tới thiết bị qua trình quản lý trong ứng dụng: **Cài đặt → Game → Java runtimes**, hoặc cùng màn hình đó được đề nghị ở lần chạy đầu. Một downloader đa luồng tải từng asset phát hành qua nhiều kết nối; mỗi hàng gánh download, update và delete riêng, và một bản cài hoàn tất áp dụng ngay — trình quản lý phiên bản đọc đường dẫn ở lần game chạy kế, không cần khởi động lại.

Các artifact được build và phát hành bởi kho [Witch-Launcher/JDK-Java_iOS](https://github.com/Witch-Launcher/JDK-Java_iOS) dưới một tag rolling, `runtimes-latest`, bị force-move ở mỗi lần build. Một manifest `runtimes.json` liệt kê từng tệp — phiên bản, URL và kích thước — với một release asset cho mỗi artifact thay vì một tệp nén lớn duy nhất. Launcher đọc manifest đó theo yêu cầu; URL của nó nằm trong tùy chọn `witch.runtime_manifest`, nên một mirror có thể thay thế.

```
{
  "jre8":     { "version": "1.8.0_472", "url": "https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/runtimes-latest/jre8-ios-aarch64.tar.xz" },
  "jre17":    { "version": "17.0.20",   "url": "…" },
  "jre21":    { "version": "21.0.8",    "url": "…" },
  "jre25":    { "version": "25.0.4",    "url": "…" },
  "lwjgl333": { "version": "3.3.3",     "url": "…" },
  "lwjgl336": { "version": "3.3.6",     "url": "…" },
  "lwjgl341": { "version": "3.4.1",     "url": "…" }
}
```

> [!IMPORTANT] Bản **slimmed** phát hành không kèm runtime để tiết kiệm bộ nhớ. Ở đó, tải trong ứng dụng không phải lựa chọn — một bản cài mới tải Java và LWJGL trước khi bất kỳ phiên bản nào khởi động.

## Phiên bản và LWJGL {#matrix}

Minecraft khai báo mức Java nó cần và Witch chọn runtime đã tải về cho khớp; trình quản lý cũng hiển thị vị trí của từng cái. Java 8, Java 25, LWJGL 3.3.3 và LWJGL 3.4.1 gắn huy hiệu **quan trọng** trong danh sách — hãy tải những cái đó trước khi bộ nhớ eo hẹp.

| Java | Minecraft hỗ trợ | Ghi chú |
| --- | --- | --- |
| **Java 8** | Beta releases cho tới 1.16 | Huy hiệu quan trọng — nền tảng cho các thiết lập legacy và modded |
| **Java 17** | 1.17 – 1.20.4 |  |
| **Java 21** | 1.20.5 – 1.21 |  |
| **Java 25** | Snapshot hiện hành và các bản phát hành mới hơn | Huy hiệu quan trọng |

Dòng LWJGL được chọn theo [profile game](getting-started.md), cạnh renderer và cài đặt JVM:

| LWJGL | Dùng thường gặp |
| --- | --- |
| **3.3.3** | Các phiên bản cũ và hầu hết stack modded — huy hiệu quan trọng |
| **3.3.6** | Các bản phát hành trung gian |
| **3.4.1** | Các phiên bản hiện đại và snapshot hiện hành — huy hiệu quan trọng |

## Nhập tùy chọn và thủ công {#import}

Cùng trình quản lý đó nhập được một archive bạn tự build. Giữ nguyên bố cục phát hành mà manifest công bố: tệp `release` ở gốc, một mục `.witch-mirror-mapping`, và `lib/server/libjvm.dylib` đã vá — archive về dạng `.tar.xz`, nên không cần nén lại. Một runtime được nhập được quản lý như bất kỳ cái nào tải về: hàng của nó trong Cài đặt có thể update hoặc delete riêng, không đụng tới phần còn lại.

Runtime nằm trong thư mục thư viện riêng của launcher và được dùng chung giữa các profile; mỗi profile tách riêng cài đặt của nó, nên mỗi cái trỏ tới mức Java và dòng LWJGL nó thích. Tệp không bao giờ được chép từ thư mục launcher khác — thư mục game chép tay làm hỏng trình quản lý phiên bản theo cách trông như một bug runtime.

## Bộ nhớ và tùy chọn JVM {#memory}

- **Auto RAM** — mặc định. Launcher dặn heap theo ngân sách bộ nhớ của chính thiết bị: điểm khởi đầu đúng đắn ở khắp nơi, và lựa chọn duy nhất hợp lý trên thiết bị ít RAM.
- **JVM arguments** — chỉnh theo từng profile cho các modpack đòi cờ cụ thể.
- **Biến môi trường** — trình chỉnh cho các cài đặt cấp runtime mà stack renderer đọc.

Chỉ nâng phần cấp phát khi một modpack chứng minh cần: JVM chia sẻ thiết bị với driver GPU, các tầng dịch và chính iOS, và một heap quá tay giết phiên nhanh hơn một heap nhỏ.

## Xử lý lỗi {#troubleshooting}

- Một hàng đứng hoặc lỗi giữa chừng — kiểm tra mạng, ưu tiên Wi-Fi không giới hạn dữ liệu, và thử tải lại từ chính hàng đó; asset thường nặng.
- Manifest không tới được — trỏ `witch.runtime_manifest` tới một mirror phục vụ `runtimes.json`, rồi mở lại trình quản lý.
- Danh sách phiên bản vẫn trống sau khi tải — archive có thể đã mất bố cục; nhập lại với `release` và `lib/server/libjvm.dylib` đúng vị trí.
- JVM tắt lúc khởi động với một thư viện còn thiếu — chuyển profile sang dòng LWJGL nó mong đợi; đi nhầm dòng làm hỏng phiên bản cũ trước tiên.

> [!NOTE] Bản cài áp dụng không cần khởi động lại. Nếu một runtime vừa tải có vẻ mất tăm, đóng rồi mở lại trình quản lý phiên bản trước khi cài lại bất cứ thứ gì.
