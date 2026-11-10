# Hệ thống plugin

## Plugin là gì {#overview}

Một plugin là một archive có chữ ký với phần mở rộng `.plgw`. Nó có thể thêm cài đặt khai báo, màu theme, JavaScript chạy lúc khởi chạy và — ở nơi nền tảng cho phép thư viện động — mã native. Mọi gói phải mang một chữ ký ECDSA P-256 hợp lệ, một manifest checksum đầy đủ, một giấy phép nguồn mở và một URL mã nguồn công khai; launcher từ chối bất cứ thứ gì tới mà thiếu những thứ đó.

| Khả năng | Trạng thái |
| --- | --- |
| Cài đặt khai báo | Switches, trường văn bản, slider và picker render từ manifest. Giá trị nằm trong `state.json` của plugin |
| Màu theme | Một `theme.json` với cặp light / dark cho từng màu, phủ lên palette của launcher |
| JavaScript (`js`) | Được hỗ trợ. Cầu JavaScriptCore giới hạn với đối tượng `Witch` nhỏ — xem [Phát triển plugin](plugins/development.md) |
| Native (`native`) | Được hỗ trợ ở nơi launcher có thể nạp dylib chưa ký hoặc ký developer. ABI 2 có thể đăng ký một root view tùy chỉnh |
| UI (`ui`) | Để dành. Tệp theme được áp dụng; tiêm layout chưa triển khai |
| Java (`java`) | Chỉ đăng ký và ghi log — entrypoint được ghi ra log nhưng không chạy trong bản này |

Nên hôm nay một plugin có thể theme launcher, đẩy cài đặt riêng của mình ra, ghi vào launch log, chỉnh màu theme từ JavaScript, hoặc (khai báo native) chạy mã biên dịch trong tiến trình launcher. Nó chưa thể tiêm màn hình hay layout — runtime `ui` còn để dành — và không thể chạy mã Java.

## Cài đặt và quản lý {#install}

### Cài đặt từ tệp

1. Chép tệp `.plgw` lên thiết bị.
2. Mở Cài đặt → Plugins.
3. Nhấn <kbd>+</kbd> và chọn gói.
4. Chờ bước kiểm tra registry hoàn tất.
5. Xem lại chi tiết gói đã được xác minh.
6. Xác nhận cài và khởi động lại launcher.

Launcher xác minh chữ ký gói và từng checksum cục bộ, rồi hỏi Witch registry trước khi cài. Base URL của registry đọc từ **Cài đặt → Witch base URL** (`witch.proxy_base_url`). Một gói registry chưa xác minh không thể cài; nếu registry không tới được, lượt cài bị từ chối thay vì bỏ qua.

### Cài đặt từ liên kết

Một trang web có thể trao cho launcher một gói với `witch://install-plugin?url=…`. Scheme nhận HTTPS; HTTP chỉ được tôn trọng cho kiểm thử trên localhost. Một gói tải về vẫn qua cùng quy trình xác minh chữ ký và checksum như một tệp cục bộ — phương tiện vận chuyển không thay đổi gì quy trình kiểm duyệt.

### Cấu hình trong plugins.json

Cấu hình plugin hướng tới người dùng nằm trong `plugins.json` trong thư mục ứng dụng hiển thị của launcher (`POJAV_HOME/plugins.json`) — launch log in ra đúng đường dẫn. Tệp được tạo tự động và an toàn để sửa trong khi launcher đã dừng.

```
{
  "version": 1,
  "plugins": {
    "com.example.hello": {
      "enabled": true,
      "settings": {
        "accent": "#7c5cff"
      },
      "features": {
        "experimental-ui": false
      }
    }
  }
}
```

- `enabled` điều khiển plugin có được nạp lúc khởi chạy hay không.
- `settings` đè lên cài đặt thường của plugin.
- `features` phơi giá trị `feature.<name>` qua API cài đặt plugin, ví dụ `Witch.getSetting("feature.experimental-ui", true)`.

Một tệp JSON không hợp lệ được để nguyên và báo trong launch log; launcher hạ xuống trạng thái nội bộ của từng plugin.

> [!NOTE] Nếu một plugin hành xử xấu nhưng launcher không phát hiện ra lỗi, đặt `enabled` thành `false` trong `plugins.json` rồi khởi động lại. Safe mode là công cụ thô hơn: bỏ qua mọi plugin lúc khởi chạy.

### Safe mode

