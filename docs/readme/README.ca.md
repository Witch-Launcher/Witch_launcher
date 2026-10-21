<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition a iPhone i iPad.</strong><br>
Una bifurcació iOS i iPadOS construïda per la comunitat de Amethyst, mantinguda per DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funcions](#features) · [Captures de pantalla](#screenshots) · [Requisits](#requirements) · [Instal·lació](#installation) · [Idiomes](#languages) · [Crèdits](#credits) · [Llicència](#license)

<details>
<summary><strong>Idiomes</strong></summary>

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
## Sobre

**Witch Launcher** és una bifurcació independent i mantinguda per la comunitat de [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) que porta **Minecraft: Java Edition** a iPhone i iPad. Combina una interfície d'usuari del llançador tàctil amb un gestor de temps d'execució complet Java, LWJGL i una pila de gràfics construïda al voltant de les capes de traducció Metal, MoltenVK i OpenGL.

Witch està construït sobre l'obra de [Boardwalk](https://github.com/zhuowei/Boardwalk), la comunitat [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS i Amethyst-iOS-25. És un projecte independent i no està afiliat a Mojang Studios, Microsoft ni a l'equip de Amethyst amunt.

> **Versió actual:** 0.0.4 · Vegeu [`news.md`](../../news.md) per a les notes de la versió.

---

<a id="features"></a>
## Característiques

### Minecraft i mods

- Executa la majoria de les versions **Minecraft: Java Edition**, des de les primeres versions beta fins a les últimes instantànies.
- Admet **Vanilla, Fabric, Quilt, Forge, NeoForge i OptiFine**.
- Crea **perfils de jocs** aïllats amb la seva pròpia configuració, modificacions, ombrejadors, paquets de recursos i mons.
- Navegueu i instal·leu contingut des de **Modrinth i CurseForge** sense sortir del llançador:
  - mods
  - paquets de mods
  - paquets d'ombres
  - paquets de recursos
  - mapes i mons d'aventures
- Resoldre i instal·lar dependències de modificacions on la font les proporcioni.
- Importeu els JAR d'instal·lador Forge/NeoForge i instal·leu els carregadors Fabric/Quilt directament des del selector de versions.

### Gràfics i rendiment

- Canvia entre diversos renderitzadors des de **Configuració → Representació i visualització**:
  - **gl4es** — Camí de compatibilitat OpenGL 2.1
  - **ANGLE** — OpenGL ES fins a Metal o Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimental
  - **Zink** — OpenGL 4.1 a Mesa 25 i MoltenVK
  - **LTW** — OpenGL 3.3 a OpenGL ES/Metal, Minecraft 1.17+, experimental
  - **TGLMT** — OpenGL 4.6 Bàsica a Metal, A11 Bionic o més recent
- **TGLMT amb suport Sodium i Iris** per a configuracions modernes basades en shader.
- **Generació de fotogrames** amb GPU adaptativa al moviment (MADI) i modes de reprojecció en 3D de la càmera, incloses la interpolació temporal i l'extrapolació predictiva.
- Escalat de resolució, velocitat de fotogrames màxima, augment d'escala FSR 1.0, memòria cau d'ombres GLSL i ajustament per renderitzador.
- HUD de rendiment amb ginys FPS, CPU, GPU, RAM, temperatura, bateria, rellotge i generació de fotogrames configurables.
- Enregistrament de rendiment integrat amb gràfics, exportació PNG/PDF i compartició.

### Controls

- Dissenys de control en pantalla, mides de botons i transparència totalment personalitzables.
- Compatibilitat amb **teclat i ratolí**, inclòs un ratolí virtual i una velocitat del punter ajustable.
- Compatibilitat amb **controladors de jocs** amb dissenys i sensibilitat configurables.
- **Giroscopi** mirant amb sensibilitat ajustable i inversió d'eix.
- Gestos del ratolí, de desplaçament i de la barra activa.
- Comportament opcional: toqueu per col·locar blocs, manteniu premut per trencar blocs.
- Fes doble toc a la barra activa per canviar l'element retingut a la mà.
- Barra d'activació lliscant i temps de premsa llarga ajustable.

### Llançador i comptes

- Compte de **Microsoft**, **local/fora de línia**, **demo** i **Ely.by**.
- Gestioneu els temps d'execució **Java 8, 17, 21 i 25**, baixeu-los des de l'aplicació o importeu-ne el vostre.
- Seleccioneu les versions LWJGL i ajusteu els arguments de la JVM, les variables d'entorn i l'assignació de memòria.
- Gestió de memòria RAM automàtica per a dispositius amb memòria limitada.
- Temes, colors d'accent, desenfocament, vores, radi de cantonada, tipus de lletra personalitzats del llançador i icones d'aplicacions.
- **Informació del dispositiu F3** del joc: xip del dispositiu, versió iOS, nom/versió del llançador, número de compilació i tipus de compilació.
- Integracions opcionals de **Servidor Witch**, CurseForge i AI per a configuracions avançades.
- **52 idiomes a l'aplicació**, inclosos paquets d'idiomes de dreta a esquerra i localitzacions divertides.

---

<a id="screenshots"></a>
## Captures de pantalla

Captures de pantalla d'una compilació de desenvolupament de Witch Launcher 0.0.4. La interfície pot canviar entre versions i temes.

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
## Requisits

| Requisit | Detalls |
|---|---|
| **Dispositiu** | iPhone o iPad amb un processador arm64 i suport Metal |
| **Sistema** | iOS o iPadOS **14.0 o posterior** |
| **JIT** | Obligatori. Habilita JIT a StikDebug, SideStore, TrollStore o una configuració jailbreak |
| **Compte** | Un compte Microsoft que posseeix Minecraft per a les descàrregues oficials; Els modes local i de demostració també estan disponibles |
| **Emmagatzematge** | Espai per al llançador, temps d'execució Java, versions de jocs, modificacions i mons |
| **Xarxa** | Necessari per iniciar la sessió, baixar versions, el navegador de contingut i serveis en línia opcionals |

Witch **no** inclou fitxers de joc Minecraft. Els fitxers del joc es descarreguen mitjançant el llançador després d'iniciar la sessió en un compte apte.

### JIT notes

Minecraft: Java Edition necessita JIT, i Witch no pot iniciar el joc sense ell.

- **Instal·lacions a l'estil SideStore / AltStore:** activeu JIT per a Witch i mantingueu activa la connexió necessària VPN/depurador. El missatge de l'aplicació fa referència a **LocalDevVPN** i `CS_DEBUGGED`.
- **StikDebug:** adjunteu StikDebug a Witch i activeu JIT. El **iOS 26/27**, StikDebug ha de romandre connectat mentre el joc s'executa. `UniversalJIT26.js` es copia al porta-retalls quan cal.
- **TrollStore:** habiliteu **URL Scheme** a TrollStore si Witch continua esperant el JIT.
- **Dispositius jailbreaks:** utilitzeu el vostre activador JIT preferit.
- Si el llançador es manté a la pantalla **Esperant el JIT**, comproveu la connexió del depurador, el paràmetre VPN i el paràmetre TrollStore URL Scheme abans de reiniciar-lo.

El comportament de JIT depèn de la versió iOS i del mètode d'instal·lació. Les actualitzacions del sistema poden trencar les configuracions existents de JIT.

---

<a id="installation"></a>
## Instal·lació

El Witch s'ha de signar per al vostre dispositiu. Aquest repositori no envia certificats ni IPA prefirmades.

### Utilitzeu una compilació

1. Baixeu una compilació de desenvolupament des del [flux de treball de desenvolupament](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) o utilitzeu una compilació signada d'una font de confiança.
2. Signeu-lo i instal·leu-lo amb **SideStore**, **AltStore**, **TrollStore** o el vostre mètode de càrrega lateral preferit.
3. Habiliteu JIT tal com es descriu anteriorment abans d'iniciar el joc.

Les compilacions TrollStore utilitzen drets addicionals i no s'han d'instal·lar amb un signant de càrrega lateral normal.

### Construeix des de la font

La compilació de Witch requereix macOS amb eines de línia d'ordres Xcode, una iOS SDK 14.0 o més recent, CMake, JDK 8, `ldid`, `wget`, `zip` i Git.

```bash
git clone --recursiu https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Les compilacions empaquetades s'escriuen a `artifacts/`.

Per crear un paquet TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Per als enllaços font del renderitzador i les notes de compilació, vegeu [`note.md`](../../note.md).

---

<a id="languages"></a>
## Idiomes

Witch Launcher s'envia amb **52 paquets d'idiomes**. Obriu **Configuració → General → Idioma** i seleccioneu un idioma o utilitzeu **Automàtic** per seguir l'idioma del dispositiu.

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

L'aplicació inclou tots els **52 paquets d'idiomes**. Les traduccions README estan disponibles per a **els 52 idiomes**, inclòs l'anglès.

Algunes traduccions són assistides per màquina i poden contenir termes tècnics incòmodes. Les correccions són benvingudes.

L'anglès és l'idioma d'origen d'aquest README. Els README localitzats estan disponibles al selector d'idiomes a la part superior d'aquesta pàgina i al directori [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Notes i limitacions

- **JIT és obligatori.** Sense una configuració de JIT que funcioni, Minecraft no s'iniciarà.
- **iOS 26/27 JIT és fràgil.** StikDebug ha de romandre adjunt, i les futures actualitzacions del sistema operatiu poden canviar el que funciona.
- Els renderitzadors marcats com a **experimentals** poden fallar o renderitzar-se incorrectament. Comenceu amb **Automàtic** si no esteu segurs.
- La **generació de marcs** requereix el renderitzador MoltenVK i el suport informàtic Metal. Pot augmentar l'ús de la bateria i la temperatura del dispositiu.
- Alguns mods, paquets de modificacions, shaders i mons poden requerir una versió, un carregador, un renderitzador o una memòria addicional específics de Minecraft.
- Els modpacks CurseForge utilitzen `manifest.json`; si la instal·lació d'un sol toc no està disponible per a un paquet, importeu l'arxiu manualment.
- Les funcions en línia depenen de serveis de tercers i poden no estar disponibles.
- Les captures de pantalla són d'una compilació de desenvolupament i poden no coincidir exactament amb la versió actual.

---

<a id="project-lineage"></a>
## Llinatge del projecte

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

### Projectes relacionats

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contribuint

Els informes d'errors i els PR són benvinguts. Quan informeu d'un problema, incloeu:

- model de dispositiu i versió iOS/iPadOS
- Versió Witch Launcher
- renderitzador i versió Minecraft
- carregador de mods i una llista de modificacions instal·lades
- passos per reproduir-se
- el registre o informe d'error corresponent

No comprometeu certificats de signatura, perfils de subministrament, claus API o altres secrets.

---

<a id="credits"></a>
## Crèdits

**Witch Launcher** el manté **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Riu amunt i comunitat

Witch Launcher i els seus projectes aigües amunt es basen en el treball de molts col·laboradors, com ara:

- **@crystall1nedev**: cap de projecte Amethyst i desenvolupador de ports iOS
- **@khanhduytran0** — Desenvolupador de ports iOS
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Agraïments addicionals a **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, el projecte ANGLE, el grup Khronos, el projecte Mesa, l'equip PojavLauncher, Mozilla i la comunitat Minecraft.

Agraïment especial a [MCHeads](https://mc-heads.net) per oferir serveis d'avatar Minecraft.

La llista completa de llicències i components de tercers està disponible a [`credits.md`](../../credits.md).

---

<a id="license"></a>
## llicència

Witch Launcher es distribueix sota la **Llicència Pública General GNU v3.0**, subjecte a les llicències i els requisits de drets d'autor dels components de tercers enumerats a [`credits.md`](../../credits.md).

Vegeu [`LICENSE`](../../LICENSE) per al text complet de la llicència.

---

<p align="center">
<sub>Minecraft és una marca comercial de Mojang Studios. Witch Launcher no està afiliat a Mojang Studios, Microsoft o al projecte Amethyst.</sub>
</p>
