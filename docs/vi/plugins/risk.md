# Phân tích rủi ro và sandbox

Một chữ ký hợp lệ chứng minh gói còn nguyên vẹn, chứ không phải là vô hại. Vì vậy launcher đọc mọi plugin trước khi chạy, xác định **plugin sẽ thực thi gì** và chấm điểm hành vi đó.

Phân tích diễn ra cục bộ, tất định và ngoại tuyến. Gói plugin không được gửi đi đâu cả.

## Mức rủi ro {#levels}

| Mức | Huy hiệu | Ý nghĩa |
| --- | --- | --- |
| An toàn | Xanh | Không phát hiện gì ngoài cài đặt khai báo và dữ liệu theme |
| Cảnh báo | Vàng | Plugin xin nhiều hơn mức cần thiết, hoặc dùng các mẫu che giấu điều nó chạy |
| Nguy hiểm | Đỏ | Plugin nạp mã native vào tiến trình launcher, hoặc xin quyền mà sandbox không bảo vệ được |

Huy hiệu hiển thị trong danh sách plugin và ở màn hình chi tiết plugin. Bản phân tích nằm trong mục **Phân tích**: mức rủi ro, danh sách những gì launcher sẽ chạy, và từng phát hiện.

## Launcher phân tích gì {#analysis}

### Entrypoint

| Entrypoint | Phát hiện |
| --- | --- |
| `native` | **Nguy hiểm** — tệp được nạp vào tiến trình launcher bằng `dlopen`, không thể cách ly |
| `js` | Script được quét theo các mẫu bên dưới |
| `java` | **Cảnh báo** — có khai báo Java agent; nó được đăng ký nhưng không chạy trong bản này |
| `ui` | **Cảnh báo** — có khai báo root view tùy chỉnh |

### Quyền (permissions)

| Quyền | Phát hiện |
| --- | --- |
| `settings`, `theme`, `storage`, `logs` | Không phát hiện gì |
| `network`, `http`, `socket`, `download`, `clipboard`, `notification`, `webview` | **Cảnh báo** |
| `filesystem`, `shell`, `exec`, `process`, `keychain`, `camera`, `microphone`, `location`, `install`, `native`, `root` | **Nguy hiểm** |
| Bất kỳ quyền nào khác | **Cảnh báo** — launcher không biết quyền đó cho phép gì |

### Payload

| Payload | Phát hiện |
| --- | --- |
| Binary đã biên dịch (`.dylib`, `.so`, `.bundle`, `.exe`, …) | **Nguy hiểm** — binary mà launcher không thể soi |
| Script thực thi được (`.sh`, `.py`, `.jar`, …) | **Cảnh báo** — payload phụ mà launcher không bao giờ chạy |
| Hơn 512 tệp, hoặc bung ra hơn 16 MB | **Cảnh báo** |
| Hơn 1.024 tệp | **Nguy hiểm** |

### Mẫu trong JavaScript

| Mẫu | Phát hiện |
| --- | --- |
| `ObjC`, `WebKit`, `PHP`, `importScripts`, `import(` | **Nguy hiểm** — script với tới các đối tượng bridge của host, vốn không thuộc API plugin |
| `eval(`, `new Function(` | **Cảnh báo** — hành vi thật không nhìn thấy được trong tệp |
| `XMLHttpRequest`, `fetch(`, `WebSocket`, `EventSource`, `sendBeacon` | **Cảnh báo** — script tự nói chuyện với mạng |
| `localStorage`, `sessionStorage`, `indexedDB` | **Cảnh báo** — API lưu trữ của trình duyệt không có ý nghĩa trong launcher |

## Buổi tập trong sandbox {#rehearsal}

Các quy tắc ở trên được đọc từ manifest và từ các tệp. Launcher làm thêm một bước: sau khi chữ ký và checksum đã được xác minh, gói được **chạy thử trong một khoảnh khắc bên trong sandbox** và launcher quan sát nó làm gì.

| Thứ được tập thử | Cách thực hiện |
| --- | --- |
| Entrypoint JavaScript | Chạy trong `JSVirtualMachine` riêng với một bridge chỉ ghi nhận. Bridge trả lời mọi lời gọi và không ghi gì vào launcher |
| Các global nguy hiểm | `eval`, `Function`, `WebKit`, `ObjC`, `PHP`, API mạng và API lưu trữ được thay bằng bộ ghi nhận thay vì bị gỡ bỏ, nên hành vi vẫn nhìn thấy được |
| Payload native | Không thể thực thi an toàn, kể cả để biết nó làm gì. Thay vào đó khả năng của nó được đọc từ binary |

Những gì buổi tập báo cáo:

