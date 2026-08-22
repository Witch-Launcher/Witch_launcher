# Wtich launcher launcher - 0.0.2
- Change and fix UI
# Wtich launcher launcher - 0.0.1
- Add all
# AngelAuraAmethyst iOS — 1.1.4-beta

## 🇬🇧 English

- Fixed Distant Horizons crashing the game at startup (NoClassDefFoundError: org.lwjgl.system.Pointer$Default on 1.20/1.20.1 Fabric). Root cause: patched GLFW's static `SharedLibrary` field was created during `GLFW.<clinit>`, which runs inside `MemoryUtil.<clinit>` → `Library.<clinit>` → `System.load` before `MemoryUtil.UNSAFE` is assigned — `Pointer$Default` got permanently poisoned and any later LWJGL use (e.g. DH's TinyFileDialogs message box) crashed with "UNSAFE is null". The library handle is now created lazily on first use, keeping `GLFW.<clinit>` pure Java.
- Reviewed and fixed the Super resolution not working.
- Fixed Distant Horizons crashing on iOS 26 (A12+ devices): the mod's zstd-jni native library is now pre-extracted from the DH jar and ad-hoc signed with a bundled ldid, so it loads from `java.library.path` instead of failing with "code signature invalid".

## 🇻🇳 Tiếng Việt

- Sửa Distant Horizons crash ngay khi khởi động game (NoClassDefFoundError: org.lwjgl.system.Pointer$Default trên Fabric 1.20/1.20.1). Nguyên nhân: thư viện `SharedLibrary` tĩnh trong GLFW (patched) được tạo trong lúc `GLFW.<clinit>` chạy bên trong `MemoryUtil.<clinit>` → `Library.<clinit>` → `System.load`, trước khi `MemoryUtil.UNSAFE` được gán — class `Pointer$Default` bị "đầu độc" vĩnh viễn và mọi truy cập LWJGL sau đó (vd: hộp thoại TinyFileDialogs của DH) crash với lỗi "UNSAFE is null". Giờ handle thư viện được tạo delay khi dùng lần đầu, giữ cho `GLFW.<clinit>` hoàn toàn pure Java.
- Xem và sửa mod Super resolution không hoạt động.
- Sửa Distant Horizons crash trên iOS 26 (máy A12+): thư viện zstd-jni của mod giờ được lấy sẵn từ jar DH và ký ad-hoc bằng ldid đi kèm trong app, load từ `java.library.path` thay vì báo lỗi "code signature invalid".

## 🇻🇳 Tiếng Việt

- Xem và sửa mod Super resolution không hoạt động.
- Làm lại hệ thống nút, list khi chơi Game
- Fixing mod TouchController
- Update LTW render
- Thêm nút copy, paste trong Game
- Fix litematica mod not working
- Thêm nhập file mrpack
- Fix làm mờ ảnh/video nền lỗi(Thêm một lớp đằng trước video hoặc ảnh để làm mờ)
- Fix lỗi JIT trên iOS 27
- Update Render MobileGlues lên 1.3.5
- Fix Vulkan mod
- Add Ely.by

---

# AngelAuraAmethyst iOS — 1.1.3

```Cảm ơn L4d đã hỗ trợ mình trong việc sửa chữa vấn đề trên iOS 27(But not working :< I'm Sorry)```
```Thanks for Development247, Han```

## 🇬🇧 English

