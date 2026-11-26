<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
  <strong>Minecraft: Java kiadás a iPhone és iPad.</strong><br> rendszereken
Egy közösség által épített iOS és iPadOS fork of Amethyst, fenntartó DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funkciók](#features) · [Képernyőképek](#screenshots) · [Követelmények](#requirements) · [Telepítés](#installation) · [Nyelvek](#languages) · [Kiadók](#credits) · [Licenc](#license)

<details>
<summary><strong>Nyelvek</strong></summary>

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
## Körülbelül

A **Witch Launcher** a [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) független, közösség által karbantartott villája, amely a **Minecraft: Java Edition** elemet hozza létre a iPhone és iPad között. Egy érintéssel indítható kezelőfelületet kombinál egy teljes Java futásidejű kezelővel (LWJGL), valamint egy grafikus veremmel, amely a Metal, MoltenVK és OpenGL fordítási rétegek köré épül.

Witch [Boardwalk](https://github.com/zhuowei/Boardwalk), a [PojavLauncher](https://github.com/PojavLauncherTeam) közösség, Amethyst-iOS és Amethyst-iOS-25 munkájára épül. Ez egy független projekt, és nem áll kapcsolatban a Mojang Studios, Microsoft vagy az upstream Amethyst csapatával.

> **Jelenlegi verzió:** 0.0.4 · Lásd a [`news.md`](../../news.md) kiadási megjegyzéseket.

---

<a id="features"></a>
## Jellemzők

### Minecraft és módosítások

- A legtöbb **Minecraft: Java Edition** verziót futtatja, a korai bétaverzióktól a legújabb pillanatképekig.
- Támogatja: **Vanilla, Fabric, Quilt, Forge, NeoForge és OptiFine**.
- Hozzon létre elszigetelt **játékprofilokat** saját beállításokkal, modokkal, shaderekkel, erőforráscsomagokkal és világokkal.
- Böngésszen és telepítsen a **Modrinth és CurseForge** tartalmaiban anélkül, hogy elhagyná az indítót:
  - modok
  - modpacks
  - shader csomagok
  - erőforrás csomagok
  - kalandtérképek és világok
- Oldja fel és telepítse a mod-függőségeket ott, ahol a forrás biztosítja azokat.
- Importálja a Forge/NeoForge telepítő JAR-okat, és telepítse az Fabric/Quilt betöltőket közvetlenül a verzióválasztóból.

### Grafika és teljesítmény

- Váltson több megjelenítő között a **Beállítások → Renderer és megjelenítés** menüpontban:
  - **gl4es** – OpenGL 2.1 kompatibilitási útvonal
  - **ANGLE** – ES OpenGL–Metal vagy Vulkan
  - **MobileGlues** – OpenGL 4.0, Minecraft 1.17+, kísérleti
  - **Zink** – OpenGL 4.1 – Mesa 25 és MoltenVK
  - **LTW** – OpenGL 3.3 – OpenGL ES/Metal, Minecraft 1.17+, kísérleti
  - **TGLMT** – OpenGL 4.6 Core a Metal, A11 Bionic vagy újabb
- **TGLMT Sodium és Iris támogatással** a modern shader-alapú beállításokhoz.
- **Keretek generálása** Mozgásadaptív GPU-val (MADI) és Camera 3D Reproject módokkal, beleértve az időbeli interpolációt és a prediktív extrapolációt.
- Felbontás skálázás, maximális képkocka sebesség, FSR 1.0 felskálázás, GLSL shader gyorsítótárak és rendererenkénti hangolás.
- Teljesítményű HUD konfigurálható FPS, CPU, GPU, RAM, hőmérséklet, akkumulátor, óra és keretgenerációs FPS widgetekkel.
- Beépített teljesítményrögzítés diagramokkal, PNG/PDF exportálás és megosztás.

### Vezérlők

- Teljesen testreszabható a képernyőn megjelenő vezérlőelrendezések, gombméretek és átlátszóság.
- **Billentyűzet és egér** támogatás, beleértve a virtuális egeret és az állítható mutatósebességet.
- **Játékvezérlő** támogatás konfigurálható elrendezésekkel és érzékenységgel.
- **Giroszkóp** célzás állítható érzékenységgel és tengelyfordítással.
- Egér, görgetés és hotbar gesztusok.
- Választható viselkedés: érintse meg a blokkok elhelyezéséhez, tartsa lenyomva a blokkok töréséhez.
- Koppintson duplán a hotbar-ra, hogy a tartott elemet kéznél lévőre cserélje.
- Csúsztatható hotbar és állítható hosszan megnyomható időzítés.

### Indító és fiókok

- **Microsoft**, **helyi/offline**, **demó** és **Ely.by** fióktámogatás.
- Kezelje a **Java 8., 17., 21. és 25. szakasza** futtatókörnyezetet, töltse le őket az alkalmazáson belül, vagy importálja a sajátját.
- Válassza ki a LWJGL verziókat, és hangolja be a JVM argumentumokat, környezeti változókat és memóriafoglalást.
- Automatikus RAM-kezelés korlátozott memóriával rendelkező eszközökhöz.
- Témák, kiemelő színek, elmosódás, szegélyek, saroksugár, egyéni indítóbetűtípusok és alkalmazásikonok.
- Játékon belüli **F3 eszközinformáció**: eszközchip, iOS verzió, indító neve/verziója, build száma és build típusa.
- Opcionális **Witch Szerver**, CurseForge és AI integráció a speciális beállításokhoz.
- **52 alkalmazáson belüli nyelv**, köztük jobbról balra haladó nyelvi csomagok és szórakoztató nyelvek.

---

<a id="screenshots"></a>
## Képernyőképek

Képernyőképek a Witch Launcher 0.0.4 fejlesztői buildből. A felület változhat a verziók és a témák között.

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
## Követelmények

| Követelmény | Részletek |
|---|---|
| **Eszköz** | iPhone vagy iPad arm64 processzorral és Metal támogatással |
| **Rendszer** | iOS vagy iPadOS **14.0 vagy újabb** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Account** | A Microsoft account that owns Minecraft for official downloads; local and demo modes are also available |
| **Tárolás** | Hely az indítóhoz, Java futási idők, játékverziók, modok és világok |
| **Hálózat** | Szükséges a bejelentkezéshez, a verzióletöltésekhez, a tartalomböngészőhöz és az opcionális online szolgáltatásokhoz |

A Witch **nem** tartalmazza a Minecraft játékfájlokat. A játékfájlok letöltése az indítón keresztül történik, miután bejelentkezett egy jogosult fiókba.

### JIT megjegyzések

A Minecraft: Java Edition-nek szüksége van a JIT-re, és a Witch nélküle nem tudja elindítani a játékot.

- **SideStore / AltStore-stílusú telepítések:** engedélyezze a JIT-t a Witch-hoz, és tartsa aktívan a szükséges VPN/hibakereső kapcsolatot. Az alkalmazáson belüli üzenet a **LocalDevVPN** és `CS_DEBUGGED`-ra vonatkozik.
- **StikDebug:** csatlakoztassa a StikDebug-t a Witch-hez, és engedélyezze a JIT-t. A **iOS 26/27** esetén a StikDebug-nek csatlakoztatva kell maradnia, amíg a játék fut. A `UniversalJIT26.js` szükség esetén a vágólapra másolódik.
- **TrollStore:** engedélyezze a **URL Scheme** elemet a TrollStore-ben, ha a Witch folyamatosan a JIT-re vár.
- **Jailbreakelt eszközök:** használja a preferált JIT engedélyezőt.
- Ha az indító a **Várakozás a JIT-ra** képernyőn marad, az újraindítás előtt ellenőrizze a hibakereső kapcsolatot, a VPN-t és a TrollStore URL Scheme beállítást.

JIT viselkedés a iOS verziótól és a telepítési módtól függ. A rendszerfrissítések megszakíthatják a meglévő JIT beállításokat.

---

<a id="installation"></a>
## Telepítés

Witch alá kell írni az eszközön. Ez az adattár nem szállít tanúsítványokat vagy előre aláírt IPA-kat.

### Használjon buildet

1. Töltse le a fejlesztési buildet a [fejlesztési munkafolyamatból] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml), vagy használjon aláírt buildet egy megbízható forrásból.
2. Írja alá és telepítse a **SideStore**, **AltStore**, **TrollStore** vagy az Ön által előnyben részesített oldalbetöltési módszerrel.
3. A játék indítása előtt engedélyezze a JIT-t a fent leírtak szerint.

A TrollStore buildek további jogosultságokat használnak, és nem telepíthetők normál oldalbetöltés aláíróval.

### Forrásból építeni

A Witch fordításához a macOS Xcode parancssori eszközökkel, egy iOS SDK 14.0 vagy újabb, CMake, JDK 8, `ldid`, `wget`, `zip` és Git.

```bash
git klón -- rekurzív https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

A csomagolt buildek a `artifacts/` szerint vannak írva.

Ha helyette egy TrollStore csomagot szeretne létrehozni:

```bash
make package TROLLSTORE_JIT_ENT=1
```

A megjelenítő forráshivatkozásaiért és összeállítási megjegyzéseiért lásd: [`note.md`](../../note.md).

---

<a id="languages"></a>
## Nyelvek

Witch Launcher **52 nyelvi csomaggal** szállítjuk. Nyissa meg a **Beállítások → Általános → Nyelv** lehetőséget, és válasszon nyelvet, vagy használja az **Automatikus** lehetőséget az eszköz nyelvének követéséhez.

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

Az alkalmazás mind az **52 nyelvi csomagot** szállítja. A README fordítások **mind az 52 nyelvre** elérhetők, beleértve az angolt is.

Egyes fordítások gépi segítséggel készülnek, és kínos szakkifejezéseket tartalmazhatnak. Helyesbítéseket szívesen fogadunk.

A README forrásnyelve az angol. A lokalizált README-k az oldal tetején található nyelvválasztóból és a [`docs/readme/`](./) könyvtárból érhetők el.

---

<a id="notes-and-limitations"></a>
## Megjegyzések és korlátozások

- **JIT kötelező.** Működő JIT beállítás nélkül a Minecraft nem indul el.
- **iOS 26/27 A JIT törékeny.** A StikDebug-nek csatolva kell maradnia, és a jövőbeli operációs rendszer-frissítések megváltoztathatják a működést.
- A **kísérleti** megjelölésű megjelenítők összeomolhatnak vagy hibásan jelenhetnek meg. Kezdje az **Automatikus** beállítással, ha nem biztos benne.
- A **Keretek létrehozásához** a MoltenVK megjelenítő és a Metal szerinti számítási támogatás szükséges. Növelheti az akkumulátorhasználatot és az eszköz hőmérsékletét.
- Egyes modokhoz, modpackokhoz, shaderekhez és világokhoz speciális Minecraft-os verzióra, betöltőre, renderelőre vagy további memóriára lehet szükség.
- CurseForge modpackok a `manifest.json`-t használják; ha egy csomaghoz nem érhető el az egyérintéses telepítés, importálja manuálisan az archívumot.
- Az online funkciók harmadik féltől származó szolgáltatásoktól függenek, és előfordulhat, hogy nem érhetők el.
- A képernyőképek fejlesztői összeállításból származnak, és előfordulhat, hogy nem egyeznek pontosan az aktuális kiadással.

---

<a id="project-lineage"></a>
## Projekt származás

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

### Kapcsolódó projektek

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Hozzájárulás

Várjuk a hibajelentéseket és a PR-okat. Probléma bejelentésekor adja meg:

- készülékmodell és iOS/iPadOS verzió
- Witch Launcher változat
- renderelő és Minecraft változat
- mod betöltő és a telepített modok listája
- szaporodási lépések
- a vonatkozó napló vagy hibajelentés

Kérjük, ne írjon alá tanúsítványokat, létesítési profilokat, API szerinti kulcsokat vagy más titkot.

---

<a id="credits"></a>
## Kredit

**Witch Launcher** a **DuyAnh662 (Za_d626)** karbantartója.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream és közösség

Witch Launcher és annak upstream projektjei számos közreműködő munkájára épülnek, többek között:

- **@crystall1nedev** — Amethyst projektmenedzser és iOS portfejlesztő
- **@khanhduytran0** – iOS portfejlesztő
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

További köszönet: **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, a ANGLE Project, a Khronos Group, a Mesa Project, a PojavLauncher Team, a Mozilla és a Minecraft közösség.

Külön köszönet [MCHeads](https://mc-heads.net) a Minecraft avatarszolgáltatásokért.

A harmadik féltől származó összetevők és licencek teljes listája a [`credits.md`]-ban (credits.md) érhető el.

---

<a id="license"></a>
## Engedély

Witch Launcher is distributed under the **GNU General Public License v3.0**, subject to the licenses and copyright requirements of the third-party components listed in [`credits.md`](../../credits.md).

Az engedély teljes szövegét lásd [`LICENSE`](../../LICENSE).

---

<p align="center">
  A <sub>Minecraft a Mojang Studios védjegye. A Witch Launcher nem áll kapcsolatban a Mojang Studios, a Microsoft vagy a Amethyst projekttel.</sub>
</p>
