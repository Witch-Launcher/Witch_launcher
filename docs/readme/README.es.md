<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition en iPhone y iPad.</strong><br>
Una bifurcación iOS y iPadOS construida por la comunidad de Amethyst, mantenida por DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Características](#features) · [Capturas de pantalla](#screenshots) · [Requisitos](#requirements) · [Instalación](#installation) · [Idiomas](#languages) · [Créditos](#credits) · [Licencia](#license)

<details>
<summary><strong>Idiomas</strong></summary>

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
## Acerca de

**Witch Launcher** es una bifurcación independiente mantenida por la comunidad de [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) que lleva **Minecraft: Java Edition** a iPhone y iPad. Combina una interfaz de usuario de inicio táctil con un administrador de tiempo de ejecución completo Java, LWJGL y una pila de gráficos construida alrededor de las capas de traducción Metal, MoltenVK y OpenGL.

Witch se basa en el trabajo de [Boardwalk](https://github.com/zhuowei/Boardwalk), la comunidad [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS y Amethyst-iOS-25. Es un proyecto independiente y no está afiliado a Mojang Studios, Microsoft ni al equipo upstream Amethyst.

> **Versión actual:** 0.0.4 · Consulte [`news.md`](../../news.md) para obtener notas de la versión.

---

<a id="features"></a>
## Características

### Minecraft y modificaciones

- Ejecuta la mayoría de las versiones **Minecraft: Java Edition**, desde las primeras versiones Beta hasta las últimas instantáneas.
- Admite **Vainilla, Fabric, Quilt, Forge, NeoForge y OptiFine**.
- Crea **perfiles de juego** aislados con sus propios ajustes, modificaciones, sombreadores, paquetes de recursos y mundos.
- Explore e instale contenido de **Modrinth y CurseForge** sin salir del iniciador:
  - modificaciones
  - paquetes de modificaciones
  - paquetes de sombreadores
  - paquetes de recursos
  - mapas y mundos de aventuras
- Resuelva e instale dependencias de mod donde la fuente las proporcione.
- Importe los JAR del instalador Forge/NeoForge e instale los cargadores Fabric/Quilt directamente desde el selector de versiones.

### Gráficos y rendimiento

- Cambie entre múltiples renderizadores desde **Configuración → Renderizador y visualización**:
  - **gl4es** — OpenGL 2.1 ruta de compatibilidad
  - **ANGLE** — OpenGL ES a Metal o Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimentales
  - **Zink** — OpenGL 4.1 a Mesa 25 y MoltenVK
  - **LTW** — OpenGL 3.3 a OpenGL ES/Metal, Minecraft 1.17+, experimental
  - **TGLMT** — OpenGL 4.6 Core hasta Metal, A11 Bionic o más reciente
- **TGLMT con soporte Sodium y Iris** para configuraciones modernas basadas en sombreadores.
- **Generación de fotogramas** con GPU adaptativa al movimiento (MADI) y modos de reproyección 3D de cámara, incluida la interpolación temporal y la extrapolación predictiva.
- Escalado de resolución, velocidad de fotogramas máxima, FSR 1.0 aumento de escala, cachés de sombreador GLSL y ajuste por renderizador.
- HUD de rendimiento con widgets configurables de FPS, CPU, GPU, RAM, temperatura, batería, reloj y FPS de generación de fotogramas.
- Grabación de interpretación integrada con gráficos, PNG/PDF exportación y uso compartido.

### Controles

- Diseños de control en pantalla, tamaños de botones y transparencia totalmente personalizables.
- Compatibilidad con **teclado y mouse**, incluido un mouse virtual y velocidad de puntero ajustable.
- Compatibilidad con **controlador de juego** con diseños y sensibilidad configurables.
- **Giroscopio** apuntando con sensibilidad ajustable e inversión de eje.
- Gestos del mouse, desplazamiento y barra de acceso rápido.
- Comportamiento opcional: toque para colocar bloques, mantenga presionado para romper bloques.
- Toca dos veces la barra de acceso rápido para cambiar el objeto retenido a la mano izquierda.
- Barra de acceso rápido deslizable y sincronización ajustable de pulsación larga.

### Lanzador y cuentas

- Soporte para cuentas **Microsoft**, **local/fuera de línea**, **demo** y **Ely.by**.
- Administre los tiempos de ejecución **Java 8, 17, 21 y 25**, descárguelos en la aplicación o importe los suyos propios.
- Seleccione LWJGL versiones y ajuste los argumentos de JVM, las variables de entorno y la asignación de memoria.
- Gestión automática de RAM para dispositivos con memoria limitada.
- Temas, colores de acento, desenfoque, bordes, radio de esquina, fuentes de inicio personalizadas e íconos de aplicaciones.
- **F3 información del dispositivo** en el juego: chip del dispositivo, versión de iOS, nombre/versión del iniciador, número de compilación y tipo de compilación.
- Integraciones opcionales de **Witch servidor**, CurseForge y AI para configuraciones avanzadas.
- **52 idiomas en la aplicación**, incluidos paquetes de idiomas de derecha a izquierda y configuraciones regionales divertidas.

---

<a id="screenshots"></a>
## Capturas de pantalla

Capturas de pantalla de una versión de desarrollo de Witch Launcher 0.0.4. La interfaz puede cambiar entre versiones y temas.

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
## Requisitos

| Requisito | Detalles |
|---|---|
| **Dispositivo** | iPhone o iPad con un procesador arm64 y soporte Metal |
| **Sistema** | iOS o iPadOS **14.0 o más reciente** |
| **JIT** | Requerido. Habilite JIT hasta StikDebug, SideStore, TrollStore o una configuración con jailbreak |
| **Cuenta** | Una cuenta Microsoft propietaria de Minecraft para descargas oficiales; los modos local y de demostración también están disponibles |
| **Almacenamiento** | Espacio para el lanzador, Java tiempos de ejecución, versiones de juegos, modificaciones y mundos |
| **Red** | Requerido para iniciar sesión, descargar versiones, el navegador de contenido y servicios en línea opcionales |

Witch **no** incluye Minecraft archivos del juego. Los archivos del juego se descargan a través del iniciador después de iniciar sesión en una cuenta elegible.

### JIT notas

Minecraft: Java Edition necesita JIT y Witch no puede iniciar el juego sin él.

- Instalaciones de estilo **SideStore/AltStore:** habilite JIT para Witch y mantenga activa la conexión requerida VPN/depurador. El mensaje en la aplicación hace referencia a **LocalDevVPN** y `CS_DEBUGGED`.
- **StikDebug:** adjunte StikDebug a Witch y habilite JIT. El **iOS 26/27**, StikDebug debe permanecer conectado mientras se ejecuta el juego. `UniversalJIT26.js` se copia al portapapeles cuando es necesario.
- **TrollStore:** habilita **URL Scheme** en TrollStore si Witch sigue esperando a JIT.
- **Dispositivos liberados:** use su habilitador JIT preferido.
- Si el iniciador permanece en la pantalla **Esperando JIT**, verifique la conexión del depurador, la configuración VPN y TrollStore URL Scheme antes de reiniciar.

El comportamiento de JIT depende de la versión de iOS y del método de instalación. Las actualizaciones del sistema pueden alterar las configuraciones JIT existentes.

---

<a id="installation"></a>
## Instalación

Witch debe estar firmado para su dispositivo. Este repositorio no envía certificados ni IPA prefirmados.

### Usa una compilación

1. Descargue una compilación de desarrollo desde el [flujo de trabajo de desarrollo](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) o utilice una compilación firmada de una fuente de confianza.
2. Firme e instálelo con **SideStore**, **AltStore**, **TrollStore** o su método de descarga preferido.
3. Habilite JIT como se describe arriba antes de iniciar el juego.

Las compilaciones TrollStore utilizan derechos adicionales y no deben instalarse con un firmante de descarga lateral normal.

### Construir desde la fuente

Para compilar Witch se requiere macOS con Xcode herramientas de línea de comandos, una iOS SDK 14.0 o posterior, CMake, JDK 8, `ldid`, `wget`, `zip` y Git.

```bash
clon de git --recursivo https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Las compilaciones empaquetadas se escriben en `artifacts/`.

Para crear un paquete TrollStore en su lugar:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Para enlaces de origen del renderizador y notas de compilación, consulte [`note.md`](../../note.md).

---

<a id="languages"></a>
## Idiomas

Witch Launcher se envía con **paquetes de 52 idiomas**. Abra **Configuración → General → Idioma** y seleccione un idioma, o use **Auto** para seguir el idioma del dispositivo.

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

La aplicación incluye todos los **52 paquetes de idiomas**. Las traducciones README están disponibles para **los 52 idiomas**, incluido el inglés.

Algunas traducciones son asistidas por máquinas y pueden contener términos técnicos incómodos. Las correcciones son bienvenidas.

El inglés es el idioma de origen de este archivo README. Los archivos README localizados están disponibles en el selector de idioma en la parte superior de esta página y en el directorio [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Notas y limitaciones

- **JIT es obligatorio.** Sin una configuración JIT que funcione, Minecraft no se iniciará.
- **iOS 26/27 JIT es frágil.** StikDebug debe permanecer adjunto y futuras actualizaciones del sistema operativo pueden cambiar lo que funciona.
- Los renderizadores marcados como **experimentales** pueden fallar o renderizarse incorrectamente. Comience con **Auto** si no está seguro.
- La **generación de fotogramas** requiere el procesador MoltenVK y el soporte informático Metal. Puede aumentar el uso de la batería y la temperatura del dispositivo.
- Algunas modificaciones, paquetes de modificaciones, sombreadores y mundos pueden requerir una Minecraft versión, un cargador, un renderizador o memoria adicional específicos.
- CurseForge los modpacks usan `manifest.json`; Si la instalación con un solo toque no está disponible para un paquete, importe el archivo manualmente.
- Las funciones en línea dependen de servicios de terceros y es posible que no estén disponibles.
- Las capturas de pantalla pertenecen a una versión de desarrollo y es posible que no coincidan exactamente con la versión actual.

---

<a id="project-lineage"></a>
## Linaje del proyecto

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

### Proyectos relacionados

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contribuyendo

Los informes de errores y las relaciones públicas son bienvenidos. Al informar un problema, incluya:

- modelo de dispositivo y versión iOS/iPadOS
- Witch Launcher versión
- renderizador y versión Minecraft
- cargador de mods y una lista de mods instalados
- pasos para reproducir
- el registro relevante o el informe de fallos

No confirme certificados de firma, perfiles de aprovisionamiento, claves API ni otros secretos.

---

<a id="credits"></a>
## Créditos

**Witch Launcher** es mantenido por **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream y comunidad

Witch Launcher y sus proyectos upstream se basan en el trabajo de muchos contribuyentes, entre ellos:

- **@crystall1nedev** — Amethyst gerente de proyecto y iOS desarrollador de port
- **@khanhduytran0** — iOS desarrollador de puertos
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Agradecimientos adicionales a **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, el proyecto ANGLE, el grupo Khronos, el proyecto Mesa, el equipo PojavLauncher, Mozilla y la comunidad Minecraft.

Un agradecimiento especial a [MCHeads](https://mc-heads.net) por brindar Minecraft servicios de avatar.

La lista completa de licencias y componentes de terceros está disponible en [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licencia

Witch Launcher se distribuye bajo la **Licencia Pública General GNU v3.0**, sujeta a las licencias y requisitos de derechos de autor de los componentes de terceros enumerados en [`credits.md`](../../credits.md).

Consulte [`LICENSE`](../../LICENSE) para obtener el texto completo de la licencia.

---

<p align="center">
<sub>Minecraft es una marca comercial de Mojang Studios. Witch Launcher no está afiliado a Mojang Studios, Microsoft ni al proyecto Amethyst.</sub>
</p>