- Fixed the Distant Horizons mod not working on iOS 26.
- Fixed the crash issue when reaching 1000MB RAM on all devices.
- Reviewed and fixed the Touch Controller not working.
- Fixed crashes on iOS 26.
- Fixed the issue of not being able to type Vietnamese when using an external keyboard.
- Fixed crashes when playing Minecraft Vanilla.
- Fixed the issue of automatic downloads when browsing mods, modpacks, etc.
- Added and modified features to change the mouse cursor style.
- Fixes crash issues when exiting the game using a code.
- Forge 26.x (e.g. Forge for Minecraft 1.21.2) now actually launches — the missing `forge-*-universal.jar` is added to the game classpath so the "forge" system mod is detected and the game no longer crashes with "Failed to find system mod: forge".
- News panel now shows only the changelog of the version you are running (filtered from news.md).
- Improved markdown rendering — headings, bold/italic, lists, code, links and tables are now rendered correctly.
- Forge & NeoForge now install correctly — the official installer jar is downloaded and run through the built-in "Execute .jar" environment.
- Import local `.mrpack` modpacks — the launcher downloads everything inside and sets up the loader automatically.
- Fixed Forge installer downloads (moved to the official MinecraftForge Maven repository).
- Modpacks needing Forge/NeoForge now auto-install the loader.
- "Execute .jar" gained an "Install (headless)" option for installer jars.
- Version list refreshes automatically after installing.

## 🇻🇳 Tiếng Việt

- Sửa lỗi Distant Horizons mod không hoạt động trên iOS 26.
- Sửa lỗi crash khi đạt 1000MB RAM trên mọi thiết bị.
- Xem và sửa mod Touch Controller không hoạt động.
- Sửa lỗi crash trên iOS 26.
- Sửa lỗi không gõ được tiếng Việt khi sử dụng bàn phím ngoài.
- Sửa lỗi crash khi chơi Minecraft Vanilla. 
- Sửa lỗi tự động load khi duyệt mod, modpacks,...
- Thêm và sửa tính năng thay đổi hình dáng trỏ chuột. 
- Sửa lỗi crash với mã khi thoát game.
- Forge 26.x (vd. Forge cho Minecraft 1.21.2) giờ chạy được thật sự — bổ sung `forge-*-universal.jar` vào classpath game để nhận diện system mod "forge", không còn crash lỗi "Failed to find system mod: forge".
- Bảng tin chỉ hiển thị changelog đúng phiên bản launcher bạn đang chạy (lọc từ news.md).
- Cải thiện render markdown — tiêu đề, in đậm/nghiêng, danh sách, code, link và bảng hiển thị đúng.
- Forge & NeoForge cài đúng cách — tải installer jar chính thức và chạy qua môi trường "Execute .jar" có sẵn.
- Nhập modpack `.mrpack` cục bộ — launcher tự tải toàn bộ nội dung và tự cài loader.
- Sửa lỗi tải installer Forge (dùng kho Maven chính thức của MinecraftForge).
- Modpack cần Forge/NeoForge tự động cài loader.
- "Execute .jar" thêm nút "Install (headless)" cho file installer.
- Danh sách version tự làm mới sau khi cà

---

# AngelAuraAmethyst iOS — 1.1.3-beta.10

```Cảm ơn L4d đã hỗ trợ mình trong việc sửa chữa vấn đề trên iOS 27(But not working :< I'm Sorry)```

## 🇬🇧 English

- 

## 🇻🇳 Tiếng Việt

- 

---

# AngelAuraAmethyst iOS — 1.1.3-beta.9

```Cảm ơn L4d đã hỗ trợ mình trong việc sửa chữa vấn đề trên iOS 27(But not working :< I'm Sorry)```

## 🇬🇧 English

- Fixed the Distant Horizons mod not working on iOS 26.
- Fixed the crash issue when reaching 1000MB RAM on all devices.
- Reviewed and fixed the Touch Controller not working.
- iOS 26.6/27 JIT: TXM detection rewritten to match StikDebug 3.1.6+ exactly — A13/A14/M1 devices (e.g. iPhone 12) now use the correct non-TXM path on iOS 26, and on iOS 27 every device except the M1 iPad Pro (iPad8,11/iPad8,12) is treated as TXM so the Universal JIT script is actually served. Use StikDebug 3.1.6 or newer (3.1.9 recommended). New hidden preference `debug.force_txm` to override detection.

## 🇻🇳 Tiếng Việt

