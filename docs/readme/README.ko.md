<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition, iPhone 및 iPad.</strong><br>
DuyAnh662(Za_d626)가 유지 관리하는 Amethyst의 커뮤니티 구축 iOS 및 iPadOS 포크입니다.
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[기능](#features) · [스크린샷](#screenshots) · [요구 사항](#requirements) · [설치](#installation) · [언어](#languages) · [크레딧](#credits) · [라이센스](#license)

<details>
<summary><strong>언어</strong></summary>

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
## 소개

**Witch Launcher**은 **Minecraft: Java Edition**를 iPhone 및 iPad로 가져오는 [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS)의 독립적인 커뮤니티 유지 포크입니다. 터치 우선 실행기 UI와 전체 Java 런타임 관리자, LWJGL 및 Metal, MoltenVK 및 OpenGL 번역 레이어를 중심으로 구축된 그래픽 스택을 결합합니다.

Witch는 [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) 커뮤니티, Amethyst-iOS 및 Amethyst-iOS-25의 작업을 기반으로 합니다. 이는 독립적인 프로젝트이며 Mojang Studios, Microsoft 또는 업스트림 Amethyst 팀과 관련이 없습니다.

> **현재 버전:** 0.0.4 · 출시 노트는 [`news.md`](../../news.md)을 참조하세요.

---

<a id="features"></a>
## 특징

### Minecraft 및 모드

- 초기 베타 릴리스부터 최신 스냅샷까지 대부분의 **Minecraft: Java Edition** 버전을 실행합니다.
- **바닐라, Fabric, Quilt, Forge, NeoForge 및 OptiFine**를 지원합니다.
- 고유한 설정, 모드, 셰이더, 리소스 팩 및 세계를 사용하여 격리된 **게임 프로필**을 만드세요.
- 실행기를 종료하지 않고 **Modrinth 및 CurseForge**의 콘텐츠를 검색하고 설치하세요.
  - 모드
  - 모드팩
  - 셰이더 팩
  - 리소스 팩
  - 모험 지도와 세계
- 소스가 제공하는 모드 종속성을 해결하고 설치합니다.
- Forge/NeoForge 설치 프로그램 JAR을 가져오고 버전 선택기에서 직접 Fabric/Quilt 로더를 설치합니다.

### 그래픽과 성능

- **설정 → 렌더러 및 디스플레이**에서 여러 렌더러 간 전환:
  - **gl4es** — OpenGL 2.1 호환성 경로
  - **ANGLE** — OpenGL ES부터 Metal 또는 Vulkan까지
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, 실험적
  - **Zink** — OpenGL 4.1부터 Mesa 25 및 MoltenVK
  - **LTW** — OpenGL 3.3 ~ OpenGL ES/Metal, Minecraft 1.17+, 실험적
  - **TGLMT** — OpenGL 4.6 코어부터 Metal, A11 Bionic 이상
- 최신 셰이더 기반 설정을 위한 **TGLMT 및 Sodium 및 Iris 지원**.
- 시간적 보간 및 예측 외삽을 포함한 모션 적응형 GPU(MADI) 및 카메라 3D 재투영 모드를 사용한 **프레임 생성**.
- 해상도 조정, 최대 프레임 속도, FSR 1.0 업스케일링, GLSL 셰이더 캐시 및 렌더러별 조정.
- 구성 가능한 FPS, CPU, GPU, RAM, 온도, 배터리, 시계 및 프레임 생성 FPS 위젯을 갖춘 성능 HUD.
- 차트, PNG/PDF 내보내기 및 공유 기능이 포함된 성능 기록이 내장되어 있습니다.

### 컨트롤

- 화면 컨트롤 레이아웃, 버튼 크기 및 투명도를 완전히 사용자 정의할 수 있습니다.
- 가상 마우스 및 조정 가능한 포인터 속도를 포함한 **키보드 및 마우스** 지원.
- 구성 가능한 레이아웃과 감도로 **게임 컨트롤러**를 지원합니다.
- 조정 가능한 감도와 축 반전으로 조준하는 **자이로스코프**.
- 마우스, 스크롤, 핫바 제스처.
- 선택적 동작: 블록을 배치하려면 탭하고, 블록을 부수려면 길게 누르세요.
- 핫바를 두 번 탭하면 들고 있는 아이템을 보조 손으로 바꿀 수 있습니다.
- 슬라이드 가능한 핫바 및 조정 가능한 길게 누르기 타이밍.

### 런처 및 계정

- **Microsoft**, **로컬/오프라인**, **데모** 및 **Ely.by** 계정 지원.
- **Java 8, 17, 21 및 25** 런타임을 관리하고 앱 내에서 다운로드하거나 직접 가져오세요.
- LWJGL 버전을 선택하고 JVM 인수, 환경 변수 및 메모리 할당을 조정합니다.
- 메모리가 제한된 장치에 대한 자동 RAM 관리.
- 테마, 강조 색상, 흐림, 테두리, 모서리 반경, 사용자 정의 런처 글꼴 및 앱 아이콘.
- 게임 내 **F3 장치 정보**: 장치 칩, iOS 버전, 실행기 이름/버전, 빌드 번호 및 빌드 유형.
- 고급 설정을 위한 선택적 **Witch 서버**, CurseForge 및 AI 통합.
- 오른쪽에서 왼쪽으로 쓰는 언어 팩과 재미있는 로케일을 포함하여 **52개의 인앱 언어**.

---

<a id="screenshots"></a>
## 스크린샷

Witch Launcher 0.0.4 개발 빌드의 스크린샷. 인터페이스는 버전과 테마 간에 변경될 수 있습니다.

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
## 요구사항

| 요구사항 | 세부정보 |
|---|---|
| **기기** | arm64 프로세서 및 Metal 지원이 포함된 iPhone 또는 iPad |
| **시스템** | iOS 또는 iPadOS **14.0 이상** |
| **JIT** | 필수의. JIT부터 StikDebug, SideStore, TrollStore 또는 탈옥 설정 활성화 |
| **계정** | 공식 다운로드에 대해 Minecraft을 소유한 Microsoft 계정 로컬 및 데모 모드도 사용 가능 |
| **저장용량** | 런처, Java 런타임, 게임 버전, 모드 및 월드를 위한 공간 |
| **네트워크** | 로그인, 버전 다운로드, 콘텐츠 브라우저 및 선택적 온라인 서비스에 필요 |

Witch에는 Minecraft 게임 파일이 포함되지 **않습니다**. 게임 파일은 적격 계정에 로그인한 후 런처를 통해 다운로드됩니다.

### JIT 메모

Minecraft: Java Edition에는 JIT이 필요하며 Witch은 Witch 없이는 게임을 시작할 수 없습니다.

- **SideStore / AltStore 스타일 설치:** Witch에 대해 JIT를 활성화하고 필수 VPN/디버거 연결을 활성 상태로 유지합니다. 인앱 메시지는 **LocalDevVPN** 및 `CS_DEBUGGED`를 참조합니다.
- **StikDebug:** StikDebug을 Witch에 첨부하고 JIT을 활성화합니다. **iOS 26/27**에는 게임이 실행되는 동안 StikDebug가 계속 연결되어 있어야 합니다. `UniversalJIT26.js`은 필요할 때 클립보드에 복사됩니다.
- **TrollStore:** Witch이 JIT을 계속 기다리는 경우 TrollStore에서 **URL Scheme**를 활성화합니다.
- **탈옥된 기기:** 선호하는 JIT 인에이블러를 사용하세요.
- 런처가 **JIT 대기 중** 화면에 계속 표시되면 다시 시작하기 전에 디버거 연결, VPN 및 TrollStore URL Scheme 설정을 확인하세요.

JIT 동작은 iOS 버전 및 설치 방법에 따라 다릅니다. 시스템 업데이트로 인해 기존 JIT 설정이 중단될 수 있습니다.

---

<a id="installation"></a>
## 설치

귀하의 장치에 대해 Witch에 서명해야 합니다. 이 저장소는 인증서나 사전 서명된 IPA를 제공하지 않습니다.

### 빌드 사용

1. [개발 워크플로](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)에서 개발 빌드를 다운로드하거나 신뢰할 수 있는 소스에서 서명된 빌드를 사용하세요.
2. **SideStore**, **AltStore**, **TrollStore** 또는 선호하는 사이드로딩 방법으로 서명하고 설치하세요.
3. 게임을 시작하기 전에 위에서 설명한 대로 JIT을 활성화하세요.

TrollStore 빌드는 추가 권한을 사용하므로 일반 사이드로딩 서명자와 함께 설치하면 안 됩니다.

### 소스에서 빌드

Witch을 컴파일하려면 Xcode 명령줄 도구가 포함된 macOS, iOS SDK 14.0 이상, CMake, JDK 8, `ldid`, `wget`, `zip` 및 Git이 필요합니다.

```bash
git clone --재귀 https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

패키지된 빌드는 `artifacts/`에 기록됩니다.

대신 TrollStore 패키지를 빌드하려면:

```bash
make package TROLLSTORE_JIT_ENT=1
```

렌더러 소스 링크 및 빌드 노트는 [`note.md`](../../note.md)을 참조하세요.

---

<a id="languages"></a>
## 언어

Witch Launcher은 **52개 언어 팩**과 함께 제공됩니다. **설정 → 일반 → 언어**를 열고 언어를 선택하거나 **자동**을 사용하여 기기 언어를 따릅니다.

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

이 앱은 **52개 언어 팩**을 모두 제공합니다. README 번역은 영어를 포함한 **52개 언어** 모두에 제공됩니다.

일부 번역은 기계의 도움을 받아 어색한 기술 용어가 포함될 수 있습니다. 수정을 환영합니다.

이 README의 소스 언어는 영어입니다. 현지화된 README는 이 페이지 상단의 언어 선택기와 [`docs/readme/`](./) 디렉토리에서 사용할 수 있습니다.

---

<a id="notes-and-limitations"></a>
## 참고 및 제한사항

- **JIT은 필수입니다.** 작동하는 JIT 설정이 없으면 Minecraft가 실행되지 않습니다.
- **iOS 26/27 JIT은 취약합니다.** StikDebug는 첨부된 상태로 유지되어야 하며 향후 OS 업데이트로 인해 작동 방식이 변경될 수 있습니다.
- **실험용**으로 표시된 렌더러는 작동이 중단되거나 잘못 렌더링될 수 있습니다. 확실하지 않으면 **자동**으로 시작하세요.
- **프레임 생성**에는 MoltenVK 렌더러 및 Metal 컴퓨팅 지원이 필요합니다. 배터리 사용량과 장치 온도가 높아질 수 있습니다.
- 일부 모드, 모드팩, 셰이더 및 세계에는 특정 Minecraft 버전, 로더, 렌더러 또는 추가 메모리가 필요할 수 있습니다.
- CurseForge 모드팩은 `manifest.json`를 사용합니다. 팩에 대해 원탭 설치를 사용할 수 없는 경우 아카이브를 수동으로 가져옵니다.
- 온라인 기능은 타사 서비스에 따라 다르며 사용하지 못할 수도 있습니다.
- 스크린샷은 개발 빌드에서 가져온 것이므로 현재 릴리스와 정확히 일치하지 않을 수 있습니다.

---

<a id="project-lineage"></a>
## 프로젝트 계보

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

### 관련 프로젝트

- [Amethyst 안드로이드](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## 기여

버그 보고서와 PR을 환영합니다. 문제를 보고할 때 다음을 포함하십시오.

- 장치 모델 및 iOS/iPadOS 버전
- Witch Launcher 버전
- 렌더러 및 Minecraft 버전
- 모드 로더 및 설치된 모드 목록
- 재현하는 단계
- 관련 로그 또는 충돌 보고서

서명 인증서, 프로비저닝 프로필, API 키 또는 기타 비밀을 커밋하지 마세요.

---

<a id="credits"></a>
## 크레딧

**Witch Launcher**은 **DuyAnh662(Za_d626)**에서 관리합니다.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### 업스트림 및 커뮤니티

Witch Launcher 및 해당 업스트림 프로젝트는 다음을 포함한 많은 기여자의 작업을 기반으로 구축되었습니다.

- **@crystall1nedev** — Amethyst 프로젝트 관리자 및 iOS 포트 개발자
- **@khanhduytran0** — iOS 포트 개발자
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

**@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE 프로젝트, Khronos Group, Mesa 프로젝트, PojavLauncher Team, Mozilla 및 Minecraft 커뮤니티에도 감사드립니다.

Minecraft 아바타 서비스를 제공해 주신 [MCHeads](https://mc-heads.net)에게 특별히 감사드립니다.

전체 타사 구성 요소 및 라이선스 목록은 [`credits.md`](../../credits.md)에서 확인할 수 있습니다.

---

<a id="license"></a>
## 라이센스

Witch Launcher은 **GNU General Public License v3.0**에 따라 배포되며 [`credits.md`](../../credits.md)에 나열된 타사 구성 요소의 라이센스 및 저작권 요구 사항이 적용됩니다.

전체 라이센스 텍스트는 [`LICENSE`](../../LICENSE)을 참조하세요.

---

<p align="center">
<sub>Minecraft는 Mojang Studios의 상표입니다. Witch Launcher는 Mojang Studios, Microsoft 또는 Amethyst 프로젝트와 관련이 없습니다.</sub>
</p>
