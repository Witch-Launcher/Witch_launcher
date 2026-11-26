<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition pe iPhone și iPad.</strong><br>
O furcă iOS și iPadOS construită de comunitate din Amethyst, întreținută de DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funcții](#features) · [Capturi de ecran](#screenshots) · [Cerințe](#requirements) · [Instalare](#installation) · [Limbi](#languages) · [Credite](#credits) · [Licență](#license)

<details>
<summary><strong>Limbi</strong></summary>

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
## Despre

**Witch Launcher** este o bifurcătură independentă, întreținută de comunitate, a [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) care aduce **Minecraft: Java Edition** la iPhone și iPad. Acesta combină o interfață de utilizare cu lansare prin atingere cu un manager de rulare complet Java, LWJGL și o stivă grafică construită în jurul straturilor de traducere Metal, MoltenVK și OpenGL.

Witch este construit pe lucrarea [Boardwalk](https://github.com/zhuowei/Boardwalk), comunitatea [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS și Amethyst-iOS-25. Este un proiect independent și nu este afiliat la Mojang Studios, Microsoft sau echipa din amonte Amethyst.

> **Versiunea curentă:** 0.0.4 · Consultați [`news.md`](../../news.md) pentru notele de lansare.

---

<a id="features"></a>
## Caracteristici

### Minecraft și mods

- Rulează majoritatea versiunilor **Minecraft: Java Edition**, de la versiunile Beta timpurii până la cele mai recente instantanee.
- Acceptă **Vanilla, Fabric, Quilt, Forge, NeoForge și OptiFine**.
- Creați **profiluri de joc** izolate cu propriile setări, modificări, shadere, pachete de resurse și lumi.
- Răsfoiți și instalați conținut din **Modrinth și CurseForge** fără a părăsi lansatorul:
  - moduri
  - modpack-uri
  - pachete de shader
  - pachete de resurse
  - hărți și lumi de aventură
- Rezolvați și instalați dependențele de mod acolo unde le furnizează sursa.
- Importați JAR-urile de instalare Forge/NeoForge și instalați încărcătoarele Fabric/Quilt direct din selectorul de versiuni.

### Grafică și performanță

- Comutați între mai multe randări din **Setări → Redare și afișare**:
  - **gl4es** — calea de compatibilitate OpenGL 2.1
  - **ANGLE** — OpenGL ES până la Metal sau Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimental
  - **Zink** — OpenGL 4.1 până la Mesa 25 și MoltenVK
  - **LTW** — OpenGL 3.3 până la OpenGL ES/Metal, Minecraft 1.17+, experimental
  - **TGLMT** — OpenGL 4.6 De bază până la Metal, A11 Bionic sau mai nou
- **TGLMT cu suport Sodium și Iris** pentru setările moderne bazate pe shader.
- **Generare cadre** cu GPU adaptabil la mișcare (MADI) și moduri de reproiectare 3D a camerei, inclusiv interpolare temporală și extrapolare predictivă.
- Scalarea rezoluției, ratele maxime de cadre, upscaling FSR 1.0, cache-uri de shader GLSL și reglaj per-renderer.
- HUD de performanță cu FPS configurabile, CPU, GPU, RAM, temperatură, baterie, ceas și widget-uri FPS pentru generarea de cadre.
- Înregistrare de performanță încorporată cu diagrame, export PNG/PDF și partajare.

### Controale

- Aspecte de control pe ecran, dimensiunile butoanelor și transparență complet personalizabile.
- Suport pentru **tastatură și mouse**, inclusiv un mouse virtual și viteză reglabilă a indicatorului.
- Compatibilitate cu **controler de joc** cu aspecte configurabile și sensibilitate.
- **Giroscop** vizat cu sensibilitate reglabilă și inversare a axei.
- Gesturi cu mouse-ul, derulare și bară rapidă.
- Comportament opțional: atingeți pentru a plasa blocuri, țineți apăsat pentru a rupe blocurile.
- Atingeți de două ori bara de acces rapid pentru a schimba elementul reținut în mână.
- Bară rapidă glisabilă și sincronizare reglabilă pentru apăsare lungă.

### Lansatorul și conturile

- Suport pentru conturi **Microsoft**, **local/offline**, **demo** și **Ely.by**.
- Gestionați **Java 8, 17, 21 și 25** timpii de execuție, descărcați-le în aplicație sau importați-le pe ale dvs.
- Selectați versiunile LWJGL și reglați argumentele JVM, variabilele de mediu și alocarea memoriei.
- Administrare automată a memoriei RAM pentru dispozitivele cu memorie limitată.
- Teme, culori de accent, estompare, chenare, raza colțului, fonturi personalizate de lansare și pictograme pentru aplicații.
- **Informații despre dispozitiv F3** în joc: cip dispozitiv, versiune iOS, numele/versiunea lansatorului, numărul versiunii și tipul versiunii.
- Integrari opționale **Witch Server**, CurseForge și AI pentru setări avansate.
- **52 de limbi în aplicație**, inclusiv pachete de limbi de la dreapta la stânga și locații distractive.

---

<a id="screenshots"></a>
## Capturi de ecran

Capturi de ecran dintr-o versiune de dezvoltare a Witch Launcher 0.0.4. Interfața se poate schimba între versiuni și teme.

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
## Cerințe

| Cerință | Detalii |
|---|---|
| **Dispozitiv** | iPhone sau iPad cu un procesor arm64 și suport Metal |
| **Sistem** | iOS sau iPadOS **14.0 sau mai nou** |
| **JIT** | Necesar. Activați JIT până la StikDebug, SideStore, TrollStore sau o configurare jailbreak |
| **Cont** | Un cont Microsoft care deține Minecraft pentru descărcări oficiale; modurile locale și demo sunt, de asemenea, disponibile |
| **Depozitare** | Spațiu pentru lansator, timpi de rulare Java, versiuni de joc, moduri și lumi |
| **Rețea** | Necesar pentru conectare, descărcări de versiuni, browser de conținut și servicii online opționale |

Witch **nu** include fișierele de joc Minecraft. Fișierele jocului sunt descărcate prin intermediul lansatorului după conectarea la un cont eligibil.

### JIT note

Minecraft: Java Edition are nevoie de JIT, iar Witch nu poate lansa jocul fără el.

- **Instalări în stilul SideStore / AltStore:** activați JIT pentru Witch și păstrați conexiunea necesară VPN/depanator activă. Mesajul din aplicație se referă la **LocalDevVPN** și `CS_DEBUGGED`.
- **StikDebug:** atașați StikDebug la Witch și activați JIT. În **iOS 26/27**, StikDebug trebuie să rămână atașat în timp ce jocul rulează. `UniversalJIT26.js` este copiat în clipboard atunci când este necesar.
- **TrollStore:** activați **URL Scheme** în TrollStore dacă Witch așteaptă în continuare JIT.
- **Dispozitive cu jailbreak:** utilizați dispozitivul de activare JIT preferat.
- Dacă lansatorul rămâne pe ecranul **Așteptați JIT**, verificați conexiunea la depanator, setarea VPN și TrollStore URL Scheme înainte de a relansa.

Comportamentul JIT depinde de versiunea iOS și metoda de instalare. Actualizările de sistem pot rupe setările existente JIT.

---

<a id="installation"></a>
## Instalare

Witch trebuie semnat pentru dispozitivul dvs. Acest depozit nu livrează certificate sau IPA-uri presemnate.

### Utilizați o construcție

1. Descărcați o versiune de dezvoltare din [fluxul de lucru de dezvoltare](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) sau utilizați o versiune semnată dintr-o sursă în care aveți încredere.
2. Semnează-l și instalează-l cu **SideStore**, **AltStore**, **TrollStore** sau metoda ta preferată de încărcare laterală.
3. Activați JIT așa cum este descris mai sus înainte de a lansa jocul.

Versiunile TrollStore folosesc drepturi suplimentare și nu ar trebui să fie instalate cu un semnatar normal de încărcare laterală.

### Construiți din sursă

Compilarea Witch necesită macOS cu instrumente de linie de comandă Xcode, un iOS SDK 14.0 sau mai nou, CMake, JDK 8, `ldid`, `wget`, `zip` și Git.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Compilările împachetate sunt scrise la `artifacts/`.

Pentru a construi un pachet TrollStore în schimb:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Pentru legăturile sursei de redare și notele de compilare, consultați [`note.md`](../../note.md).

---

<a id="languages"></a>
## Limbi

Witch Launcher se livrează cu **52 pachete de limbi**. Deschideți **Setări → General → Limbă** și selectați o limbă sau utilizați **Automat** pentru a urmări limba dispozitivului.

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

Aplicația livrează toate **pachetele de limbi 52**. Traducerile README sunt disponibile pentru **toate cele 52 de limbi**, inclusiv engleza.

Unele traduceri sunt asistate de mașini și pot conține termeni tehnici incomozi. Corecțiile sunt binevenite.

Engleza este limba sursă pentru acest README. README-urile localizate sunt disponibile din selectorul de limbă din partea de sus a acestei pagini și în directorul [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Note și limitări

- **JIT este obligatoriu.** Fără o configurare funcțională JIT, Minecraft nu se va lansa.
- **iOS 26/27 JIT este fragil.** StikDebug trebuie să rămână atașat, iar actualizările viitoare ale sistemului de operare pot schimba ceea ce funcționează.
- Renderele marcate ca **experimentale** se pot bloca sau se pot randa incorect. Începeți cu **Automat** dacă nu sunteți sigur.
- **Generarea cadrelor** necesită redarea MoltenVK și suport de calcul Metal. Poate crește utilizarea bateriei și temperatura dispozitivului.
- Unele moduri, modpack-uri, shadere și lumi pot necesita o anumită versiune Minecraft, încărcător, redare sau memorie suplimentară.
- CurseForge modpack-urile folosesc `manifest.json`; dacă instalarea cu o singură atingere nu este disponibilă pentru un pachet, importați arhiva manual.
- Funcțiile online depind de serviciile terță parte și pot fi indisponibile.
- Capturile de ecran sunt dintr-o versiune de dezvoltare și este posibil să nu se potrivească exact cu versiunea curentă.

---

<a id="project-lineage"></a>
## descendența proiectului

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

### Proiecte conexe

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contribuind

Rapoartele de erori și PR-urile sunt binevenite. Când raportați o problemă, includeți:

- modelul dispozitivului și versiunea iOS/iPadOS
- Witch Launcher versiunea
- redator și versiunea Minecraft
- încărcător de mod și o listă de mod-uri instalate
- pașii de reproducere
- jurnalul relevant sau raportul de blocare

Vă rugăm să nu comite certificate de semnare, profiluri de furnizare, chei API sau alte secrete.

---

<a id="credits"></a>
## Credite

**Witch Launcher** este întreținut de **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### În amonte și comunitate

Witch Launcher și proiectele sale din amonte sunt construite pe munca multor colaboratori, inclusiv:

- **@crystall1nedev** — manager de proiect Amethyst și dezvoltator de porturi iOS
- **@khanhduytran0** — dezvoltator de porturi iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Mulțumiri suplimentare pentru **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, Proiectul ANGLE, Grupul Khronos, Proiectul Mesa, Echipa PojavLauncher, Mozilla și comunitatea Minecraft.

Mulțumiri speciale lui [MCHeads](https://mc-heads.net) pentru furnizarea serviciilor de avatar Minecraft.

Lista completă a componentelor terță parte și a licențelor este disponibilă în [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licență

Witch Launcher este distribuit sub **GNU General Public License v3.0**, sub rezerva licențelor și cerințelor privind drepturile de autor ale componentelor terțe enumerate în [`credits.md`](../../credits.md).

Consultați [`LICENSE`](../../LICENSE) pentru textul complet al licenței.

---

<p align="center">
<sub>Minecraft este o marcă comercială a Mojang Studios. Witch Launcher nu este afiliat cu Mojang Studios, Microsoft sau cu proiectul Amethyst.</sub>
</p>
