<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition sa iPhone at iPad.</strong><br>
Isang iOS at iPadOS na tinidor ng Amethyst na binuo ng komunidad, na pinapanatili ng DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Mga Tampok](#features) · [Mga Screenshot](#screenshots) · [Mga Kinakailangan](#requirements) · [Pag-install](#installation) · [Mga Wika](#languages) · [Mga Kredito](#credits) · [Lisensya](#license)

<details>
<summary><strong>Mga wika</strong></summary>

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
## Tungkol sa

Ang **Witch Launcher** ay isang independiyenteng tinidor na pinapanatili ng komunidad ng [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) na nagdadala ng **Minecraft: Java Edition** sa iPhone at iPad. Pinagsasama nito ang isang touch-first launcher UI na may buong Java runtime manager, LWJGL, at isang graphics stack na binuo sa paligid ng Metal, MoltenVK, at OpenGL na mga layer ng pagsasalin.

Witch ay itinayo sa gawain ng [Boardwalk](https://github.com/zhuowei/Boardwalk), ang [PojavLauncher](https://github.com/PojavLauncherTeam) na komunidad, Amethyst-iOS, at Amethyst-iOS-25. Ito ay isang independiyenteng proyekto at hindi kaakibat ng Mojang Studios, Microsoft, o ng upstream Amethyst na pangkat.

> **Kasalukuyang bersyon:** 0.0.4 · Tingnan ang [`news.md`](../../news.md) para sa mga tala sa paglabas.

---

<a id="features"></a>
## Mga tampok

### Minecraft at mga mod

- Pinapatakbo ang karamihan ng **Minecraft: Java Edition** na bersyon, mula sa mga unang paglabas ng Beta hanggang sa pinakabagong mga snapshot.
- Sinusuportahan ang **Vanilla, Fabric, Quilt, Forge, NeoForge, at OptiFine**.
- Lumikha ng nakahiwalay na **mga profile ng laro** gamit ang sarili nilang mga setting, mod, shader, resource pack, at mundo.
- Mag-browse at mag-install ng nilalaman mula sa **Modrinth at CurseForge** nang hindi umaalis sa launcher:
  - mga mod
  - mga modpack
  - shader pack
  - mga resource pack
  - mga mapa ng pakikipagsapalaran at mundo
- Lutasin at i-install ang mga dependency ng mod kung saan ibinibigay ng pinagmulan ang mga ito.
- Mag-import ng Forge/NeoForge installer JAR at direktang mag-install ng Fabric/Quilt loader mula sa tagapili ng bersyon.

### Mga graphic at pagganap

- Lumipat sa pagitan ng maraming renderer mula sa **Mga Setting → Renderer at Display**:
  - **gl4es** — OpenGL 2.1 na landas ng compatibility
  - **ANGLE** — OpenGL ES hanggang Metal o Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimental
  - **Zink** — OpenGL 4.1 hanggang Mesa 25 at MoltenVK
  - **LTW** — OpenGL 3.3 hanggang OpenGL ES/Metal, Minecraft 1.17+, eksperimental
  - **TGLMT** — OpenGL 4.6 Core hanggang Metal, A11 Bionic o mas bago
- **TGLMT na may suportang Sodium at Iris** para sa modernong shader-based na mga setup.
- **Pagbuo ng Frame** gamit ang Motion-Adaptive GPU (MADI) at mga mode ng Camera 3D Reproject, kabilang ang temporal na interpolation at predictive extrapolation.
- Pag-scale ng resolution, maximum framerate, FSR 1.0 upscaling, GLSL shader cache, at per-renderer tuning.
- Performance HUD na may mga na-configure na FPS, CPU, GPU, RAM, temperatura, baterya, orasan, at frame-generation na FPS na mga widget.
- Built-in na pag-record ng pagganap na may mga chart, PNG/PDF pag-export, at pagbabahagi.

### Mga kontrol

- Ganap na nako-customize na on-screen control layout, laki ng button, at transparency.
- Suporta sa **keyboard at mouse**, kabilang ang virtual mouse at adjustable pointer speed.
- Suporta ng **Game controller** na may mga nako-configure na layout at sensitivity.
- **Gyroscope** na naglalayong may adjustable sensitivity at axis inversion.
- Mga galaw ng mouse, scroll, at hotbar.
- Opsyonal na gawi: i-tap upang maglagay ng mga bloke, pindutin nang matagal upang masira ang mga bloke.
- I-double tap ang hotbar upang palitan ang hawak na item sa off-hand.
- Slideable hotbar at adjustable long-press timing.

### Launcher at mga account

- **Microsoft**, **local/offline**, **demo**, at **Ely.by** na suporta sa account.
- Pamahalaan ang **Java 8, 17, 21, at 25** na mga runtime, i-download ang mga ito in-app, o i-import ang iyong sarili.
- Pumili ng LWJGL na mga bersyon at ibagay ang mga argumento ng JVM, mga variable ng kapaligiran, at paglalaan ng memorya.
- Auto RAM management para sa mga device na may limitadong memory.
- Mga tema, kulay ng accent, blur, mga hangganan, radius ng sulok, mga custom na font ng launcher, at mga icon ng app.
- In-game **F3 impormasyon ng device**: device chip, iOS bersyon, pangalan/bersyon ng launcher, numero ng build, at uri ng build.
- Opsyonal na **Witch Server**, CurseForge, at AI na mga pagsasama para sa mga advanced na setup.
- **52 in-app na wika**, kabilang ang right-to-left language pack at nakakatuwang mga lokal.

---

<a id="screenshots"></a>
## Mga screenshot

Mga screenshot mula sa pagbuo ng Witch Launcher 0.0.4. Maaaring magbago ang interface sa pagitan ng mga bersyon at tema.

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
## Mga kinakailangan

| Kinakailangan | Mga Detalye |
|---|---|
| **Device** | iPhone o iPad na may arm64 processor at Metal suporta |
| **System** | iOS o iPadOS **14.0 o mas bago** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Account** | Isang Microsoft account na nagmamay-ari ng Minecraft para sa mga opisyal na pag-download; lokal at demo mode ay magagamit din |
| **Imbakan** | Space para sa launcher, Java runtime, bersyon ng laro, mod, at mundo |
| **Network** | Kinakailangan para sa pag-sign in, pag-download ng bersyon, browser ng nilalaman, at mga opsyonal na serbisyong online |

Witch ay **hindi** kasama ang Minecraft mga file ng laro. Ang mga file ng laro ay dina-download sa pamamagitan ng launcher pagkatapos mag-sign in sa isang karapat-dapat na account.

### JIT mga tala

Kailangan ng Minecraft: Java Edition JIT, at hindi mailulunsad ng Witch ang laro nang wala ito.

- **SideStore / AltStore-style na mga pag-install:** paganahin ang JIT para sa Witch at panatilihing aktibo ang kinakailangang VPN/debugger na koneksyon. Ang in-app na mensahe ay tumutukoy sa **LocalDevVPN** at `CS_DEBUGGED`.
- **StikDebug:** ilakip ang StikDebug sa Witch at paganahin ang JIT. Sa **iOS 26/27**, StikDebug ay dapat manatiling nakadikit habang tumatakbo ang laro. Ang `UniversalJIT26.js` ay kinopya sa clipboard kung kinakailangan.
- **TrollStore:** paganahin ang **URL Scheme** sa TrollStore kung patuloy na naghihintay ang Witch para sa JIT.
- **Mga Jailbroken na device:** gamitin ang iyong ginustong JIT enabler.
- Kung mananatili ang launcher sa screen na **Naghihintay para sa JIT**, suriin ang koneksyon ng debugger, ang VPN, at ang setting ng TrollStore URL Scheme bago muling ilunsad.

Ang pag-uugali ng JIT ay nakasalalay sa iOS na bersyon at paraan ng pag-install. Maaaring sirain ng mga pag-update ng system ang mga umiiral nang JIT setup.

---

<a id="installation"></a>
## Pag-install

Dapat na naka-sign ang Witch para sa iyong device. Ang repositoryong ito ay hindi nagpapadala ng mga sertipiko o paunang nilagdaan na mga IPA.

### Gumamit ng build

1. Mag-download ng development build mula sa [development workflow](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), o gumamit ng sign na build mula sa source na pinagkakatiwalaan mo.
2. Lagdaan at i-install ito gamit ang **SideStore**, **AltStore**, **TrollStore**, o ang gusto mong paraan ng pag-sideload.
3. Paganahin ang JIT tulad ng inilarawan sa itaas bago ilunsad ang laro.

Gumagamit ang TrollStore build ng mga karagdagang entitlement at hindi dapat i-install gamit ang isang normal na sideloading signer.

### Bumuo mula sa pinagmulan

Ang pag-compile ng Witch ay nangangailangan ng macOS na may Xcode command-line tool, isang iOS SDK 14.0 o mas bago, CMake, JDK 8, `ldid`, `wget`, `zip`, at Git.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Ang mga naka-package na build ay isinulat sa `artifacts/`.

Upang bumuo ng TrollStore package sa halip:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Para sa mga link ng pinagmulan ng renderer at mga tala sa pagbuo, tingnan ang [`note.md`](../../note.md).

---

<a id="languages"></a>
## Mga wika

Witch Launcher nagpapadala ng **52 language pack**. Buksan ang **Mga Setting → Pangkalahatan → Wika** at pumili ng wika, o gamitin ang **Auto** upang sundin ang wika ng device.

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

Ipinapadala ng app ang lahat ng **52 language pack**. Available ang mga pagsasalin ng README para sa **lahat ng 52 wika**, kabilang ang Ingles.

Ang ilang pagsasalin ay tinulungan ng makina at maaaring maglaman ng mga awkward na teknikal na termino. Malugod na tinatanggap ang mga pagwawasto.

English ang source language para sa README na ito. Available ang mga naka-localize na README mula sa tagapili ng wika sa tuktok ng pahinang ito at sa direktoryo ng [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Mga tala at limitasyon

- Ang **JIT ay sapilitan.** Kung walang gumaganang JIT setup, Minecraft ay hindi ilulunsad.
- **iOS 26/27 JIT ay marupok.** StikDebug ay dapat manatiling naka-attach, at maaaring baguhin ng mga update sa OS sa hinaharap kung ano ang gumagana.
- Maaaring mag-crash o mali ang pag-render ng mga renderer na may markang **eksperimento**. Magsimula sa **Auto** kung hindi ka sigurado.
- Ang **Pagbuo ng Frame** ay nangangailangan ng MoltenVK renderer at Metal compute na suporta. Maaari nitong palakihin ang paggamit ng baterya at temperatura ng device.
- Ang ilang mod, modpack, shader, at mundo ay maaaring mangailangan ng partikular na Minecraft na bersyon, loader, renderer, o karagdagang memorya.
- CurseForge ang mga modpack ay gumagamit ng `manifest.json`; kung hindi available ang one-tap installation para sa isang pack, manual na i-import ang archive.
- Ang mga online na feature ay nakadepende sa mga third-party na serbisyo at maaaring hindi available.
- Ang mga screenshot ay mula sa isang development build at maaaring hindi eksaktong tumugma sa kasalukuyang release.

---

<a id="project-lineage"></a>
## Angkan ng proyekto

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

### Mga kaugnay na proyekto

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Nag-aambag

Malugod na tinatanggap ang mga ulat ng bug at PR. Kapag nag-uulat ng problema, isama ang:

- modelo ng device at bersyon ng iOS/iPadOS.
- Witch Launcher na bersyon
- renderer at Minecraft na bersyon
- mod loader at isang listahan ng mga naka-install na mod
- mga hakbang sa pagpaparami
- ang nauugnay na log o ulat ng pag-crash

Mangyaring huwag mag-commit ng pagpirma ng mga certificate, provisioning profile, API key, o iba pang mga lihim.

---

<a id="credits"></a>
## Mga kredito

Ang **Witch Launcher** ay pinapanatili ng **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream at komunidad

Witch Launcher at ang mga upstream na proyekto nito ay binuo sa gawain ng maraming nag-aambag, kabilang ang:

- **@crystall1nedev** — Amethyst project manager at iOS port developer
- **@khanhduytran0** — iOS developer ng port
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Karagdagang pasasalamat sa **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, sa ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla, at sa Minecraft na komunidad.

Espesyal na pasasalamat sa [MCHeads](https://mc-heads.net) para sa pagbibigay ng Minecraft serbisyo ng avatar.

Ang kumpletong third-party na bahagi at listahan ng lisensya ay available sa [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lisensya

Witch Launcher ay ipinamamahagi sa ilalim ng **GNU General Public License v3.0**, napapailalim sa mga lisensya at kinakailangan sa copyright ng mga third-party na bahagi na nakalista sa [`credits.md`](../../credits.md).

Tingnan ang [`LICENSE`](../../LICENSE) para sa kumpletong teksto ng lisensya.

---

<p align="center">
<sub>Minecraft ay isang trademark ng Mojang Studios. Witch Launcher ay hindi kaakibat sa Mojang Studios, Microsoft, o sa Amethyst proyekto.</sub>
</p>
