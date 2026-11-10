# Phát triển plugin

## Cấu trúc gói {#overview}

Một `.plgw` là một archive zip với manifest, danh sách checksum và một chữ ký ở gốc; phần còn lại là payload được liệt kê trong checksums. Mọi đường dẫn phải tương đối, nằm trong gói, và không được chứa `..`, backslash hay prefix tuyệt đối — symbolic link bị từ chối.

| Tệp | Vai trò |
| --- | --- |
| `witch-plugin.json` | Manifest bắt buộc — danh tính, giấy phép, nguồn, phiên bản API, entrypoints, và tùy chọn cài đặt cùng theme |
| `checksums.json` | Bắt buộc. Hash SHA-256 của từng tệp payload; launcher từ chối các tệp thừa bên ngoài danh sách checksum |
| `witch-plugin.sig` | Bắt buộc. Chữ ký ES256 phủ đúng byte của `checksums.json`, kèm ID khóa ký và khóa công khai |
| `main.js` | Entrypoint JavaScript được đặt tên bởi khóa `js` trong `entrypoints` |
| `libexample.dylib` | Entrypoint native được đặt tên bởi khóa `native`, export `witch_plugin_init` |
| `theme.json` | Màu theme, được trỏ tới bởi `ui.theme` hoặc trực tiếp bởi `ui` |
| `icon.png` / `banner` | Ảnh tùy chọn, khai báo bằng `icon` / `banner` trong manifest |

Một manifest tối thiểu — các trường bắt buộc cộng một entrypoint `js` — trông thế này:

```
{
  "id": "com.example.hello",
  "name": "Hello Witch",
  "version": "1.0.0",
  "license": "MIT",
  "source": "https://github.com/example/hello",
  "api": 1,
  "entrypoints": { "js": "main.js" }
}
```

Tệp theme map khóa màu sang giá trị hex. Một giá trị cũng có thể là đối tượng với cặp `light` và `dark`:

```
{
  "colors": {
    "amethyst_accent_color": { "light": "#7c5cff", "dark": "#9d7bff" },
    "amethyst_bg_color": "#0b0b12",
    "amethyst_text_color": "#ffffff",
    "amethyst_secondary_text_color": "#b7b7c9"
  }
}
```

## Đặc tả manifest {#manifest}

### Trường bắt buộc

| Trường | Quy tắc |
| --- | --- |
| `id` | Chữ cái thường, số, chấm, gạch dưới hoặc gạch ngang; phải khớp `^[a-z0-9][a-z0-9._-]{1,63}$` |
| `name` | Tên hiển thị khác rỗng |
| `version` | Các thành phần dạng số, ví dụ `1.0.0` hoặc `2.1.0-beta.1` |
| `license` | Định danh nguồn mở OSI/SPDX từ danh sách cho phép bên dưới |
| `source` | URL mã nguồn công khai `http` hoặc `https` |
| `api` | Phiên bản API plugin. Bản này hỗ trợ `1` |

### Trường tùy chọn

| Trường | Mục đích |
| --- | --- |
| `author` | Hiển thị trong bảng cài và màn chi tiết |
| `description` | Tóm tắt ngắn hiện trong danh sách plugin và màn chi tiết |
| `details` | Miêu tả dài hơn, để dành cho khung xem chi tiết |
| `icon` | Đường dẫn tương đối an toàn tới ảnh PNG hoặc JPEG |
| `banner` | Đường dẫn tương đối an toàn tới ảnh banner |
| `permissions` | Các quyền được khai báo, hiện mang tính thông tin |
| `settings` | Schema cài đặt khai báo |
| `entrypoints` | Các entrypoint runtime |
| `ui` | Một đường dẫn theme trực tiếp (vd `"theme.json"`), hoặc `{ "theme": "theme.json" }` |

### Danh sách giấy phép cho phép

Registry chỉ xác minh các gói khai báo một trong những định danh SPDX này và một URL HTTP(S) mã nguồn công khai. Đây là yêu cầu khả năng kiểm toán, không phải bảo đảm mật mã.

