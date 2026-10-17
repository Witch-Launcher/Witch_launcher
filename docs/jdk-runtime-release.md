# JDK + LWJGL runtime release (repo Witch-Launcher/JDK-Java_iOS)

Repo này (`Angel-Aura-Amethyst-iOS`) không build JDK nữa sau khi tách.
Mọi JDK/LWJGL do repo `Witch-Launcher/JDK-Java_iOS` build và publish.

## Copy workflow mẫu

Copy file `docs/jdk-workflow-template.yml` trong repo này sang repo JDK thành
`.github/workflows/build-runtimes.yml`, sau đó tạo tag `runtimes-latest` (rolling):

```bash
# trong repo JDK-Java_iOS
git tag -f runtimes-latest
git push -f origin runtimes-latest
```

Workflow sẽ build matrix:

- JRE: 8, 17, 21, 25 (`tar.xz`, layout giữ nguyên `release`, `.witch-mirror-mapping`, `lib/server/libjvm.dylib` đã patch)
- LWJGL jars: `lwjgl-3.3.3.jar`, `lwjgl-3.3.6.jar`, `lwjgl-3.4.1.jar`
- LWJGL natives: `lwjgl33-natives.tar.xz`, `lwjgl36-natives.tar.xz`, `lwjgl41-natives.tar.xz`
- Manifest: `runtimes.json`

Mỗi file là **1 Release asset riêng**, không zip chung:

```json
{
  "jre8":   { "version": "1.8.0_472", "url": "https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/runtimes-latest/jre8-ios-aarch64.tar.xz", "size": 123456 },
  "jre17":  { "version": "17.0.20", "url": ".../jre17-ios-aarch64.tar.xz", "size": 0 },
  "jre21":  { "version": "21.0.8", "url": ".../jre21-ios-aarch64.tar.xz", "size": 0 },
  "jre25":  { "version": "25.0.4", "url": ".../jre25-ios-aarch64.tar.xz", "size": 0 },
  "lwjgl333": { "version": "3.3.3", "url": ".../lwjgl-3.3.3.jar", "size": 0 },
  "lwjgl336": { "version": "3.3.6", "url": ".../lwjgl-3.3.6.jar", "size": 0 },
  "lwjgl341": { "version": "3.4.1", "url": ".../lwjgl-3.4.1.jar", "size": 0 }
}
```

Launcher đọc manifest tại (đổi được qua pref `witch.runtime_manifest`):

```
https://github.com/Witch-Launcher/JDK-Java_iOS/releases/download/runtimes-latest/runtimes.json
```

## Launcher tiêu thụ thế nào

- Bản Simple first-run: `MainMenuViewController.m maybeShowRuntimeOnboarding` → `RuntimeDownloadViewController` (onboardingMode).
- Settings → `Tải Runtime JDK/LWJGL` mở lại bảng bất cứ lúc nào; mỗi dòng có Tải/Cập nhật + Xóa riêng (`WitchRuntimeService`).
- Cài luôn không restart: tải xong post `WitchRuntimesDidChange`, `JavaLauncher` đọc path lazily nên không cần restart app.
- Quan trọng: JDK8, JDK25, LWJGL 3.3.3, LWJGL 3.4.1 hiện badge `[quan trọng]`.

## Launcher self-update

- Kênh lưu ở `launcher.update_channel`: 0=Tự động, 1=Beta (pre-release), 2=Ổn định (release).
- Settings → `Cập nhật Launcher (Beta/Stable)` (`LauncherUpdateViewController`): chọn kênh, chọn Full/Simple, tải đúng `*.ipa` (sideload) hoặc `*.tipa` (TrollStore, detect `_TrollStore`), cài qua `trollstore://install` → `apple-magnifier://install` → Share Sheet fallback.
- Auto-check mỗi launch (`WitchUpdateService autoCheckFromViewController`), "Để sau" né 3 ngày.
