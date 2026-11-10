# JIT & JIT tích hợp

## Tổng quan {#overview}

Minecraft: Java Edition chạy trên một JVM biên dịch bytecode thành mã máy native trong lúc game chơi. iOS đánh dấu bộ nhớ ghi được là không thực thi được — quy tắc W^X — nên một tiến trình không thể tạo và chạy mã trong cùng những trang bộ nhớ đó. Trao một ngoại lệ chính là điều mọi phương pháp JIT ở đây làm: một tiến trình bên ngoài với entitlement phù hợp debug Witch và chuyển các trang bộ nhớ của nó thành thực thi được.

Thiếu nó, không gì khởi động. Launcher mở, phiên bản được chọn, và JVM dừng trước khi lớp đầu tiên tải — đó là lý do màn hình game mở cùng băng *Waiting for JIT* cho tới khi một phương pháp ổn định.

Các bản cài SideStore và AltStore có sẵn một lựa chọn: giữ VPN của chúng được attach và tiến trình <kbd>CS_DEBUGGED</kbd> sống khỏe suốt phiên. Thông báo trong ứng dụng nhắc đúng điều đó. Mọi con đường khác nằm trên trang này.

## Ma trận phương pháp {#methods}

**Cài đặt → Game → JIT** giữ công tắc. Script luôn là `UniversalJIT26.js` của riêng Witch; chỉ cơ chế attach thay đổi giữa các phương pháp.

| Phương pháp | Cách hoạt động | Yêu cầu |
| --- | --- | --- |
| **Tự động** — mặc định | Giải quyết lúc khởi chạy, theo thứ tự: TrollStore khi có entitlement JIT, rồi StikJIT tích hợp khi có tệp pairing, rồi StikDebug | Không — dùng thứ bản cài sẵn có |
| **StikJIT tích hợp** | Witch sinh `WitchJITHelper.appex` nhúng, thứ chạy StikJIT và attach vào launcher đang chạy qua dịch vụ RemotePairing của thiết bị | iOS 17.4+, một tệp remote pairing, LocalDevVPN đã kết nối, Developer Mode, bản cài có `get-task-allow` |
| **StikDebug** | Witch mở `stikdebug://enable-jit` kèm bundle ID và PID của mình; StikDebug attach và bật JIT | Đã cài StikDebug; trên iOS 26/27 nó phải giữ được attach |
| **Wait for Debugger** | Launcher giữ màn hình chờ tới khi một debugger bên ngoài — `lldb` hoặc một phiên IDE — attach | Một máy tính cùng mạng có `lldb` hoặc IDE hỗ trợ remote-debug |
| **TrollStore** | Witch trao yêu cầu cho TrollStore, với entitlement hệ thống mở các trang bộ nhớ | Bản cài `.tipa`; bật URL Scheme trong TrollStore |

> [!NOTE] Công tắc **Force JIT Script** chỉ bỏ qua bước phát hiện TXM. Nó không chọn script khác — script do developer định nghĩa luôn là `UniversalJIT26.js`.

## Tự động {#auto}

1. Giữ **Cài đặt → Game → JIT → JIT Method** ở **Tự động**.
2. Chạy game. Witch rà các phương pháp từ trên xuống: entitlement TrollStore thắng trước, rồi StikJIT tích hợp khi tệp pairing đã được nhập, rồi StikDebug.
3. Nếu nhánh bạn kỳ vọng không bao giờ vào, hãy sửa trực tiếp nhánh đó — thứ tự rà là một tìm kiếm, không phải một cấu trúc sửa chữa.

## StikJIT tích hợp {#built-in-jit}

Một tiến trình không thể tự debug chính nó một cách đồng bộ — attach debugger vào PID của chính nó gây deadlock. Đó là toàn bộ lý do của helper: `WitchJITHelper.appex` là một tiến trình riêng, nên Witch trao cho nó PID của launcher, tệp remote pairing, `UniversalJIT26.js` dạng base64, và cờ force-script. Helper gọi `StikJIT.enableJIT` và giữ attach trong khi script phục vụ các debug trap. Trên iOS 17/18, một lần attach và detach là đủ; trên iOS 26/27 nó phải giữ nguyên cả phiên.