`MIT` · `Apache-2.0` · `BSD-2-Clause` · `BSD-3-Clause` · `ISC` · `MPL-2.0` · `GPL-2.0-only` · `GPL-2.0-or-later` · `GPL-3.0-only` · `GPL-3.0-or-later` · `LGPL-2.1-only` · `LGPL-2.1-or-later` · `LGPL-3.0-only` · `LGPL-3.0-or-later` · `AGPL-3.0-only` · `AGPL-3.0-or-later` · `EPL-2.0` · `CC0-1.0` · `Unlicense` · `Zlib`

### Cài đặt khai báo

`settings` khai báo các lựa chọn riêng của plugin; launcher render chúng và lưu giá trị theo từng plugin trong `state.json`. Bốn loại đầu vào được hỗ trợ:

| Loại | Trường thêm |
| --- | --- |
| `switch` | `default` boolean |
| `text` | `default`, tùy chọn `placeholder` |
| `slider` | `default`, `min`, `max` |
| `picker` | `default`, mảng `options` — chuỗi hoặc đối tượng `{ "key", "name" }` |

Mỗi mục mang `key`, `type`, `label` (chấp nhận `title` như một biệt danh) và tùy chọn `description`. Một picker trông như:

```
{
  "key": "accent",
  "type": "picker",
  "label": "Accent color",
  "description": "Applied on the next launch.",
  "default": "#7c5cff",
  "options": [
    { "key": "#7c5cff", "name": "Amethyst" },
    { "key": "#ff5c8a", "name": "Rose" }
  ]
}
```

### Entrypoints

| Khóa | Hành vi |
| --- | --- |
| `js` | Chạy lúc khởi chạy trong một context JavaScriptCore riêng |
| `native` | Chạy lúc khởi chạy ở nơi nạp được dylib; ABI 2 có thể đăng ký một root view controller tùy chỉnh |
| `java` | Được nhận diện và ghi log, nhưng không chạy trong bản này. Một plugin chỉ-Java không được coi là đang hoạt động |
| `ui` | Để dành — tệp theme được áp dụng, tiêm layout chưa triển khai |

> [!NOTE] Soi nhanh mức hỗ trợ runtime: `js` và `native` chạy, `ui` để dành cho một bản sau, còn `java` chỉ được ghi log. Thiết kế plugin quanh JavaScript và theme trong lúc này.

## Runtime JavaScript {#javascript}

JavaScript chạy trong một `JSContext` riêng cho từng plugin. Không có DOM và không có API mạng — đối tượng toàn cục `Witch` là toàn bộ cây cầu:

| API | Hành vi |
| --- | --- |
| `Witch.pluginID` | ID plugin hiện tại |
| `Witch.version` | Phiên bản plugin hiện tại |
| `Witch.log(message)` | Ghi một tin nhắn có prefix vào launcher log |
| `Witch.getSetting(key, fallback)` | Trả về giá trị đã lưu hoặc `fallback` |
| `Witch.setSetting(key, value)` | Lưu một cài đặt serialize được bằng JSON |
| `Witch.setThemeColor(key, hex)` | Lưu một màu theme và nạp lại theme |
| `Witch.reloadTheme()` | Áp dụng lại các màu theme |

```
const greeting = Witch.getSetting("greeting", "Hello");
Witch.log(greeting);
Witch.setThemeColor("amethyst_accent_color", "#7c5cff");
```

JavaScript chạy đồng bộ trong lúc launcher khởi động và phải trả lời nhanh; không có watchdog về thời gian thực thi, và không có quyền truy cập trực tiếp vào các view controller của launcher.

### Phản chiếu giá trị cài đặt

Cài đặt plugin nằm trong `state.json` của plugin và được phản chiếu tới `plugins.json` trong thư mục ứng dụng của launcher. Launcher trộn cấu hình tổng thể lúc khởi động, nên người dùng có thể tắt plugin hoặc đè thủ công từng cài đặt. Khóa dưới `features` được phơi ra thành cài đặt `feature.<name>` đọc qua `Witch.getSetting` hoặc native `get_setting`; giá trị có thể là chuỗi, số, boolean hoặc đối tượng JSON. Mảng `settings` trong manifest khai báo mặc định và các điều khiển UI, trong khi `plugins.json` giữ phần đè của người dùng.

### Quy tắc trộn theme

