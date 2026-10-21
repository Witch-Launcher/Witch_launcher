<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition auf iPhone und iPad.</strong><br>
Ein von der Community erstellter iOS- und iPadOS-Fork von Amethyst, verwaltet von DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funktionen](#features) · [Screenshots](#screenshots) · [Anforderungen](#requirements) · [Installation](#installation) · [Sprachen](#languages) · [Credits](#credits) · [Lizenz](#license)

<details>
<summary><strong>Sprachen</strong></summary>

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
## Über

**Witch Launcher** ist ein unabhängiger, von der Community gepflegter Fork von [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), der **Minecraft: Java Edition** zu iPhone und iPad bringt. Es kombiniert eine Touch-First-Launcher-Benutzeroberfläche mit einem vollständigen Java-Laufzeitmanager, LWJGL und einem Grafikstapel, der auf den Übersetzungsebenen Metal, MoltenVK und OpenGL basiert.

Witch basiert auf der Arbeit von [Boardwalk](https://github.com/zhuowei/Boardwalk), der [PojavLauncher](https://github.com/PojavLauncherTeam)-Community, Amethyst-iOS und Amethyst-iOS-25. Es handelt sich um ein unabhängiges Projekt und ist nicht mit Mojang Studios, Microsoft oder dem Upstream-Team Amethyst verbunden.

> **Aktuelle Version:** 0.0.4 · Versionshinweise finden Sie unter [`news.md`](../../news.md).

---

<a id="features"></a>
## Funktionen

### Minecraft und Mods

- Läuft die meisten **Minecraft: Java Edition**-Versionen, von frühen Beta-Versionen bis hin zu den neuesten Snapshots.
- Unterstützt **Vanilla, Fabric, Quilt, Forge, NeoForge und OptiFine**.
- Erstellen Sie isolierte **Spielprofile** mit eigenen Einstellungen, Mods, Shadern, Ressourcenpaketen und Welten.
- Durchsuchen und installieren Sie Inhalte von **Modrinth und CurseForge**, ohne den Launcher zu verlassen:
  - Mods
  - Modpacks
  - Shader-Pakete
  - Ressourcenpakete
  - Abenteuerkarten und -welten
- Lösen Sie Mod-Abhängigkeiten auf und installieren Sie sie dort, wo die Quelle sie bereitstellt.
- Importieren Sie Forge/NeoForge-Installer-JARs und installieren Sie Fabric/Quilt-Loader direkt aus der Versionsauswahl.

### Grafik und Leistung

- Wechseln Sie zwischen mehreren Renderern über **Einstellungen → Renderer und Anzeige**:
  - **gl4es** – OpenGL 2.1-Kompatibilitätspfad
  - **ANGLE** – OpenGL ES bis Metal oder Vulkan
  - **MobileGlues** – OpenGL 4.0, Minecraft 1.17+, experimentell
  - **Zink** – OpenGL 4.1 bis Mesa 25 und MoltenVK
  - **LTW** – OpenGL 3.3 bis OpenGL ES/Metal, Minecraft 1.17+, experimentell
  - **TGLMT** – OpenGL 4.6 Kern bis Metal, A11 Bionic oder neuer
- **TGLMT mit Sodium- und Iris-Unterstützung** für moderne Shader-basierte Setups.
- **Bilderzeugung** mit bewegungsadaptiver GPU (MADI) und Kamera-3D-Neuprojektionsmodi, einschließlich zeitlicher Interpolation und prädiktiver Extrapolation.
- Auflösungsskalierung, maximale Framerate, FSR 1.0 Hochskalierung, GLSL-Shader-Caches und Optimierung pro Renderer.
- Leistungs-HUD mit konfigurierbaren FPS-, CPU-, GPU-, RAM-, Temperatur-, Akku-, Uhr- und Frame-Generierungs-FPS-Widgets.
- Integrierte Leistungsaufzeichnung mit Diagrammen, PNG/PDF Export und Freigabe.

### Kontrollen

- Vollständig anpassbare Bildschirmsteuerungslayouts, Tastengrößen und Transparenz.
- **Tastatur- und Mausunterstützung**, einschließlich einer virtuellen Maus und einstellbarer Zeigergeschwindigkeit.
- **Gamecontroller**-Unterstützung mit konfigurierbaren Layouts und Empfindlichkeit.
- **Gyroskop** mit einstellbarer Empfindlichkeit und Achsenumkehr.
- Maus-, Scroll- und Hotbar-Gesten.
- Optionales Verhalten: Tippen Sie, um Blöcke zu platzieren, und halten Sie gedrückt, um Blöcke aufzubrechen.
- Tippen Sie zweimal auf die Hotbar, um den gehaltenen Gegenstand in die Nebenhand zu tauschen.
- Verschiebbare Hotbar und einstellbares Long-Press-Timing.

### Launcher und Konten

- **Microsoft**, **lokal/offline**, **Demo** und **Ely.by**-Kontounterstützung.
- Verwalten Sie die Laufzeiten **Java 8, 17, 21 und 25**, laden Sie sie in der App herunter oder importieren Sie Ihre eigenen.
- Wählen Sie LWJGL Versionen aus und optimieren Sie JVM-Argumente, Umgebungsvariablen und Speicherzuweisung.
- Automatische RAM-Verwaltung für Geräte mit begrenztem Speicher.
- Themen, Akzentfarben, Unschärfe, Rahmen, Eckenradius, benutzerdefinierte Startschriftarten und App-Symbole.
- **F3-Geräteinformationen im Spiel**: Gerätechip, iOS-Version, Name/Version des Launchers, Build-Nummer und Build-Typ.
- Optionale **Witch-Server**-, CurseForge- und AI-Integrationen für erweiterte Setups.
- **52 In-App-Sprachen**, einschließlich von rechts nach links geschriebener Sprachpakete und unterhaltsamer Gebietsschemas.

---

<a id="screenshots"></a>
## Screenshots

Screenshots von einem Entwicklungs-Build von Witch Launcher 0.0.4. Die Benutzeroberfläche kann sich zwischen Versionen und Themes ändern.

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
## Anforderungen

| Anforderung | Einzelheiten |
|---|---|
| **Gerät** | iPhone oder iPad mit einem arm64-Prozessor und Metal-Unterstützung |
| **System** | iOS oder iPadOS **14.0 oder neuer** |
| **JIT** | Erforderlich. Aktivieren Sie JIT bis StikDebug, SideStore, TrollStore oder ein Setup mit Jailbreak |
| **Konto** | Ein Microsoft-Konto, das Minecraft für offizielle Downloads besitzt; Es sind auch lokale und Demo-Modi verfügbar |
| **Speicher** | Platz für den Launcher, Java Laufzeiten, Spielversionen, Mods und Welten |
| **Netzwerk** | Erforderlich für die Anmeldung, Versionsdownloads, den Inhaltsbrowser und optionale Onlinedienste |

Witch enthält **keine** Minecraft Spieledateien. Spieldateien werden über den Launcher heruntergeladen, nachdem Sie sich bei einem berechtigten Konto angemeldet haben.

### JIT Notizen

Minecraft: Java Edition benötigt JIT und Witch kann das Spiel nicht ohne es starten.

- **SideStore/AltStore-artige Installationen:** aktivieren Sie JIT für Witch und halten Sie die erforderliche VPN/Debugger-Verbindung aktiv. Die In-App-Nachricht bezieht sich auf **LocalDevVPN** und `CS_DEBUGGED`.
- **StikDebug:** Hängen Sie StikDebug an Witch an und aktivieren Sie JIT. Am **iOS 26./27** muss StikDebug verbunden bleiben, während das Spiel läuft. `UniversalJIT26.js` wird bei Bedarf in die Zwischenablage kopiert.
- **TrollStore:** aktiviert **URL Scheme** in TrollStore, wenn Witch weiterhin auf JIT wartet.
- **Geräte mit Jailbreak:** Verwenden Sie Ihren bevorzugten JIT-Enabler.
- Wenn der Launcher auf dem Bildschirm **Warten auf JIT** bleibt, überprüfen Sie vor dem Neustart die Debugger-Verbindung, die Einstellung VPN und TrollStore URL Scheme.

Das Verhalten von JIT hängt von der iOS-Version und der Installationsmethode ab. Systemaktualisierungen können bestehende JIT Setups zerstören.

---

<a id="installation"></a>
## Installation

Witch muss für Ihr Gerät signiert sein. Dieses Repository versendet keine Zertifikate oder vorsignierten IPAs.

### Verwenden Sie einen Build

1. Laden Sie einen Entwicklungs-Build aus dem [Entwicklungs-Workflow](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) herunter oder verwenden Sie einen signierten Build von einer Quelle, der Sie vertrauen.
2. Signieren und installieren Sie es mit **SideStore**, **AltStore**, **TrollStore** oder Ihrer bevorzugten Sideloading-Methode.
3. Aktivieren Sie JIT wie oben beschrieben, bevor Sie das Spiel starten.

TrollStore-Builds verwenden zusätzliche Berechtigungen und sollten nicht mit einem normalen Sideloading-Signer installiert werden.

### Aus dem Quellcode erstellen

Das Kompilieren von Witch erfordert macOS mit Xcode Befehlszeilentools, iOS SDK 14.0 oder neuer, CMake, JDK 8, `ldid`, `wget`, `zip` und Git.

```bash
git clone --recursive https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Gepackte Builds werden in `artifacts/` geschrieben.

Um stattdessen ein TrollStore-Paket zu erstellen:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Informationen zu Renderer-Quelllinks und Build-Hinweisen finden Sie unter [`note.md`](../../note.md).

---

<a id="languages"></a>
## Sprachen

Witch Launcher wird mit **52 Sprachpaketen** geliefert. Öffnen Sie **Einstellungen → Allgemein → Sprache** und wählen Sie eine Sprache aus oder verwenden Sie **Auto**, um der Gerätesprache zu folgen.

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

Die App liefert alle **52 Sprachpakete**. README-Übersetzungen sind für **alle 52 Sprachen** verfügbar, einschließlich Englisch.

Einige Übersetzungen werden maschinell unterstützt und können unangenehme Fachbegriffe enthalten. Korrekturen sind willkommen.

Englisch ist die Ausgangssprache dieser README-Datei. Lokalisierte READMEs sind über die Sprachauswahl oben auf dieser Seite und im Verzeichnis [`docs/readme/`](./) verfügbar.

---

<a id="notes-and-limitations"></a>
## Hinweise und Einschränkungen

- **JIT ist obligatorisch.** Ohne ein funktionierendes JIT-Setup wird Minecraft nicht gestartet.
- **iOS 26/27 JIT ist fragil.** StikDebug muss angeschlossen bleiben, und zukünftige Betriebssystem-Updates können die Funktionsweise ändern.
- Als **experimentell** gekennzeichnete Renderer können abstürzen oder falsch gerendert werden. Beginnen Sie mit **Auto**, wenn Sie sich nicht sicher sind.
- Für die **Frame-Generierung** ist der Renderer MoltenVK und die Rechenunterstützung Metal erforderlich. Dies kann den Akkuverbrauch und die Gerätetemperatur erhöhen.
- Einige Mods, Modpacks, Shader und Welten erfordern möglicherweise eine bestimmte Minecraft Version, einen bestimmten Loader, Renderer oder zusätzlichen Speicher.
- CurseForge Modpacks verwenden `manifest.json`; Wenn die One-Tap-Installation für ein Paket nicht verfügbar ist, importieren Sie das Archiv manuell.
- Online-Funktionen sind von Diensten Dritter abhängig und möglicherweise nicht verfügbar.
- Die Screenshots stammen aus einem Entwicklungs-Build und stimmen möglicherweise nicht genau mit der aktuellen Version überein.

---

<a id="project-lineage"></a>
## Projektlinie

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

### Verwandte Projekte

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Mitwirken

Fehlerberichte und PRs sind willkommen. Wenn Sie ein Problem melden, schließen Sie Folgendes ein:

- Gerätemodell und iOS/iPadOS-Version
- Witch Launcher-Version
- Renderer und Minecraft-Version
- Mod-Loader und eine Liste der installierten Mods
- Schritte zur Reproduktion
- das entsprechende Protokoll oder den Absturzbericht

Bitte übergeben Sie keine Signaturzertifikate, Bereitstellungsprofile, API Schlüssel oder andere Geheimnisse.

---

<a id="credits"></a>
## Credits

**Witch Launcher** wird von **DuyAnh662 (Za_d626)** verwaltet.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream und Community

Witch Launcher und seine Upstream-Projekte basieren auf der Arbeit vieler Mitwirkender, darunter:

- **@crystall1nedev** – Amethyst Projektmanager und iOS Portentwickler
- **@khanhduytran0** – iOS Portentwickler
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Zusätzlicher Dank geht an **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, das ANGLE Projekt, die Khronos Group, das Mesa Projekt, das PojavLauncher Team, Mozilla und die Minecraft Community.

Besonderer Dank geht an [MCHeads](https://mc-heads.net) für die Bereitstellung von Minecraft Avatar-Diensten.

Die vollständige Komponenten- und Lizenzliste von Drittanbietern finden Sie unter [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lizenz

Witch Launcher wird unter der **GNU General Public License v3.0** vertrieben und unterliegt den Lizenz- und Urheberrechtsanforderungen der in [`credits.md`](../../credits.md) aufgeführten Drittanbieterkomponenten.

Den vollständigen Lizenztext finden Sie unter [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft ist eine Marke von Mojang Studios. Witch Launcher ist nicht mit Mojang Studios, Microsoft oder dem Amethyst-Projekt verbunden.</sub>
</p>
