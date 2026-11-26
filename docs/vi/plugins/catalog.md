# Danh mục plugin

Launcher có thể cài và cập nhật plugin thẳng từ một repository GitHub. Chỉ cần một repository hợp lệ là đủ: launcher đọc tệp danh mục từ đó, tra cứu các gói và ghim mọi lượt tải bằng mã băm.

## Yêu cầu về repository {#repository}

Repository được cấu hình sẽ được kiểm tra trước khi bất kỳ byte nào của gói được tải về.

| Yêu cầu | Lý do |
| --- | --- |
| Repository tồn tại | Sai tên repository phải báo lỗi rõ ràng, không phải cài im lặng rồi không có gì |
| Repository phải công khai | Repository riêng tư không thể được người dùng kiểm chứng |
| Repository không bị lưu trữ (archived) hoặc vô hiệu hóa | Repository đã lưu trữ bị đóng băng, không thể tin rằng nó còn phát hành cập nhật |
| `full_name` khớp với `owner/repo` đã cấu hình | Một chuyển hướng hay đổi tên không được âm thầm phục vụ nội dung khác |
| Nhánh mặc định có tệp danh mục | Danh mục là cửa vào duy nhất của repository |

Repository được cấu hình ở **Cài đặt → Mạng → Repository danh mục plugin** (`witch.plugins.repo`, `owner/repo`). Mặc định là `Witch-Launcher/Witch_plugin_catalog`. Đổi tên tệp danh mục bằng `witch.plugins.catalog_file` (mặc định `witch-plugins.json`).

Một repository plugin có thể làm luôn catalog của chính nó. [`examples/plugins/pe-buttons`](https://github.com/Ynnyny/witch-pe-buttons) làm đúng như vậy: trỏ cài đặt về `Ynnyny/witch-pe-buttons` là PE Buttons xuất hiện ở mục **Plugin có sẵn**.

## Tệp danh mục {#format}

```json
{
  "version": 1,
  "plugins": [
    {
      "id": "com.witch.aurora-ui",
      "name": "Aurora UI",
      "version": "1.2.0",
      "description": "Bộ theme mở rộng cho launcher",
      "author": "Witch Examples",
      "license": "MIT",
      "source": "https://github.com/owner/repo",
      "package": "packages/aurora-ui-1.2.0.plgw",
      "sha256": "b5361f0f9a9b0e4f2f2a1c0d9e8b7a6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f0a9b",
      "channel": "stable",
      "notes": "Thêm hai preset nữa"
    }
  ]
}
```

| Trường | Bắt buộc | Ý nghĩa |
| --- | --- | --- |
| `id` | Có | Phải khớp với `id` bên trong `witch-plugin.json`. Mục thiếu id sẽ bị bỏ qua |
| `version` | Có | Được so với phiên bản đã cài để biết có bản cập nhật không |
| `package` | Có | Đường dẫn tệp `.plgw` trong repository, hoặc một URL `https` tuyệt đối |
| `sha256` | Có | SHA-256 của tệp `.plgw` đã phát hành. Launcher từ chối gói có mã băm không khớp |
| `name` | Không | Hiện trong danh sách. Nếu thiếu thì dùng id |
| `description`, `author`, `license`, `source`, `notes` | Không | Hiện trong danh mục và bảng cài đặt |
| `channel` | Không | Nhãn kênh tùy ý của nhà phát hành |

Mục thiếu id, phiên bản, đường dẫn gói hoặc mã băm hợp lệ sẽ bị bỏ qua thay vì làm hỏng cả danh mục.

## Quy trình cập nhật {#flow}

1. **Kiểm tra repository.** GitHub xác nhận nó tồn tại, công khai và không bị lưu trữ.
2. **Đọc danh mục.** `witch-plugins.json` được lấy từ nhánh mặc định.
3. **So phiên bản.** Mục có phiên bản mới hơn bản đang cài sẽ được đề nghị cập nhật.
4. **Tải gói.** Chỉ nhận `https` và giới hạn 32 MB.
5. **Ghim lượt tải.** SHA-256 của tệp tải về phải bằng `sha256` trong danh mục. Tệp bị thay đổi bị từ chối trước khi giải nén.
6. **Xác minh cục bộ.** Chữ ký ES256, manifest checksum, tập tệp và giới hạn kích thước được kiểm tra y hệt tệp cục bộ.
7. **Phân tích rủi ro.** Launcher xác định plugin sẽ thực thi gì — xem [Phân tích rủi ro và sandbox](plugins/risk.md).
8. **Hỏi registry.** Chỉ build mà registry đã xác minh cho đúng hash này mới cài được.
9. **Cài đặt.** Plugin không có phát hiện nào được cài ngay. Plugin cần chú ý hoặc nguy hiểm sẽ được hiện trước, kèm mọi thứ nó sắp chạy, và người dùng tự quyết.

## Cập nhật plugin đã cài {#update}

Một bản cập nhật thay thế thư mục plugin nhưng giữ lại cấu hình hướng tới người dùng: cài đặt, cờ tính năng và trạng thái bật của bản cũ được mang sang. Bản cài cũ được chuyển sang bên trong trong lúc bản mới được đặt vào chỗ, và được trả lại nếu có gì hỏng — nên một bản cập nhật lỗi không bao giờ để lại plugin cài dở.

Phân tích rủi ro chạy lại cho bản mới. Một plugin trở nên nguy hiểm ở bản cập nhật sẽ được sandbox theo mặc định, kể cả khi bản cũ thì không.

## Xuất bản một danh mục {#publishing}

1. Build và ký gói theo [Xuất bản](plugins/publishing.md).
2. Chép tệp `.plgw` vào repository, ví dụ dưới `packages/`.
3. Thêm một mục vào `witch-plugins.json` với id, phiên bản và SHA-256 mà packer đã in ra.
4. Commit và push. Launcher lấy danh mục mới ở lần làm mới kế.

Danh mục chỉ là kênh phân phối, không bao giờ là điểm neo tin cậy. Một mục trong danh mục chỉ có thể phát hành gói vốn đã qua các bước xác minh chữ ký, checksum và registry.