| Phát hiện | Mức |
| --- | --- |
| Script với tới `ObjC`, `WebKit` hoặc `PHP` | Nguy hiểm |
| Script cố dùng `eval` hoặc `Function` | Cảnh báo |
| Script cố ra mạng | Cảnh báo |
| Script cố dùng API lưu trữ web | Cảnh báo |
| Script không bao giờ kết thúc (ngân sách 3 giây) | Nguy hiểm |
| Script ném lỗi | Cảnh báo |
| Script đổi theme lúc khởi chạy | Cảnh báo |
| Binary mang API tiến trình, keychain, camera hoặc vị trí | Nguy hiểm |
| Binary mang API tệp hoặc mạng | Cảnh báo |

Buổi tập diễn ra trong lúc xác minh, trước khi gói được cài. Kết quả được lưu cùng plugin, nên màn hình plugin vẫn hiện gói đã làm gì khi được kiểm tra: các lời gọi nó thực hiện, những hành vi bị sandbox từ chối và các khả năng mà payload của nó mang.

> [!IMPORTANT] Buổi tập chạy code của một gói chưa được tin cậy bên trong tiến trình launcher. Script được cách ly trong virtual machine riêng và chỉ thấy một bridge ghi nhận, chữ ký và checksum đã được xác minh trước khi nó bắt đầu, và nó bị giới hạn trong ba giây. Một script không bao giờ kết thúc sẽ bị bỏ rơi, không phải chờ đợi.

## Cài đặt một plugin {#install}

| Rủi ro | Launcher làm gì |
| --- | --- |
| An toàn | Cài ngay sau khi qua xác minh. Không hỏi lại |
| Cảnh báo | Bảng cài đặt liệt kê mọi phát hiện và những gì launcher sẽ chạy. Người dùng xác nhận, plugin được sandbox |
| Nguy hiểm | Bảng cài đặt mang tính phá hủy và cho hai lựa chọn: **Cài đặt trong sandbox** (mã native vẫn bị chặn) hoặc **Cài đặt và cho chạy mã native**. Một plugin native không làm được gì nếu không có lựa chọn thứ hai, nên launcher không bao giờ tự chọn thay người dùng |

Trong mọi trường hợp kết quả phân tích được lưu cùng plugin, nên huy hiệu và các phát hiện vẫn hiện sau khi khởi động lại.

## Sandbox {#sandbox}

Một plugin không an toàn sẽ chạy trong sandbox của launcher. Sandbox được runtime cưỡng chế, không phải một lời hứa trong manifest.

| Quy tắc | Hành vi |
| --- | --- |
| Mã native bị chặn | Entrypoint `native` không bao giờ được đưa tới `dlopen`. Plugin vẫn cài và bật, nhưng phần native không chạy. Màn hình plugin sẽ ghi rõ điều đó |
| Script được cách ly | Plugin sandboxed chạy trong `JSVirtualMachine` riêng, không chạm tới đối tượng của plugin khác |
| Cửa thoát host bị gỡ | `eval`, `Function`, `WebKit`, `ObjC`, `PHP` và `importScripts` bị xóa khỏi global object trước khi script chạy |
| Đổi màu theme bị từ chối | `Witch.setThemeColor` và `Witch.reloadTheme` bị bỏ qua trong sandbox |
| Script không thể treo launcher | Script được đánh giá trên một queue riêng thay vì luồng chính, nên vòng lặp vô hạn không đóng băng launcher lúc khởi chạy |

Sandbox phủ JavaScript và cài đặt khai báo. Nó không phải là ranh giới bảo mật cho mã native — và đó chính là lý do mã native bị chặn ngay từ đầu.

## Tắt sandbox {#disable}

Màn hình plugin có nút **Sandbox**. Tắt sandbox sẽ hiện một bảng xác nhận, và với plugin bị xếp mức nguy hiểm thì bảng xác nhận đó mang tính phá hủy.

Tắt sandbox là cách duy nhất để plugin sandboxed nạp mã native. Chỉ làm điều đó với plugin bạn tự build, hoặc mã nguồn bạn đã đọc.

> [!IMPORTANT] Sandbox giới hạn mức hại một plugin gây ra; nó không làm cho plugin lạ trở nên đáng tin. Mã native là phần sandbox không thể kiềm chế, và vì thế nó bị chặn chứ không bị cách ly.

## Khuyến nghị {#recommendations}

- Đọc phần phân tích trước khi cài bất cứ thứ gì không phải màu xanh.
- Giữ sandbox bật trừ khi bạn có lý do rõ ràng để tắt.
- Ưu tiên plugin JavaScript và theme hơn plugin native.
- Thu hồi hoặc gỡ plugin không qua được xác minh registry.