Safe mode ngăn mọi entrypoint plugin được nạp. Nó được bật thủ công bằng cách tạo `SAFE_MODE` trong thư mục dữ liệu ẩn của launcher (đường dẫn cũ `POJAV_HOME/SAFE_MODE` cũng được kiểm tra), hoặc tự động sau những lần lỗi runtime lặp lại — mỗi lần nạp lỗi tăng bộ đếm crash của plugin, và hai lần lỗi đẩy launcher vào safe mode.

## Các trạng thái xác minh {#verification}

Hai quyết định được giữ tách rời: một gói có hợp lệ về mặt mật mã — chữ ký và checksum — và nhà phát hành cùng đúng build này có được tin hay không. Registry trả lời vế thứ hai. Mọi plugin đã cài được rà lại ngay sau lần khởi chạy; một registry không tới được giữ trạng thái đã biết gần nhất, trong khi kết quả thu hồi hoặc từ chối vô hiệu hóa plugin.

| Trạng thái | Ý nghĩa | Launcher làm gì |
| --- | --- | --- |
| Unverified | Chữ ký và checksum hợp lệ, nhưng build chưa được registry xác minh | Hiển thị cảnh báo `developerSigned`. Nhấn **Tin khóa developer này** sẽ ghim ID khóa và khóa công khai cục bộ; khóa đã ghim được chấp nhận không cảnh báo |
| Verified | Registry đã xác minh đúng tập checksum và hash gói này | Cài sạch. Kết luận gắn với hash gói — một kết quả verified cho một hash khác được coi là **Invalid** |
| Revoked | Registry đã thu hồi build này | Vô hiệu hóa plugin ở lượt rà xác minh kế |
| Invalid | Registry đã từ chối build, hoặc gói không còn khớp các checksum đã xác minh | Từ chối cài, hoặc vô hiệu hóa plugin đã cài. Trước mỗi lần nạp, launcher rà lại chữ ký, ghim khóa ký, checksum, tập tệp và ngưỡng kích thước — một huy hiệu verified cũ không thể vượt qua can thiệp cục bộ |

> [!IMPORTANT] Một gói hợp lệ về mật mã và việc nó đáng tin là hai chuyện khác nhau. Xác minh bằng khóa công khai nhúng trong gói chỉ chứng minh danh sách checksum được ký bằng khóa riêng khớp — chứ không chứng minh ai sở hữu nó. Quyền sở hữu đến từ ghim khóa hoặc xác minh registry. Một gói tự ký có thể được soi cục bộ, nhưng phải được nộp lên và xác minh bởi registry trước khi launcher chịu cài nó.

## Thái độ bảo mật {#security}

Launcher kiểm tra gì, và khi nào:

| Kiểm tra | Hành vi |
| --- | --- |
| Chữ ký ES256 | Mọi gói được ký bằng ECDSA P-256 và SHA-256. Chữ ký trong `witch-plugin.sig` phủ đúng byte của `checksums.json`; khóa riêng không bao giờ nằm trong gói |
| Manifest checksum | `checksums.json` phải map từng tệp payload tới hash SHA-256 của nó. Tệp thừa bị từ chối lúc cài, trừ `checksums.json` và `witch-plugin.sig`; symbolic link và tệp không thường bị từ chối |
| Giới hạn tài nguyên | Gói vượt 32 MB, hơn 2,048 mục, hoặc bung ra hơn 128 MB bị từ chối. `state.json` của từng plugin bị chặn ở 1 MB |
| Ghim khóa | **Tin khóa developer này** ghim một ID khóa và khóa công khai vào tùy chọn cục bộ, để các gói sau của nhà phát hành đó không còn cảnh báo |
| Rà registry | Plugin đã cài được rà lại ngay sau khởi chạy. Registry không tới được giữ trạng thái đã biết gần nhất; kết quả thu hồi hoặc từ chối vô hiệu hóa plugin |
| Bộ đếm crash safe-mode | Mỗi lần nạp lỗi được đánh dấu theo plugin và tăng bộ đếm crash của nó. Hai lần lỗi bật safe mode tự động |

> [!IMPORTANT] Plugin native là loại mở rộng rủi ro nhất. Chúng chạy trong tiến trình launcher và không thể được sandbox một cách an toàn, và một crash native có thể tiêu launcher trước khi đường mã phục hồi kịp chạy. Dylib đã nạp ở lại cho tới hết tiến trình. Cài chỉ những mã bạn tin và có thể build lại từ mã nguồn đã công bố.

### Khuyến nghị

- Build từ mã nguồn và đối chiếu hash gói.
- Chỉ ghim khóa nhà phát hành sau khi đã soi mã nguồn.
- Ưu tiên plugin JavaScript và theme hơn plugin native.
- Thu hồi hoặc gỡ plugin không qua được xác minh registry.