- Sửa lỗi Distant Horizons mod không hoạt động trên iOS 26.
- Sửa lỗi crash khi đạt 1000MB RAM trên mọi thiết bị.
- Xem và sửa mod Touch Controller không hoạt động.
- Sửa JIT trên iOS 26.6/27: viết lại cách nhận diện TXM cho khớp hoàn toàn với StikDebug 3.1.6+ — máy A13/A14/M1 (vd iPhone 12) giờ dùng đúng đường non-TXM trên iOS 26, còn trên iOS 27 mọi thiết bị trừ iPad Pro M1 (iPad8,11/iPad8,12) được xem là TXM để debugger thực sự phục vụ script Universal JIT. Hãy dùng StikDebug 3.1.6 trở lên (khuyến nghị 3.1.9). Thêm pref ẩn `debug.force_txm` để ép nhận diện TXM.

---

# AngelAuraAmethyst iOS — 1.1.3-beta.8

```Cảm ơn L4d đã hỗ trợ mình trong việc sửa chữa vấn đề trên iOS 27(But not working :< I'm Sorry)```

## 🇬🇧 English

- Fixed crashes on iOS 26.
- Fixed the issue of not being able to type Vietnamese when using an external keyboard.
- Fixed crashes when playing Minecraft Vanilla.
- Fixed the issue of automatic downloads when browsing mods, modpacks, etc.
- Added and modified features to change the mouse cursor style.
- Fixes crash issues when exiting the game using a code.

## 🇻🇳 Tiếng Việt

- Sửa lỗi crash trên iOS 26.
- Sửa lỗi không gõ được tiếng Việt khi sử dụng bàn phím ngoài.
- Sửa lỗi crash khi chơi Minecraft Vanilla. 
- Sửa lỗi tự động load khi duyệt mod, modpacks,...
- Thêm và sửa tính năng thay đổi hình dáng trỏ chuột. 
- Sửa lỗi crash với mã khi thoát game.

---

# AngelAuraAmethyst iOS — 1.1.3-beta.7

## 🇬🇧 English
- Fixed a crash ("`-[__NSDictionaryM containsString:]`") when launching Minecraft 1.13+ versions — rule-based JVM arguments (dictionary entries like `{"rules": …}` in `arguments.jvm`) are now skipped instead of being treated as strings.
- iOS 27 JIT stability: the mirror-mapped code cache path (observed crashing with SIGBUS W^X / SIGSEGV on some A14/A15 devices with Java 21/25) is now **disabled by default on iOS 27**, falling back to the classic JIT26 path. Override with the hidden preference `debug.mirror_mapped_code_cache` (-1 auto / 0 off / 1 on).
- Updated the Universal JIT script to match StikDebug 3.1.x (improved signal handling) and added explicit error reporting when the debugger is too old to grant JIT execution.
- iOS 27 note: use **StikDebug 3.1.6 or newer** (3.1.9 recommended) — older builds cannot grant JIT on iOS 27.

## 🇻🇳 Tiếng Việt
- Sửa crash ("`-[__NSDictionaryM containsString:]`") khi chạy Minecraft 1.13+ — các đối số JVM dạng rule (entry là dictionary như `{"rules": …}` trong `arguments.jvm`) giờ được bỏ qua thay vì xử lý như chuỗi.
- Ổn định JIT trên iOS 27: mirror-mapped code cache (từng gây crash SIGBUS W^X / SIGSEGV trên một số máy A14/A15 với Java 21/25) giờ **tắt mặc định trên iOS 27**, chuyển về path JIT26 cổ điển. Có thể ghi đè bằng pref ẩn `debug.mirror_mapped_code_cache` (-1 tự động / 0 tắt / 1 bật).
- Cập nhật Universal JIT script khớp StikDebug 3.1.x (xử lý tín hiệu cải thiện) và báo lỗi rõ ràng khi debugger quá cũ không cấp được JIT.
- Lưu ý iOS 27: hãy dùng **StikDebug 3.1.6 trở lên** (khuyến nghị 3.1.9) — bản cũ không cấp được JIT trên iOS 27.

---

# AngelAuraAmethyst iOS — 1.1.3-beta.6