```
Witch.app
└── PlugIns/
    └── WitchJITHelper.appex
```

1. **Ký với entitlement development** — SideStore, AltStore, Xcode hoặc trình ký nào giữ `get-task-allow`, và giữ nguyên `PlugIns/` khi ký lại archive.
2. **Cài LocalDevVPN** — [ứng dụng đồng hành](https://apps.apple.com/app/id6755608044) — và kết nối nó. Witch có thể mở giùm `localdevvpn://enable?scheme=witch` và LocalDevVPN trả về qua `witch://`. Một mạng Wi-Fi gần đó giúp đường hầm luôn tới được; trên di động, kết nối trước, rồi bật Chế độ máy bay và quay lại Witch.
3. **Bật Developer Mode** trong cài đặt hệ thống.
4. **Nhập một tệp remote pairing** trong **Cài đặt → Game → JIT** — xem [bên dưới](#developer-mode).
5. **Chọn StikJIT tích hợp** và chạy. Lần chuẩn bị đầu sẽ tải và mount Developer Disk Image, và màn hình thiết lập dò `10.7.0.1:62078` và `:49152` để báo đường hầm có tới được hay không.
6. **Giữ nó attach.** Trên iOS 26/27, helper giữ kết nối cho cả phiên.

Chọn StikJIT tích hợp trực tiếp không bao giờ lặng lẽ rơi về phương án khác: một thiết lập chưa đủ sẽ dừng lần khởi chạy với lỗi rõ ràng và lối tắt tới màn hình sửa nó.

> [!IMPORTANT] StikJIT tích hợp không dùng được trong LiveContainer, vốn không thể tạo phần helper extension bắt buộc — hãy dùng StikDebug ở đó. Nếu một trình ký đã cắt `PlugIns/`, phương pháp được báo không khả dụng và Tự động rơi về StikDebug; cài lại một bản còn giữ nguyên các extension.

### Phạm vi và bản quyền

Tính năng này chủ ý chỉ dành cho JIT và chỉ sideload — không an toàn cho App Store. Diện `NSExtension` nó dùng là private, nên một bản cập nhật iOS có thể thay đổi điều gì hoạt động. StikJIT là MPL-2.0, và mô hình helper đi theo phần tích hợp Built-in StikJIT của Husk (GPL-2.0-or-later); danh sách đầy đủ nằm ở trang [credits](https://witch-launcher.github.io/docs/#/credits).

Dành cho người build: helper được đóng gói sẵn dưới dạng slice arm64 trong `third_party/stikjit` và được stage bởi `make jit-helper` (rồi `make package`). Makefile bỏ qua helper và framework khi retag các tệp Mach-O về baseline iOS 14 — cả hai đều là iOS 17.4+ — và ký chúng trước binary chính.

## StikDebug {#stikdebug}

1. Cài **StikDebug** lên thiết bị.
2. Đặt phương pháp thành **StikDebug** — hoặc giữ **Tự động** trên bản cài không có entitlement TrollStore hay tệp pairing.
3. Chạy: Witch mở `stikdebug://enable-jit` mang theo bundle ID và PID của Witch. Khi script cần chuyển qua tay, `UniversalJIT26.js` được sao vào clipboard.
4. Giữ StikDebug attach trong khi chơi — trên iOS 26/27 là suốt phiên, không chỉ khung hình đầu.

## Wait for Debugger {#wait-debugger}

1. Đặt phương pháp thành **Wait for Debugger** và chạy — màn hình chờ sẽ thay thế.
2. Attach từ một máy tính: `lldb` với lệnh `process connect` remote, hoặc debugger nhúng trong IDE của bạn, qua mạng.
3. Khi attach hoàn tất, JIT vào và quá trình khởi động tiếp tục. Detach sau đó an toàn trên iOS 17/18; giữ attach trên iOS 26/27.

## TrollStore {#trollstore}

1. Cài bản `.tipa` qua TrollStore — không qua một trình ký sideload.
2. Giữ phương pháp ở **Tự động**: entitlement JIT tự giải quyết lúc khởi chạy, không cần chuyển trang VPN.
3. Nếu launcher vẫn chờ, mở mục Witch trong TrollStore và bật **URL Scheme**, rồi chạy lại.

## Developer Mode, tệp pairing và DDI {#developer-mode}

### Tạo tệp pairing

Tệp remote pairing được tạo từ một máy tính đáng tin: với Xcode hoặc `idevicesetup`, hoặc qua một AltStore source đã có sẵn. [Hướng dẫn pairing StikDebug](https://github.com/StikDebug/StikDebug-Guide/blob/main/pairing_file.md) đi con đường thủ công từng bước. Nhập kết quả trong **Cài đặt → Game → JIT** — hoặc chép vào thư mục `Documents` của Witch qua Finder hoặc ứng dụng Files, vì file sharing đã được bật.

### Quy tắc kiểm tra

Tệp được kiểm tra ngay khi nhập. `public_key` và `private_key` phải là giá trị `Data` 32 byte, và `identifier` một chuỗi khác rỗng — thứ khác bị từ chối kèm lý do hiển thị. Hai kiểu từ chối phổ biến: tệp là provisioning profile chứ không phải remote pairing plist, hoặc các key bị cắt cụt bởi một bản sao đã re-encode plist.

Witch giữ bản sao đã kiểm tra tại `Documents/StikJIT/pairingFile.plist`. Trong một thao tác, dữ liệu pairing chuyển tới helper dưới dạng `Data` trong yêu cầu extension, được ghi vào thư mục riêng `Library/StikJIT` của helper, và bị xóa khi yêu cầu kết thúc. Không bao giờ được ghi vào log.

### Developer Disk Image

Helper sở hữu bộ nhớ cache DDI trong thư mục `Library/StikJIT` của nó. Lần chuẩn bị đầu sẽ tải và mount ảnh personalized ba tệp, hoặc ảnh cryptex năm tệp trên iOS 26.4+. Một lần mount thành công tồn tại cho tới khi thiết bị khởi động lại. **Reset Developer Disk Image** xóa các tệp cache, và lần chuẩn bị kế tải lại chúng — biện pháp chuẩn sau một bản cập nhật iOS.

## Xử lý lỗi {#troubleshooting}

| Triệu chứng | Kiểm tra gì |
| --- | --- |
| “StikJIT tích hợp không khả dụng” | Xác nhận iOS 17.4+, helper vẫn còn trong `PlugIns/`, và bạn không nằm trong LiveContainer. Cài lại Witch nếu một lần ký đã cắt extension. |
| “Tệp pairing chưa được cung cấp” | Nhập lại tệp pairing trong **Cài đặt → Game → JIT**; chắc chắn đó là remote pairing plist, không phải provisioning profile. |
| “Không tới được” / timeout | Kết nối LocalDevVPN và ưu tiên Wi-Fi trước. Trên di động, kết nối VPN, rồi bật Chế độ máy bay và quay lại Witch. |
| Hoạt động một lần rồi kết nối bị reset | Một pairing mới hơn đã thay cái cũ — mỗi lần pairing cho nghỉ cái trước. Ghép nối thiết bị lại. |
| DDI cũ sau một bản cập nhật iOS | Dùng **Reset Developer Disk Image**, rồi chạy lại **Prepare JIT**. |
| JIT ngưng giữa game | Phần helper extension đã bị giết. Mở lại Witch và đừng tự detach debugger. |
| Game crash lúc khởi động | Đường JIT mirror chưa từng nhận được script sống. Xem `Documents/JITReport-latest.txt`, giữ helper attach và dùng runtime đóng gói sẵn. |

> [!WARNING] JIT trên iOS 26/27 mong manh là chủ ý: debugger phải giữ attach trong toàn bộ phiên game, và một bản cập nhật OS có thể đổi điều gì hoạt động bất kỳ lúc nào. Trên iOS 17/18, chỉ cần attach và detach.

> [!NOTE] Đang kẹt ở *Waiting for JIT*? Đi hết danh mục trước khi chạy lại — kết nối debugger còn hoạt động (StikDebug được attach hoặc phiên đã attach), LocalDevVPN đã kết nối và probe đường hầm xanh, TrollStore URL Scheme đã bật — rồi chạy lại.