Màu theme trộn theo một thứ tự cố định. Màu accent do người dùng đặt trong cài đặt launcher thắng palette mặc định; trừ khi một theme plugin định nghĩa cùng khóa, cài đặt hệ thống giữ nguyên — một plugin đang bật mà định nghĩa màu đó sẽ có ưu tiên trên cài đặt hệ thống. Trong và xuyên giữa các plugin: màu tĩnh `theme.json` được áp trước, rồi các đè từ `Witch.setThemeColor` được trộn sau, và nếu nhiều plugin định nghĩa cùng khóa, plugin sau cùng theo thứ tự sắp xếp thắng.

Các khóa màu được hỗ trợ gồm `amethyst_accent_color`, `amethyst_bg_color`, `amethyst_card_bg_color`, `amethyst_text_color`, `amethyst_secondary_text_color`, `amethyst_sidebar_bg_color`, `amethyst_topbar_bg_color`, `amethyst_rightpanel_bg_color` và `amethyst_ui_border_color`.

## Runtime native {#native}

Một entrypoint native là một `.dylib` export `witch_plugin_init`, được gọi một lần lúc khởi chạy với bảng API của host. Mọi callback nhận `host->userdata`; launcher cấp một context cho từng plugin để cài đặt và cập nhật theme trỏ đúng plugin, và các lệnh host từ background thread được dẫn về main thread.

| Bề mặt ABI | Hành vi |
| --- | --- |
| `witch_plugin_init` | Export bắt buộc. Đối chiếu `host->abi_version` với `WITCH_PLUGIN_ABI_VERSION` và trả về `0` khi thành công; bất kỳ giá trị khác không nào ghi một lỗi runtime và bỏ qua plugin — thư viện ở lại cho tới hết vòng đời tiến trình |
| `host->userdata` | Context riêng cho mỗi plugin, trao cho từng callback |
| `host->log` | Ghi một tin nhắn có prefix vào launcher log |
| `host->get_setting` | Trả về cài đặt đã lưu; con trỏ hợp lệ tới lần `get_setting` kế trên cùng thread — hãy sao chép trước khi giữ |
| `host->set_root_view_factory` | ABI 2. Đăng ký một factory cung cấp root view của launcher |

```
#include "WitchPluginAPI.h"

static int plugin_init(const WitchPluginHostAPI *host) {
    host->log(host->userdata, "plugin started");
    return 0;
}

__attribute__((visibility("default")))
int witch_plugin_init(const WitchPluginHostAPI *host) {
    if (!host || host->abi_version != WITCH_PLUGIN_ABI_VERSION) return 1;
    return plugin_init(host);
}
```

### Root UI tùy chỉnh (ABI 2)

ABI 2 thêm `set_root_view_factory`. Một plugin native có thể thay root của launcher bằng một `UIViewController` tuân thủ `WitchRootHost`:

```
#import <UIKit/UIKit.h>

@interface ExampleRootViewController : UIViewController <WitchRootHost>
@end

static void *make_root(void *userdata) {
    return (__bridge_retained void *) [[ExampleRootViewController alloc] init];
}

static int plugin_init(const WitchPluginHostAPI *host) {
    host->set_root_view_factory(host->userdata, make_root);
    return 0;
}
```

Factory trả về một đối tượng retained; launcher nắm quyền sở hữu cho tới hết vòng đời của root. Chỉ factory đầu tiên được đăng ký trong một lần khởi chạy được dùng. Nếu plugin bị tắt, lỗi nạp, hoặc factory trả về một đối tượng không tuân thủ `WitchRootHost`, launcher giữ `AmethystRootViewController`. Một root tùy chỉnh tự lo bố cục của mình và phải dẫn hành động qua `coordinator` ở những chỗ launcher kỳ vọng hành vi native.

> [!NOTE] Plugin native chỉ nạp được trên những bản cài cho phép thư viện động chưa ký hoặc ký developer — trên SideStore và iOS nguyên bản, điều này có thể đòi một bypass JIT / dyld. Plugin JavaScript và theme không bao giờ cần nạp native.

## Đóng gói và đăng tải {#publishing}

### Tạo khóa

Gói được ký bằng ECDSA P-256 và SHA-256 (ES256). Sinh một cặp khóa và giữ khóa riêng offline; lệnh in khóa công khai base64 và ID khóa dẫn xuất.

```
python3 scripts/plugins/pack_plugin.py \
  --generate-key ./keys/example-private.pem \
  --key-id dev-example
```

### Đóng gói

