<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition關於iPhone和iPad.</strong><br>
社区构建的 Amethyst 的 iOS 和 iPadOS 分支，由 DuyAnh662 (Za_d626) 维护。
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[功能](#features) · [屏幕截图](#screenshots) · [要求](#requirements) · [安装](#installation) · [语言](#languages) · [制作人员](#credits) · [许可证](#license)

<details>
<summary><strong>語言</strong></summary>

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
## 關於

**Witch Launcher** 是 [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) 的一个独立的、由社区维护的分支，它将 **Minecraft: Java Edition** 带到了 iPhone 和 iPad。它将触摸优先启动器 UI 与完整的Java运行时管理器、LWJGL以及围绕Metal、MoltenVK和OpenGL转换层构建的图形堆栈相结合。

Witch 建立在 [Boardwalk](https://github.com/zhuowei/Boardwalk)、[PojavLauncher](https://github.com/PojavLauncherTeam) 社区、Amethyst-iOS 和 Amethyst-iOS-25 的工作基础上。它是一个独立的项目，不隶属于 Mojang Studios、Microsoft 或上游 Amethyst 团队。

> **当前版本：** 0.0.4 · 请参阅 [`news.md`](../../news.md) 了解发行说明。

---

<a id="features"></a>
## 特點

### Minecraft和模組

- 运行大多数 **Minecraft: Java Edition** 版本，从早期 Beta 版本到最新快照。
- 支持**普通、Fabric、Quilt、Forge、NeoForge和OptiFine**。
- 使用自己的设置、模组、着色器、资源包和世界创建独立的**游戏配置文件**。
- 无需离开启动器即可浏览并安装**Modrinth和CurseForge**中的内容：
  - 模組
  - 模組包
  - 著色器包
  - 資源包
  - 冒險地圖與世界
- 解決並安裝來源提供的 mod 依賴項。
- 直接从版本选择器导入Forge/NeoForge安装程序JAR并安装Fabric/Quilt加载程序。

### 圖形和效能

- 從**設定 → 渲染器和顯示**在多個渲染器之間切換：
  - **gl4es** — OpenGL 2.1 相容性路徑
  - **ANGLE** — OpenGL ES 至 Metal 或 Vulkan
  - **MobileGlues** — OpenGL 4.0、Minecraft 1.17+，實驗性
  - **Zink** — OpenGL 4.1 至 Mesa 25 和 MoltenVK
  - **LTW** — OpenGL 3.3 至 OpenGL ES/Metal、Minecraft 1.17+，實驗性
  - **TGLMT** — OpenGL 4.6 核心至 Metal、A11 Bionic 或更新版本
- **TGLMT 以及 Sodium 和 Iris 支援**，用於現代基於著色器的設定。
- 使用運動自適應 GPU (MADI) 和相機 3D 重投影模式產生**幀**，包括時間插值和預測外推。
- 分辨率缩放、最大帧速率、FSR 1.0 升级、GLSL 着色器缓存和每个渲染器调整。
- 具有可配置 FPS、CPU、GPU、RAM、溫度、電池、時鐘和幀生成 FPS 小部件的性能 HUD。
- 內建帶有圖表的演奏記錄、PNG/PDF 匯出和分享。

### 控制

- 完全可自訂的螢幕控制佈局、按鈕大小和透明度。
- **键盘和鼠标**支持，包括虚拟鼠标和可调节的指针速度。
- **游戏控制器**支持可配置的布局和灵敏度。
- **陀螺儀**瞄準，靈敏度可調，軸反轉。
- 鼠标、滚动和热键栏手势。
- 可选行为：点击放置方块，按住打破方块。
- 雙擊熱鍵可將持有的物品切換到副手。
- 可滑动的热键栏和可调节的长按时间。

### 啟動器和帳戶

- **Microsoft**、**本地/离线**、**演示**和**Ely.by**帐户支持。
- 管理**Java8、17、21和25**运行时，在应用程序内下载它们，或导入您自己的运行时。
- 选择LWJGL版本并调整 JVM 参数、环境变量和内存分配。
- 针对内存有限的设备进行自动 RAM 管理。
- 主題、強調色、模糊、邊框、圓角半徑、自訂啟動器字體和應用程式圖示。
- 游戏内**F3设备信息**：设备芯片、iOS版本、启动器名称/版本、版本号和版本类型。
- 可选的**Witch服务器**、CurseForge和AI集成用于高级设置。
- **52 套用內語言**，包括從右到左的語言包和有趣的語言環境。

---

<a id="screenshots"></a>
## 截圖

Witch Launcher0.0.4 开发版本的屏幕截图。界面可以在版本和主题之间变化。

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
## 要求

| 要求 | 詳情 |
|---|---|
| **設備** | iPhone 或 iPad，帶有 arm64 處理器和 Metal 支援 |
| **系统** | iOS 或 iPadOS **14.0 或更高版本** |
| **JIT** | 必需的。啟用 JIT 至 StikDebug、SideStore、TrollStore 或越獄設定 |
| **帐户** | 拥有 Minecraft 用于官方下载的 Microsoft 帐户；还提供本地和演示模式 |
| **儲存** | 啟動器、Java運行時、遊戲版本、模組和世界的空間 |
| **网络** | 登录、版本下载、内容浏览器和可选在线服务所需 |

Witch**不**包含Minecraft游戏文件。登入符合條件的帳戶後，將透過啟動器下載遊戲檔案。

### JIT註釋

Minecraft: Java Edition需要JIT，而Witch沒有它就無法啟動遊戲。

- **SideStore/AltStore式安裝：**為Witch啟用JIT並保持所需的VPN/調試器連線處於活動狀態。應用內訊息指的是**LocalDevVPN**和`CS_DEBUGGED`。
- **StikDebug：**將StikDebug附加到Witch並啟用JIT。在 **iOS 26/27** 上，StikDebug 在遊戲運行時必須保持連線狀態。 `UniversalJIT26.js` 会在需要时复制到剪贴板。
- **TrollStore：**如果Witch一直等待JIT，則在TrollStore中啟用**URL Scheme**。
- **越獄設備：**使用您首選的JIT啟用程序。
- 如果啟動器停留在**等待JIT**畫面上，請在重新啟動之前檢查調試器連線、VPN和TrollStoreURL Scheme設定。

JIT 行為取決於iOS 版本和安裝方法。系統更新可能會破壞現有的JIT設定。

---

<a id="installation"></a>
## 安裝

Witch 必須針對您的裝置進行簽署。此儲存庫不提供憑證或預先簽署的 IPA。

### 使用建構

1. 從[開發工作流程](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) 下載開發版本，或使用您信任的來源的簽章版本。
2. 使用**SideStore**、**AltStore**、**TrollStore**或您首選的側面加載方法簽署並安裝它。
3. 在啟動遊戲之前，請按照上述說明啟用JIT。

TrollStore 建造使用額外的權利，不應使用普通的側面加載簽署者進行安裝。

### 從原始碼構建

編譯Witch需要macOS與Xcode命令列工具、iOSSDK14.0或更新版本、CMake、JDK8、`ldid`、`wget`、`zip`和Git。

```bash
git克隆--遞迴https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

打包版本依照 `artifacts/` 編寫。

要建造 TrollStore 包：

```bash
make package TROLLSTORE_JIT_ENT=1
```

有關渲染器來源連結和建置說明，請參閱 [`note.md`](../../note.md)。

---

<a id="languages"></a>
## 語言

Witch Launcher 附帶 **52 種語言包**。開啟**設定→常規→語言**並選擇一種語言，或使用**自動**遵循裝置語言。

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

該應用程式附帶所有 **52 種語言包**。自述文件提供**所有 52 種語言**的翻譯，包括英文。

有些翻譯是機器輔助的，可能包含尷尬的技術術語。歡迎指正。

英語是本自述文件的來源語言。可以從本頁頂部的語言選擇器和 [`docs/readme/`](./) 目錄中取得本地化自述文件。

---

<a id="notes-and-limitations"></a>
## 注意事項和限制

- **JIT 是強制性的。 **如果沒有有效的 JIT 設置，Minecraft 將不會啟動。
- **iOS 26/27 JIT 很脆弱。 ** StikDebug 必須保持附加狀態，未來的作業系統更新可能會改變工作方式。
- 標示為**實驗**的渲染器可能會崩潰或渲染不正確。如果您不確定，請從**自動**開始。
- **幀生成**需要MoltenVK渲染器和Metal計算支援。它可以增加電池使用量和設備溫度。
- 某些模組、模組包、著色器和世界可能需要特定的Minecraft版本、載入器、渲染器或額外的記憶體。
- CurseForge 模組包使用`manifest.json`；如果包無法一鍵安裝，請手動匯入存檔。
- 線上功能依賴第三方服務，可能無法使用。
- 屏幕截图来自开发版本，可能与当前版本不完全匹配。

---

<a id="project-lineage"></a>
## 專案血統

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

### 相關項目

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## 貢獻

歡迎 Bug 報告和 PR。報告問題時，請包括：

- 設備型號和iOS/iPadOS版本
- Witch Launcher版本
- 渲染器和Minecraft版本
- mod 載入器和已安裝 mod 的列表
- 重現步驟
- 相關日誌或崩潰報告

请不要提交签名证书、配置文件、API密钥或其他机密。

---

<a id="credits"></a>
## 製作人員

**Witch Launcher** 由 **DuyAnh662 (Za_d626)** 维护。

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### 上游和社區

Witch Launcher 及其上游项目建立在许多贡献者的工作之上，包括：

- **@crystall1nedev** — Amethyst 项目经理和 iOS 端口开发人员
- **@khanhduytran0** — iOS 端口开发商
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

另外也要感謝 **@lunixbochs**、**@ptitSeb**、**@kakashidinho**、ANGLE 專案、Khronos Group、Mesa 專案、PojavLauncher 團隊、Mozilla 和 Minecraft 社區。

特别感谢[MCHeads](https://mc-heads.net)提供Minecraft头像服务。

完整的第三方组件和许可证列表可在 [`credits.md`](../../credits.md) 中找到。

---

<a id="license"></a>
## 許可證

Witch Launcher 根據 **GNU 通用公共授權 v3.0** 分發，並遵守 [`credits.md`](../../credits.md) 中列出的第三方組件的授權和版權要求。

请参阅 [`LICENSE`](../../LICENSE) 了解完整的许可文本。

---

<p align="center">
<sub>Minecraft是Mojang Studios的商標。 Witch Launcher 不隶属于Mojang Studios、Microsoft 或Amethyst 项目。 </sub>
</p>
