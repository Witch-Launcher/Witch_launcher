<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition sur iPhone et iPad.</strong><br>
Un fork iOS et iPadOS de Amethyst construit par la communauté, maintenu par DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Fonctionnalités](#features) · [Captures d'écran](#screenshots) · [Exigences](#requirements) · [Installation](#installation) · [Langues](#languages) · [Crédits](#credits) · [Licence](#license)

<details>
<summary><strong>Langues</strong></summary>

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
## À propos

**Witch Launcher** est un fork indépendant et maintenu par la communauté de [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) qui amène **Minecraft: Java Edition** à iPhone et iPad. Il combine une interface utilisateur de lancement tactile avec un gestionnaire d'exécution complet Java, LWJGL et une pile graphique construite autour des couches de traduction Metal, MoltenVK et OpenGL.

Witch s'appuie sur le travail de [Boardwalk](https://github.com/zhuowei/Boardwalk), de la communauté [PojavLauncher](https://github.com/PojavLauncherTeam), de Amethyst-iOS et de Amethyst-iOS-25. Il s'agit d'un projet indépendant et n'est pas affilié à Mojang Studios, Microsoft ou à l'équipe en amont Amethyst.

> **Version actuelle :** 0.0.4 · Voir [`news.md`](../../news.md) pour les notes de version.

---

<a id="features"></a>
## Caractéristiques

### Minecraft et mods

- Exécute la plupart des versions **Minecraft: Java Edition**, depuis les premières versions bêta jusqu'aux derniers instantanés.
- Prend en charge **Vanilla, Fabric, Quilt, Forge, NeoForge et OptiFine**.
- Créez des **profils de jeu** isolés avec leurs propres paramètres, mods, shaders, packs de ressources et mondes.
- Parcourez et installez le contenu de **Modrinth et CurseForge** sans quitter le lanceur :
  - mods
  - packs de modules
  - packs de shaders
  - packs de ressources
  - cartes et mondes d'aventure
- Résolvez et installez les dépendances du mod là où la source les fournit.
- Importez les fichiers JAR du programme d'installation Forge/NeoForge et installez les chargeurs Fabric/Quilt directement à partir du sélecteur de version.

### Graphiques et performances

- Basculez entre plusieurs moteurs de rendu depuis **Paramètres → Moteur de rendu et affichage** :
  - **gl4es** — OpenGL chemin de compatibilité 2.1
  - **ANGLE** – OpenGL ES à Metal ou Vulkan
  - **MobileGlues** — OpenGL 4,0, Minecraft 1,17+, expérimental
  - **Zink** — OpenGL 4.1 à Mesa 25 et MoltenVK
  - **LTW** – OpenGL 3,3 à OpenGL ES/Metal, Minecraft 1,17+, expérimental
  - **TGLMT** — OpenGL 4.6 Core jusqu'à Metal, A11 Bionic ou version ultérieure
- **TGLMT avec prise en charge de Sodium et Iris** pour les configurations modernes basées sur des shaders.
- **Génération d'images** avec les modes GPU adaptatif au mouvement (MADI) et Camera 3D Reproject, y compris l'interpolation temporelle et l'extrapolation prédictive.
- Mise à l'échelle de la résolution, fréquence d'images maximale, mise à l'échelle FSR 1.0, caches de shader GLSL et réglage par moteur de rendu.
- HUD de performances avec widgets FPS, CPU, GPU, RAM, température, batterie, horloge et génération d'images configurables.
- Enregistrement de performances intégré avec graphiques, PNG/PDF exportation et partage.

### Contrôles

- Dispositions des commandes à l'écran, tailles de boutons et transparence entièrement personnalisables.
- Prise en charge du **clavier et de la souris**, y compris une souris virtuelle et une vitesse de pointeur réglable.
- Prise en charge du **contrôleur de jeu** avec des dispositions et une sensibilité configurables.
- **Gyroscope** visant avec sensibilité réglable et inversion d'axe.
- Gestes de la souris, du défilement et de la barre de raccourcis.
- Comportement facultatif : appuyez pour placer des blocs, maintenez enfoncé pour casser des blocs.
- Appuyez deux fois sur la barre de raccourcis pour échanger l'élément détenu vers la main gauche.
- Barre de raccourci coulissante et timing d'appui long réglable.

### Lanceur et comptes

- Prise en charge des comptes **Microsoft**, **local/hors ligne**, **démo** et **Ely.by**.
- Gérez les environnements d'exécution **Java 8, 17, 21 et 25**, téléchargez-les dans l'application ou importez les vôtres.
- Sélectionnez les versions LWJGL et ajustez les arguments JVM, les variables d'environnement et l'allocation de mémoire.
- Gestion automatique de la RAM pour les appareils avec une mémoire limitée.
- Thèmes, couleurs d'accent, flou, bordures, rayon de coin, polices de lancement personnalisées et icônes d'application.
- Dans le jeu, **F3 informations sur l'appareil** : puce de l'appareil, version iOS, nom/version du lanceur, numéro de build et type de build.
- Intégrations facultatives **Witch Server**, CurseForge et AI pour les configurations avancées.
- **52 langues intégrées à l'application**, y compris des packs de langues s'écrivant de droite à gauche et des paramètres régionaux amusants.

---

<a id="screenshots"></a>
## Captures d'écran

Captures d'écran d'une version de développement de Witch Launcher 0.0.4. L'interface peut changer entre les versions et les thèmes.

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
## Exigences

| Exigence | Détails |
|---|---|
| **Appareil** | iPhone ou iPad avec un processeur arm64 et prise en charge de Metal |
| **Système** | iOS ou iPadOS **14.0 ou version ultérieure** |
| **JIT** | Requis. Activez JIT à StikDebug, SideStore, TrollStore ou une configuration jailbreakée |
| **Compte** | Un compte Microsoft possédant Minecraft pour les téléchargements officiels ; les modes local et démo sont également disponibles |
| **Storage** | Space for the launcher, Java runtimes, game versions, mods, and worlds |
| **Réseau** | Requis pour la connexion, les téléchargements de versions, le navigateur de contenu et les services en ligne facultatifs |

Witch n'inclut **pas** les Minecraft fichiers de jeu. Les fichiers du jeu sont téléchargés via le lanceur après vous être connecté à un compte éligible.

### JIT remarques

Minecraft: Java Edition a besoin de JIT et Witch ne peut pas lancer le jeu sans lui.

- **Installations de style SideStore/AltStore :** activez JIT pour Witch et maintenez la connexion VPN/débogueur requise active. Le message dans l'application fait référence à **LocalDevVPN** et `CS_DEBUGGED`.
- **StikDebug :** attachez StikDebug à Witch et activez JIT. Le **iOS 26/27**, StikDebug doit rester attaché pendant que le jeu est en cours d'exécution. `UniversalJIT26.js` est copié dans le presse-papiers en cas de besoin.
- **TrollStore :** activez **URL Scheme** dans TrollStore si Witch continue d'attendre JIT.
- **Appareils jailbreakés** : utilisez votre activateur JIT préféré.
- Si le lanceur reste sur l'écran **En attente de JIT**, vérifiez la connexion du débogueur, le VPN et le paramètre TrollStore URL Scheme avant de relancer.

Le comportement de JIT dépend de la version de iOS et de la méthode d'installation. Les mises à jour du système peuvent interrompre les configurations JIT existantes.

---

<a id="installation"></a>
## Mise en place

Witch doit être signé pour votre appareil. Ce référentiel ne fournit pas de certificats ni d'IPA pré-signés.

### Utiliser une version

1. Téléchargez une version de développement à partir du [workflow de développement](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) ou utilisez une version signée provenant d'une source de confiance.
2. Signez-le et installez-le avec **SideStore**, **AltStore**, **TrollStore** ou votre méthode de chargement latéral préférée.
3. Activez JIT comme décrit ci-dessus avant de lancer le jeu.

Les versions TrollStore utilisent des droits supplémentaires et ne doivent pas être installées avec un signataire de chargement latéral normal.

### Construire à partir des sources

La compilation de Witch nécessite macOS avec les outils de ligne de commande Xcode, un iOS SDK 14.0 ou plus récent, CMake, JDK 8, `ldid`, `wget`, `zip` et Git.

```bash
git clone --récursif https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Les builds packagés sont écrits dans `artifacts/`.

Pour créer un package TrollStore à la place :

```bash
make package TROLLSTORE_JIT_ENT=1
```

Pour les liens sources du moteur de rendu et les notes de construction, voir [`note.md`](../../note.md).

---

<a id="languages"></a>
## Langues

Witch Launcher est livré avec **52 modules linguistiques**. Ouvrez **Paramètres → Général → Langue** et sélectionnez une langue, ou utilisez **Auto** pour suivre la langue de l'appareil.

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

L'application fournit les **52 packs linguistiques**. Les traductions README sont disponibles pour **les 52 langues**, y compris l'anglais.

Certaines traductions sont assistées par machine et peuvent contenir des termes techniques peu pratiques. Les corrections sont les bienvenues.

L'anglais est la langue source de ce README. Les README localisés sont disponibles à partir du sélecteur de langue en haut de cette page et dans le répertoire [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Remarques et limites

- **JIT est obligatoire.** Sans une configuration JIT fonctionnelle, Minecraft ne se lancera pas.
- **iOS 26/27 JIT est fragile.** StikDebug doit rester attaché, et les futures mises à jour du système d'exploitation pourraient modifier ce qui fonctionne.
- Les moteurs de rendu marqués **expérimental** peuvent planter ou s'afficher de manière incorrecte. Commencez par **Auto** si vous n'êtes pas sûr.
- La **Génération de cadres** nécessite le moteur de rendu MoltenVK et la prise en charge du calcul Metal. Cela peut augmenter l’utilisation de la batterie et la température de l’appareil.
- Certains mods, modpacks, shaders et mondes peuvent nécessiter une version Minecraft spécifique, un chargeur, un moteur de rendu ou une mémoire supplémentaire.
- Les modpacks CurseForge utilisent `manifest.json` ; si l'installation en un clic n'est pas disponible pour un pack, importez l'archive manuellement.
- Les fonctionnalités en ligne dépendent de services tiers et peuvent être indisponibles.
- Les captures d'écran proviennent d'une version de développement et peuvent ne pas correspondre exactement à la version actuelle.

---

<a id="project-lineage"></a>
## Lignée du projet

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

### Projets associés

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contribuer

Les rapports de bogues et les relations publiques sont les bienvenus. Lorsque vous signalez un problème, incluez :

- modèle de l'appareil et version iOS/iPadOS
- version Witch Launcher
- moteur de rendu et version Minecraft
- chargeur de mods et une liste des mods installés
- étapes pour reproduire
- le journal ou le rapport de crash correspondant

Veuillez ne pas signer de certificats, de profils de provisionnement, de clés API ou d'autres secrets.

---

<a id="credits"></a>
## Crédits

**Witch Launcher** est maintenu par **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Amont et communauté

Witch Launcher et ses projets en amont s'appuient sur le travail de nombreux contributeurs, notamment :

- **@crystall1nedev** — Amethyst chef de projet et iOS développeur de ports
- **@khanhduytran0** — iOS développeur de ports
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Remerciements supplémentaires à **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, au projet ANGLE, au groupe Khronos, au projet Mesa, à l'équipe PojavLauncher, à Mozilla et à la communauté Minecraft.

Un merci spécial à [MCHeads](https://mc-heads.net) pour avoir fourni les services d'avatar Minecraft.

La liste complète des composants tiers et des licences est disponible dans [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licence

Witch Launcher est distribué sous la **Licence publique générale GNU v3.0**, sous réserve des licences et des exigences en matière de droits d'auteur des composants tiers répertoriés dans [`credits.md`](../../credits.md).

Voir [`LICENSE`](../../LICENSE) pour le texte complet de la licence.

---

<p align="center">
<sub>Minecraft est une marque commerciale de Mojang Studios. Witch Launcher n'est pas affilié à Mojang Studios, Microsoft ou au projet Amethyst.</sub>
</p>