## 🇬🇧 English
- Fixed "Insufficient contiguous virtual memory space" and early app kills on non-jailbroken devices — the launcher now reads the real remaining memory allowance via `os_proc_available_memory()`, caps auto RAM at 60% of the remaining allowance (minimum 384 MB) and the memory probe no longer blocks launching.
- Virtual mouse pointer customization — pick from built-in styles (Arrow, Crosshair, Circle, Dot, Beam) or use your own cursor files: Windows `.cur` / `.ani` and common image formats (png, jpg, gif, bmp, tiff, webp…).
- Cursor hotspot from `.cur`/`.ani` files is honored, so the tap point lands exactly on the arrow tip (or the center of centered shapes).
- Custom pointer file is stored in the app's Documents folder; resetting or removing the file falls back to the default pointer.

## 🇻🇳 Tiếng Việt
- Sửa lỗi "Insufficient contiguous virtual memory space" và bị kill sớm trên máy không jailbreak — launcher giờ đọc đúng dung lượng bộ nhớ còn lại qua `os_proc_available_memory()`, giới hạn auto RAM ở 60% phần còn lại (tối thiểu 384 MB) và bước kiểm tra bộ nhớ không còn chặn khởi động.
- Cá nhân hóa con trỏ chuột ảo — chọn kiểu có sẵn (Arrow, Crosshair, Circle, Dot, Beam) hoặc dùng file con trỏ của bạn: `.cur` / `.ani` của Windows và các định dạng ảnh phổ biến (png, jpg, gif, bmp, tiff, webp…).
- Tôn trọng hotspot trong file `.cur`/`.ani` — điểm chạm trỏ đúng mũi tên (hoặc tâm với hình tròn).
- File con trỏ tùy chỉnh lưu trong thư mục Documents của app; xóa/mất file sẽ tự quay về con trỏ mặc định.

---

# AngelAuraAmethyst iOS — 1.1.3-beta.5

## 🇬🇧 English
- Forge 26.x (e.g. Forge for Minecraft 1.21.2) now actually launches — the missing `forge-*-universal.jar` is added to the game classpath so the "forge" system mod is detected and the game no longer crashes with "Failed to find system mod: forge".
- News panel now shows only the changelog of the version you are running (filtered from news.md).
- Improved markdown rendering — headings, bold/italic, lists, code, links and tables are now rendered correctly.

## 🇻🇳 Tiếng Việt
- Forge 26.x (vd. Forge cho Minecraft 1.21.2) giờ chạy được thật sự — bổ sung `forge-*-universal.jar` vào classpath game để nhận diện system mod "forge", không còn crash lỗi "Failed to find system mod: forge".
- Bảng tin chỉ hiển thị changelog đúng phiên bản launcher bạn đang chạy (lọc từ news.md).
- Cải thiện render markdown — tiêu đề, in đậm/nghiêng, danh sách, code, link và bảng hiển thị đúng.

---

# AngelAuraAmethyst iOS — 1.1.3-beta.4

## 🇬🇧 English
- Forge & NeoForge now install correctly — the official installer jar is downloaded and run through the built-in "Execute .jar" environment.
- Import local `.mrpack` modpacks — the launcher downloads everything inside and sets up the loader automatically.
- Fixed Forge installer downloads (moved to the official MinecraftForge Maven repository).
- Modpacks needing Forge/NeoForge now auto-install the loader.
- "Execute .jar" gained an "Install (headless)" option for installer jars.
- Version list refreshes automatically after installing.

Thanks to everyone who tested this build!

## 🇻🇳 Tiếng Việt
- Forge & NeoForge cài đúng cách — tải installer jar chính thức và chạy qua môi trường "Execute .jar" có sẵn.
- Nhập modpack `.mrpack` cục bộ — launcher tự tải toàn bộ nội dung và tự cài loader.
- Sửa lỗi tải installer Forge (dùng kho Maven chính thức của MinecraftForge).
- Modpack cần Forge/NeoForge tự động cài loader.
- "Execute .jar" thêm nút "Install (headless)" cho file installer.
- Danh sách version tự làm mới sau khi cài.

Cảm ơn mọi người đã test bản này!