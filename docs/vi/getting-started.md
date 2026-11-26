# Bắt đầu

## Yêu cầu {#overview}

| Yêu cầu | Chi tiết |
| --- | --- |
| Thiết bị | iPhone hoặc iPad — arm64, hỗ trợ Metal |
| OS | iOS / iPadOS **14.0 trở lên**. Helper JIT tích hợp cần **17.4+** |
| JIT | **Bắt buộc.** Không có biên dịch just-in-time, runtime không khởi động — xem [hướng dẫn JIT](jit.md) |
| Tài khoản | Một tài khoản Microsoft sở hữu Minecraft Java Edition. Cũng hỗ trợ tài khoản local, demo và Ely.by |

> [!IMPORTANT] Witch Launcher không bao giờ đóng gói sẵn tệp game hay chứng chỉ Microsoft. Bạn luôn nhận được `.ipa` / `.tipa` từ GitHub releases và tự chọn cách ký bên dưới.

## Chọn phương án cài đặt {#install}

### SideStore / AltStore — cách chuẩn

1. Tải bản chuẩn hoặc bản slim — tệp `.ipa` trong mục [Tải về](https://witch-launcher.github.io/#download).
2. Sideload bằng SideStore hoặc AltStore.
3. Cho JIT, dùng kết nối VPN gắn kèm (tiến trình <kbd>CS_DEBUGGED</kbd> sống khỏe khi VPN được attach), hoặc chạy với **StikDebug**.

### TrollStore — hiệu năng sạch nhất

1. Lấy tệp `.tipa` từ releases.
2. Mở qua TrollStore. Entitlement hệ thống của nó tự lo phần JIT — không cần chuyển trang VPN.

### StikJIT tích hợp — iOS 17.4 trở lên

1. Cài [ứng dụng đồng hành LocalDevVPN](https://apps.apple.com/app/id6755608044).
2. Trong Cài đặt → Game → JIT, bật phương án **StikJIT tích hợp**.
3. Cung cấp tệp pairing developer-mode; Witch chạy helper JIT riêng với tệp đó. Chi tiết và xử lý lỗi nằm trong [hướng dẫn JIT](jit.md).

### Jailbreak

1. Cài `.ipa` qua trình quản lý gói bạn thấy phù hợp.
2. Trên thiết bị jailbreak, JIT có thể bật không cần VPN đồng hành — bật JIT enabler của jail và đặt Cài đặt → Game → JIT theo phương pháp nó cung cấp.

## Lần chạy đầu tiên {#first-launch}

1. **Cấp quyền JIT** — nếu băng đỏ báo “Waiting for JIT”, hãy làm phương án bạn chọn ở trên trước.
2. **Chọn một phiên bản** — danh sách trình quản lý phiên bản có thể trống cho tới khi một Java runtime được tải về. Witch tự tải Java 8 / 17 / 21 / 25 khi phiên bản cần.
3. **Thêm tài khoản** — Microsoft (chính thức), local (offline), demo hoặc Ely.by.
4. **Nhấn Play** — lần khởi động đầu tải tài nguyên game; chờ vài phút.

> [!NOTE] Bản **slimmed** không đóng gói runtime sẵn để tiết kiệm bộ nhớ. Nếu một phiên bản không khởi động được, kiểm tra game không bị sao chép từ thư mục launcher khác — dùng tính năng tải runtime trong ứng dụng thay thế.

## Kiểm tra JIT nhanh trước khi đi tiếp {#jit-check}

| Cài đặt | Phương pháp |
| --- | --- |
| SideStore / AltStore | Tự động → StikDebug hoặc gắn debugger qua VPN |
| TrollStore | Tự động → helper tích hợp hoặc URL scheme của TrollStore |
| iOS 17.4+ / không jailbreak | StikJIT tích hợp → tệp pairing + LocalDevVPN |
| Jailbroken | TrollStore hoặc debugger tùy chọn |

Ma trận phương pháp đầy đủ, hướng dẫn tệp pairing và bảng xử lý lỗi bảy dòng nằm ở trang [JIT & JIT tích hợp](jit.md).

## Bước tiếp theo {#next}

- [Java runtimes](runtimes.md) — Java 8 → 25, LWJGL 3.3.3 → 3.4.1, ghi chú bộ nhớ
- [Hệ thống plugin](plugins/system.md) — phần mở rộng `.plgw` có chữ ký
- [FAQ](https://witch-launcher.github.io/docs/#/faq) — những câu hỏi xuất hiện mỗi tuần