Thư mục nguồn phải chứa `witch-plugin.json` ở gốc, và mọi entrypoint, icon, banner, tệp theme được trỏ tới phải tồn tại. Trình đóng gói ghi checksums xác định và ký `checksums.json`:

```
python3 scripts/plugins/pack_plugin.py \
  --source examples/plugins/hello \
  --private-key ./keys/example-private.pem \
  --key-id dev-example \
  --out ./hello-1.0.0.plgw
```

Nó in `artifact_sha256` (SHA-256 của `.plgw` cuối cùng), `checksums_sha256` (SHA-256 của `checksums.json` đã ký), và `public_key` cùng `key_id` cần cho việc nộp duyệt.

### Xác minh cục bộ

Một gói tự ký hoặc ký bên ngoài có thể được kiểm tra mà không cần registry:

```
python3 scripts/plugins/pack_plugin.py --verify ./hello-1.0.0.plgw
```

### Nộp tới registry

Nộp cả hai hash, khóa công khai và ID khóa tới registry worker:

```
curl -X POST https://witch-worker.vvvuduyanh2012.workers.dev/v1/plugins/submit \
  -H 'Content-Type: application/json' \
  -d '{
    "pluginId": "com.witch.example.hello",
    "version": "1.0.0",
    "name": "Hello Witch",
    "license": "MIT",
    "sourceUrl": "https://github.com/example/witch-hello-plugin",
    "artifactSha256": "b536...",
    "checksumsSha256": "efda...",
    "publicKey": "BGRZ...",
    "publisherKeyId": "dev-example"
  }'
```

Các trường bắt buộc: `pluginId`, `version`, `name`, `license`, `sourceUrl`, `artifactSha256`, `checksumsSha256`, `publicKey`, `publisherKeyId`. Máy chủ không tính hash nào — nó lưu các giá trị do nhà phát hành cung cấp để rà soát, nên trước khi được xác minh, hãy chắc URL nguồn công khai và khớp build nộp lên, giấy phép nằm trong danh sách cho phép, các hash, khóa công khai và ID khóa khớp gói, và không có hành vi native nào thiếu miêu tả. Bản nộp ở trạng thái `pending` cho tới khi một quản trị viên xác minh hoặc từ chối, và một phiên bản đã verified không thể bị ghi đè bởi một bản nộp sau — hãy phát hành một phiên bản mới thay thế.

### Tóm tắt API registry

| Đường | Hành vi |
| --- | --- |
| `GET /v1/plugins/verify` | Kiểm tra id, phiên bản, hash checksum và artifact, ID khóa. Trả về `verified`, `unverified`, `pending`, `rejected`, `revoked`, `invalid` hoặc `unavailable` |
| `GET /v1/plugins/list` | Chỉ trả về các hàng verified, không bị thu hồi |
| `POST /v1/plugins/submit` | Đăng ký một build pending cho rà soát |

Launcher đọc base registry từ **Cài đặt → Witch base URL** (`witch.proxy_base_url`); xác minh bị bỏ qua khi cài đặt đó rỗng. Nếu Supabase chưa được cấu hình trên máy chủ, `verify` trả `unavailable`, `list` trả danh sách rỗng, và các đường nộp trả lỗi.

### Rà soát admin và triển khai

Đường admin `GET /admin/plugins?status=pending` và các hành động theo phiên bản `/verify`, `/reject` và `/revoke` đòi header `X-Admin-Key` — `PLUGIN_ADMIN_KEY`, fallback về `ADMIN_PAGE_KEY`; nếu cả hai chưa được cấu hình, các đường trả `503` thay vì chạy không xác thực. Build bị thu hồi được launcher vô hiệu hóa ở lượt rà xác minh kế.

Tự host registry: áp `worker/supabase/migrations/007_plugin_registry.sql` vào dự án Supabase (nó tạo bảng `plugin_submissions` và bảng append-only `plugin_audit_log`, cả hai đều có row-level security), đặt `PLUGIN_ADMIN_KEY` qua `wrangler secret put` hoặc bảng điều khiển hosting, và triển khai những entry point bạn dùng — Cloudflare Worker (`worker/src/worker.js`) hoặc máy chủ Express (`worker/src/index.js` với `worker/src/routes/plugins.js`). Các đường registry công khai được miễn xác thực bearer và HMAC nhưng vẫn nằm dưới giới hạn tốc độ toàn cục.
