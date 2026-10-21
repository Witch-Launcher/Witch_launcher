<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition关于iPhone和iPad.</strong><br>
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
<summary><strong>语言</strong></summary>

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
## 关于

**Witch Launcher** 是 [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) 的一个独立的、由社区维护的分支，它将 **Minecraft: Java Edition** 带到了 iPhone 和 iPad。它将触摸优先启动器 UI 与完整的Java运行时管理器、LWJGL以及围绕Metal、MoltenVK和OpenGL转换层构建的图形堆栈相结合。

Witch 建立在 [Boardwalk](https://github.com/zhuowei/Boardwalk)、[PojavLauncher](https://github.com/PojavLauncherTeam) 社区、Amethyst-iOS 和 Amethyst-iOS-25 的工作基础上。它是一个独立的项目，不隶属于 Mojang Studios、Microsoft 或上游 Amethyst 团队。

> **当前版本：** 0.0.4 · 请参阅 [`news.md`](../../news.md) 了解发行说明。

---

<a id="features"></a>
## 特点

### Minecraft和模组

- 运行大多数 **Minecraft: Java Edition** 版本，从早期 Beta 版本到最新快照。
- 支持**普通、Fabric、Quilt、Forge、NeoForge和OptiFine**。
- 使用自己的设置、模组、着色器、资源包和世界创建独立的**游戏配置文件**。
- 无需离开启动器即可浏览并安装**Modrinth和CurseForge**中的内容：
  - 模组
  - 模组包
  - 着色器包
  - 资源包
  - 冒险地图和世界
- 解决并安装源提供的 mod 依赖项。
- 直接从版本选择器导入Forge/NeoForge安装程序JAR并安装Fabric/Quilt加载程序。

### 图形和性能

- 从**设置 → 渲染器和显示**在多个渲染器之间切换：
  - **gl4es** — OpenGL 2.1 兼容性路径
  - **ANGLE** — OpenGL ES 至 Metal 或 Vulkan
  - **MobileGlues** — OpenGL 4.0、Minecraft 1.17+，实验性
  - **Zink** — OpenGL 4.1 至 Mesa 25 和 MoltenVK
  - **LTW** — OpenGL 3.3 至 OpenGL ES/Metal、Minecraft 1.17+，实验性
  - **TGLMT** — OpenGL 4.6 核心至 Metal、A11 Bionic 或更新版本
- **TGLMT 以及 Sodium 和 Iris 支持**，用于现代基于着色器的设置。
- 使用运动自适应 GPU (MADI) 和相机 3D 重投影模式生成**帧**，包括时间插值和预测外推。
- 分辨率缩放、最大帧速率、FSR 1.0 升级、GLSL 着色器缓存和每个渲染器调整。
- 具有可配置 FPS、CPU、GPU、RAM、温度、电池、时钟和帧生成 FPS 小部件的性能 HUD。
- 内置带有图表的演奏记录、PNG/PDF 导出和共享。

### 控制

- 完全可定制的屏幕控制布局、按钮大小和透明度。
- **键盘和鼠标**支持，包括虚拟鼠标和可调节的指针速度。
- **游戏控制器**支持可配置的布局和灵敏度。
- **陀螺仪**瞄准，灵敏度可调，轴反转。
- 鼠标、滚动和热键栏手势。
- 可选行为：点击放置方块，按住打破方块。
- 双击热键可将持有的物品切换到副手。
- 可滑动的热键栏和可调节的长按时间。

### 启动器和帐户

- **Microsoft**、**本地/离线**、**演示**和**Ely.by**帐户支持。
- 管理**Java8、17、21和25**运行时，在应用程序内下载它们，或导入您自己的运行时。
- 选择LWJGL版本并调整 JVM 参数、环境变量和内存分配。
- 针对内存有限的设备进行自动 RAM 管理。
- 主题、强调色、模糊、边框、圆角半径、自定义启动器字体和应用程序图标。
- 游戏内**F3设备信息**：设备芯片、iOS版本、启动器名称/版本、版本号和版本类型。
- 可选的**Witch服务器**、CurseForge和AI集成用于高级设置。
- **52 种应用内语言**，包括从右到左的语言包和有趣的语言环境。

---

<a id="screenshots"></a>
## 截图

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

| 要求 | 详情 |
|---|---|
| **设备** | iPhone 或 iPad，带有 arm64 处理器和 Metal 支持 |
| **系统** | iOS 或 iPadOS **14.0 或更高版本** |
| **JIT** | 必需的。启用 JIT 至 StikDebug、SideStore、TrollStore 或越狱设置 |
| **帐户** | 拥有 Minecraft 用于官方下载的 Microsoft 帐户；还提供本地和演示模式 |
| **存储** | 启动器、Java运行时、游戏版本、模组和世界的空间 |
| **网络** | 登录、版本下载、内容浏览器和可选在线服务所需 |

Witch**不**包含Minecraft游戏文件。登录符合条件的帐户后，将通过启动器下载游戏文件。

### JIT注释

Minecraft: Java Edition需要JIT，而Witch没有它就无法启动游戏。

- **SideStore/AltStore式安装：**为Witch启用JIT并保持所需的VPN/调试器连接处于活动状态。应用内消息指的是**LocalDevVPN**和`CS_DEBUGGED`。
- **StikDebug：**将StikDebug附加到Witch并启用JIT。在 **iOS 26/27** 上，StikDebug 在游戏运行时必须保持连接状态。 `UniversalJIT26.js` 会在需要时复制到剪贴板。
- **TrollStore：**如果Witch一直等待JIT，则在TrollStore中启用**URL Scheme**。
- **越狱设备：**使用您首选的JIT启用程序。
- 如果启动器停留在**等待JIT**屏幕上，请在重新启动之前检查调试器连接、VPN和TrollStoreURL Scheme设置。

JIT 行为取决于iOS 版本和安装方法。系统更新可能会破坏现有的JIT设置。

---

<a id="installation"></a>
## 安装

Witch 必须针对您的设备进行签名。此存储库不提供证书或预签名的 IPA。

### 使用构建

1. 从[开发工作流程](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) 下载开发版本，或使用来自您信任的来源的签名版本。
2. 使用**SideStore**、**AltStore**、**TrollStore**或您首选的侧面加载方法签名并安装它。
3. 在启动游戏之前，按照上述说明启用JIT。

TrollStore 构建使用额外的权利，不应使用普通的侧面加载签名者进行安装。

### 从源代码构建

编译Witch需要macOS与Xcode命令行工具、iOSSDK14.0或更新版本、CMake、JDK8、`ldid`、`wget`、`zip`和Git。

```bash
git克隆--递归https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

打包版本按照 `artifacts/` 编写。

要构建 TrollStore 包：

```bash
make package TROLLSTORE_JIT_ENT=1
```

有关渲染器源链接和构建说明，请参阅 [`note.md`](../../note.md)。

---

<a id="languages"></a>
## 语言

Witch Launcher 附带 **52 种语言包**。打开**设置→常规→语言**并选择一种语言，或使用**自动**遵循设备语言。

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

该应用程序附带所有 **52 种语言包**。README 翻译涵盖**所有 52 种语言**，包括英语。

有些翻译是机器辅助的，可能包含尴尬的技术术语。欢迎指正。

英语是本自述文件的源语言。可以从本页顶部的语言选择器和 [`docs/readme/`](./) 目录中获取本地化自述文件。

---

<a id="notes-and-limitations"></a>
## 注意事项和限制

- **JIT 是强制性的。**如果没有有效的 JIT 设置，Minecraft 将不会启动。
- **iOS 26/27 JIT 很脆弱。** StikDebug 必须保持附加状态，未来的操作系统更新可能会改变工作方式。
- 标记为**实验**的渲染器可能会崩溃或渲染不正确。如果您不确定，请从**自动**开始。
- **帧生成**需要MoltenVK渲染器和Metal计算支持。它可以增加电池使用量和设备温度。
- 某些模组、模组包、着色器和世界可能需要特定的Minecraft版本、加载器、渲染器或额外的内存。
- CurseForge 模组包使用`manifest.json`；如果包无法一键安装，请手动导入存档。
- 在线功能依赖于第三方服务，可能不可用。
- 屏幕截图来自开发版本，可能与当前版本不完全匹配。

---

<a id="project-lineage"></a>
## 项目血统

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

### 相关项目

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## 贡献

欢迎 Bug 报告和 PR。报告问题时，请包括：

- 设备型号和iOS/iPadOS版本
- Witch Launcher版本
- 渲染器和Minecraft版本
- mod 加载器和已安装 mod 的列表
- 重现步骤
- 相关日志或崩溃报告

请不要提交签名证书、配置文件、API密钥或其他机密。

---

<a id="credits"></a>
## 制作人员

**Witch Launcher** 由 **DuyAnh662 (Za_d626)** 维护。

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### 上游和社区

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

另外还要感谢 **@lunixbochs**、**@ptitSeb**、**@kakashidinho**、ANGLE 项目、Khronos Group、Mesa 项目、PojavLauncher 团队、Mozilla 和 Minecraft 社区。

特别感谢[MCHeads](https://mc-heads.net)提供Minecraft头像服务。

完整的第三方组件和许可证列表可在 [`credits.md`](../../credits.md) 中找到。

---

<a id="license"></a>
## 许可证

Witch Launcher 根据 **GNU 通用公共许可证 v3.0** 分发，并遵守 [`credits.md`](../../credits.md) 中列出的第三方组件的许可证和版权要求。

请参阅 [`LICENSE`](../../LICENSE) 了解完整的许可文本。

---

<p align="center">
<sub>Minecraft是Mojang Studios的商标。 Witch Launcher 不隶属于Mojang Studios、Microsoft 或Amethyst 项目。</sub>
</p>
