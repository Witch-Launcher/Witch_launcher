<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
iPhone および iPad の <strong>Minecraft: Java Edition。</strong><br>
コミュニティによって構築された Amethyst の iOS および iPadOS フォーク。DuyAnh662 (Za_d626) によって保守されています。
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[機能](#features) · [スクリーンショット](#screenshots) · [要件](#requirements) · [インストール](#installation) · [言語](#languages) · [クレジット](#credits) · [ライセンス](#license)

<details>
<summary><strong>言語</strong></summary>

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
## について

**Witch Launcher** は、コミュニティによって管理される独立した [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) のフォークであり、**Minecraft: Java Edition** を iPhone と iPad にもたらします。これは、タッチファースト ランチャー UI と、完全な Java ランタイム マネージャー、LWJGL、および Metal、MoltenVK、および OpenGL 変換レイヤーを中心に構築されたグラフィックス スタックを組み合わせています。

Witch は、[Boardwalk](https://github.com/zhuowei/Boardwalk)、[PojavLauncher](https://github.com/PojavLauncherTeam) コミュニティ、Amethyst-iOS、および Amethyst-iOS-25 の成果に基づいて構築されています。これは独立したプロジェクトであり、Mojang Studios、Microsoft、または上流の Amethyst チームとは提携していません。

> **現在のバージョン:** 0.0.4 · リリース ノートについては、[`news.md`](../../news.md) を参照してください。

---

<a id="features"></a>
## 特長

### Minecraft と MOD

- 初期のベータ版リリースから最新のスナップショットまで、ほとんどの **Minecraft: Java Edition** バージョンを実行します。
- **バニラ、Fabric、Quilt、Forge、NeoForge、OptiFine** をサポートします。
- 独自の設定、MOD、シェーダー、リソース パック、ワールドを含む独立した**ゲーム プロファイル**を作成します。
- ランチャーを離れることなく、**Modrinth と CurseForge** のコンテンツを参照してインストールします。
  - 改造
  - モッドパック
  - シェーダパック
  - リソースパック
  - アドベンチャーマップと世界
- ソースが提供する MOD の依存関係を解決してインストールします。
- Forge/NeoForge インストーラー JAR をインポートし、バージョン ピッカーから直接 Fabric/Quilt ローダーをインストールします。

### グラフィックとパフォーマンス

- **設定 → レンダラーとディスプレイ** から複数のレンダラーを切り替えます。
  - **gl4es** — OpenGL 2.1 互換性パス
  - **ANGLE** — OpenGL ES ～ Metal または Vulkan
  - **MobileGlues** — OpenGL 4.0、Minecraft 1.17+、試験運用版
  - **Zink** — OpenGL 4.1 ～ Mesa 25 および MoltenVK
  - **LTW** — OpenGL 3.3 ～ OpenGL ES/Metal、Minecraft 1.17+、試験運用版
  - **TGLMT** — OpenGL 4.6 コアから Metal、A11 Bionic 以降
- **TGLMT は、最新のシェーダベースのセットアップ向けに Sodium および Iris をサポート**します。
- モーション アダプティブ GPU (MADI) とカメラ 3D 再投影モードによる**フレーム生成** (時間補間と予測外挿を含む)。
- 解像度スケーリング、最大フレームレート、FSR 1.0 アップスケーリング、GLSL シェーダ キャッシュ、レンダラーごとの調整。
- 構成可能な FPS、CPU、GPU、RAM、温度、バッテリー、クロック、フレーム生成 FPS ウィジェットを備えたパフォーマンス HUD。
- チャート、PNG/PDF エクスポート、共有機能を備えた組み込みのパフォーマンス記録。

### コントロール

- 画面上のコントロールのレイアウト、ボタンのサイズ、透明度を完全にカスタマイズできます。
- 仮想マウスや調整可能なポインタ速度を含む**キーボードとマウス** のサポート。
- 構成可能なレイアウトと感度を備えた**ゲーム コントローラー** のサポート。
- 調整可能な感度と軸反転を備えた**ジャイロスコープ**による照準。
- マウス、スクロール、ホットバーのジェスチャ。
- オプションの動作: タップしてブロックを配置し、長押ししてブロックを破壊します。
- ホットバーをダブルタップして、持っているアイテムをオフハンドに切り替えます。
- スライド可能なホットバーと長押しのタイミングを調整可能。

### ランチャーとアカウント

- **Microsoft**、**ローカル/オフライン**、**デモ**、**Ely.by** アカウントのサポート。
- **Java 8、17、21、25** ランタイムを管理し、アプリ内でダウンロードするか、独自のランタイムをインポートします。
- LWJGL バージョンを選択し、JVM 引数、環境変数、メモリ割り当てを調整します。
- メモリが限られているデバイスの自動 RAM 管理。
- テーマ、アクセントカラー、ぼかし、境界線、コーナー半径、カスタムランチャーフォント、アプリアイコン。
- ゲーム内の**F3 デバイス情報**: デバイス チップ、iOS バージョン、ランチャー名/バージョン、ビルド番号、ビルド タイプ。
- 高度なセットアップのためのオプションの **Witch サーバー**、CurseForge、および AI の統合。
- **52 のアプリ内言語**（右から左へ記述する言語パックや楽しいロケールを含む）。

---

<a id="screenshots"></a>
## スクリーンショット

Witch Launcher 0.0.4 の開発ビルドのスクリーンショット。インターフェイスはバージョンやテーマによって異なる場合があります。

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
## 要件

| 要件 | 詳細 |
|---|---|
| **デバイス** | arm64 プロセッサと Metal サポートを備えた iPhone または iPad |
| **システム** | iOS または iPadOS **14.0 以降** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Account** | A Microsoft account that owns Minecraft for official downloads; local and demo modes are also available |
| **ストレージ** | ランチャー、Java ランタイム、ゲーム バージョン、MOD、ワールド用のスペース |
| **Network** | Required for sign-in, version downloads, the content browser, and optional online services |

Witch には Minecraft ゲーム ファイルは**含まれません**。ゲーム ファイルは、対象となるアカウントにサインインした後、ランチャーを通じてダウンロードされます。

### JIT メモ

Minecraft: Java Edition には JIT が必要であり、Witch はそれなしではゲームを起動できません。

- **SideStore / AltStore スタイルのインストール:** Witch に対して JIT を有効にし、必要な VPN/デバッガー接続をアクティブなままにします。アプリ内メッセージは **LocalDevVPN** と `CS_DEBUGGED` を指します。
- **StikDebug:** StikDebug を Witch に接続し、JIT を有効にします。 **iOS 26/27** では、ゲームの実行中、StikDebug は接続されたままでなければなりません。 `UniversalJIT26.js` は、必要に応じてクリップボードにコピーされます。
- **TrollStore:** Witch が JIT を待機し続ける場合、TrollStore の **URL Scheme** を有効にします。
- **ジェイルブレイクされたデバイス:** 好みの JIT イネーブラを使用します。
- ランチャーが [**JIT を待機中** ] 画面のままの場合は、再起動する前に、デバッガーの接続、VPN、および TrollStore URL Scheme の設定を確認してください。

JIT の動作は、iOS のバージョンとインストール方法によって異なります。システムのアップデートにより、既存の JIT セットアップが壊れる可能性があります。

---

<a id="installation"></a>
## インストール

Witch はデバイス用に署名する必要があります。このリポジトリは、証明書や事前署名された IPA を配布しません。

### ビルドを使用する

1. [開発ワークフロー](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) から開発ビルドをダウンロードするか、信頼できるソースからの署名付きビルドを使用します。
2. **SideStore**、**AltStore**、**TrollStore**、または好みのサイドローディング方法で署名し、インストールします。
3. ゲームを起動する前に、上記の説明に従って JIT を有効にします。

TrollStore ビルドは追加の資格を使用するため、通常のサイドローディング署名者と一緒にインストールしないでください。

### ソースからビルドする

Witch をコンパイルするには、Xcode コマンドライン ツールを備えた macOS、iOS SDK 14.0 以降、CMake、JDK 8、`ldid`、`wget`、`zip`、および Git が必要です。

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

パッケージ化されたビルドは `artifacts/` に書き込まれます。

代わりに TrollStore パッケージをビルドするには:

```bash
make package TROLLSTORE_JIT_ENT=1
```

レンダラーのソース リンクとビルド ノートについては、[`note.md`](../../note.md) を参照してください。

---

<a id="languages"></a>
## 言語

Witch Launcher には**52 個の言語パック**が同梱されています。 **設定 → 一般 → 言語** を開いて言語を選択するか、**自動** を使用してデバイスの言語に従います。

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

アプリにはすべての **52 言語パック**が同梱されています。 README の翻訳は、英語を含む **52 言語すべて**で利用できます。

一部の翻訳は機械支援されており、扱いにくい専門用語が含まれている場合があります。修正は大歓迎です。

この README のソース言語は英語です。ローカライズされた README は、このページの上部にある言語セレクターおよび [`docs/readme/`](./) ディレクトリから入手できます。

---

<a id="notes-and-limitations"></a>
## 注意事項と制限事項

- **JIT は必須です。** JIT のセットアップが機能しないと、Minecraft は起動しません。
- **iOS 26/27 JIT は壊れやすいです。** StikDebug は接続されたままにしておく必要があり、将来の OS アップデートにより動作内容が変更される可能性があります。
- **実験的** とマークされたレンダラーは、クラッシュしたり、正しくレンダリングされなかったりする可能性があります。よくわからない場合は、**自動**から始めてください。
- **フレーム生成**には、MoltenVK レンダラと Metal コンピューティング サポートが必要です。バッテリーの使用量が増加し、デバイスの温度が上昇する可能性があります。
- 一部の MOD、MODPACK、シェーダー、およびワールドには、特定の Minecraft バージョン、ローダー、レンダラー、または追加のメモリが必要な場合があります。
- CurseForge modpack は `manifest.json` を使用します。ワンタップ インストールがパックで利用できない場合は、アーカイブを手動でインポートします。
- オンライン機能はサードパーティのサービスに依存しているため、利用できない場合があります。
- スクリーンショットは開発ビルドのものであり、現在のリリースと正確に一致しない場合があります。

---

<a id="project-lineage"></a>
## プロジェクトの系統

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

### 関連プロジェクト

- [Amethyst アンドロイド](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## 貢献する

バグレポートや PR は大歓迎です。問題を報告するときは、次のことを含めてください。

- デバイスモデルとiOS/iPadOSバージョン
- Witch Launcher バージョン
- レンダラーと Minecraft バージョン
- MODローダーとインストールされているMODのリスト
- 再現する手順
- 関連するログまたはクラッシュレポート

署名証明書、プロビジョニングプロファイル、API キー、またはその他のシークレットをコミットしないでください。

---

<a id="credits"></a>
## クレジット

**Witch Launcher** は **DuyAnh662 (Za_d626)** によって管理されています。

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### 上流とコミュニティ

Witch Launcher とその上流プロジェクトは、次のような多くの貢献者の成果に基づいて構築されています。

- **@crystall1nedev** — Amethyst プロジェクト マネージャーおよび iOS 移植開発者
- **@khanhduytran0** — iOS 移植開発者
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

さらに、**@lunixbochs**、**@ptitSeb**、**@kakashidinho**、ANGLE プロジェクト、Khronos Group、Mesa プロジェクト、PojavLauncher チーム、Mozilla、および Minecraft コミュニティに感謝します。

Minecraft アバター サービスを提供してくださった [MCHeads](https://mc-heads.net) に感謝します。

完全なサードパーティ コンポーネントとライセンスのリストは、[`credits.md`](../../credits.md) で入手できます。

---

<a id="license"></a>
## ライセンス

Witch Launcher は**GNU General Public License v3.0** に基づいて配布されており、[`credits.md`](../../credits.md) にリストされているサードパーティ コンポーネントのライセンスと著作権要件が適用されます。

完全なライセンステキストについては、[`LICENSE`](../../LICENSE) を参照してください。

---

<p align="center">
<sub>MinecraftはMojang Studiosの商標です。 Witch Launcher は Mojang Studios、Microsoft、または Amethyst プロジェクトに所属していません。</sub>
</p>
