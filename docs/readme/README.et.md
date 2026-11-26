<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone ja iPad.</strong><br> kohta
Kogukonna ehitatud iOS ja iPadOS kahvel Amethyst, mida haldab DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funktsioonid](#features) · [Ekraanipildid](#screenshots) · [Nõuded](#requirements) · [Installimine](#installation) · [Keeled](#languages) · [Krediidid](#credits) · [Litsents](#license)

<details>
<summary><strong>Keeled</strong></summary>

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
## Umbes

**Witch Launcher** on [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) iseseisev, kogukonna poolt hooldatav kahvel, mis toob **Minecraft: Java Edition** kuni iPhone ja iPad. See ühendab puutetundliku käivitusliidese täieliku Java käitusaja halduriga LWJGL ja Metal, MoltenVK ja OpenGL tõlkekihtide ümber ehitatud graafikapinu.

Witch on üles ehitatud [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) kogukonna, Amethyst-iOS ja Amethyst-iOS-25 tööle. See on iseseisev projekt ega ole seotud Mojang Studios, Microsoft ega ülesvoolu Amethyst meeskonnaga.

> **Praegune versioon:** 0.0.4 · Vaadake väljalaskemärkmeid [`news.md`](../../news.md).

---

<a id="features"></a>
## Omadused

### Minecraft ja muudatused

- Käitab enamikku **Minecraft: Java Edition** versioone alates varasest beetaversioonist kuni viimaste hetktõmmisteni.
- Toetab **Vanilli, Fabric, Quilt, Forge, NeoForge ja OptiFine**.
- Looge isoleeritud **mänguprofiile** oma seadete, modifikatsioonide, varjutajate, ressursipakettide ja maailmadega.
- Sirvige ja installige **Modrinth ja CurseForge** sisu käivitusprogrammist lahkumata:
  - modifikatsioonid
  - modifikatsioonipakid
  - varjude pakendid
  - ressursipaketid
  - seikluskaardid ja maailmad
- Lahendage ja installige modi sõltuvused seal, kus allikas neid pakub.
- Importige Forge/NeoForge installija JAR-id ja installige Fabric/Quilt laadijad otse versioonivalijast.

### Graafika ja jõudlus

- Valige mitme renderdaja vahel **Seaded → Renderdaja ja kuva**:
  - **gl4es** – OpenGL 2.1 ühilduvustee
  - **ANGLE** — ES OpenGL kuni Metal või Vulkan
  - **MobileGlues** – OpenGL 4.0, Minecraft 1.17+, eksperimentaalne
  - **Zink** — OpenGL 4.1 kuni Mesa 25 ja MoltenVK
  - **LTW** — OpenGL 3.3 kuni OpenGL ES/Metal, Minecraft 1.17+, eksperimentaalne
  - **TGLMT** – OpenGL 4.6 Tuum kuni Metal, A11 Bionic või uuem
- **TGLMT Sodium ja Iris toega** kaasaegsete varjundipõhiste seadistuste jaoks.
- **Kaadri genereerimine** koos liikuva adaptiivse GPU-ga (MADI) ja kaamera 3D taasesitusrežiimidega, sealhulgas ajaline interpolatsioon ja ennustav ekstrapolatsioon.
- Eraldusvõime skaleerimine, maksimaalne kaadrisagedus, FSR 1.0 ülesskaleerimine, GLSL-i varjutaja vahemälud ja renderdajapõhine häälestamine.
- Toimiv HUD konfigureeritavate FPS-i, protsessori, GPU, RAM-i, temperatuuri, aku, kella ja kaadri genereerimise FPS-vidinatega.
- Sisseehitatud jõudluse salvestamine graafikutega, PNG/PDF eksportimine ja jagamine.

### Juhtnupud

- Täielikult kohandatavad ekraanil kuvatavad juhtimispaigutused, nuppude suurused ja läbipaistvus.
- **Klaviatuuri ja hiire** tugi, sealhulgas virtuaalne hiir ja reguleeritav kursori kiirus.
- **Mängukontrolleri** tugi konfigureeritava paigutuse ja tundlikkusega.
- Reguleeritava tundlikkuse ja telje ümberpööramisega sihtiv **güroskoop**.
- Hiire, kerimise ja kuumariba žestid.
- Valikuline käitumine: puudutage plokkide paigutamiseks, hoidke plokkide purustamiseks.
- Topeltpuudutage kuumutusriba, et vahetada hoitud üksus vabaks.
- Libistav kuumariba ja reguleeritav pika vajutuse ajastus.

### Käivitaja ja kontod

- Konto tugi **Microsoft**, **kohalik/offline**, **demo** ja **Ely.by**.
- Hallake **Java lõikeid 8, 17, 21 ja 25**, laadige need rakendusesiseselt alla või importige oma.
- Valige LWJGL versioonid ja häälestage JVM-i argumendid, keskkonnamuutujad ja mälujaotus.
- Piiratud mäluga seadmete automaatne RAM-i haldus.
- Teemad, aktsentvärvid, hägusus, äärised, nurgaraadius, kohandatud käivitusfondid ja rakenduste ikoonid.
- Mängusisene **F3 seadme teave**: seadme kiip, iOS versioon, käivitaja nimi/versioon, järgu number ja järgu tüüp.
- Valikulised **Witch serveri**, CurseForge ja AI integratsioonid täpsemate seadistuste jaoks.
- **52 rakendusesisest keelt**, sealhulgas paremalt vasakule keelepaketid ja lõbusad lokaadid.

---

<a id="screenshots"></a>
## Ekraanipildid

Ekraanipildid Witch Launcher 0.0.4 arendusjärgust. Liides võib versioonide ja teemade vahel muutuda.

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
## Nõuded

| Nõue | Üksikasjad |
|---|---|
| **Seade** | iPhone või iPad arm64 töötleja ja Metal toega |
| **Süsteem** | iOS või iPadOS **14.0 või uuem** |
| **JIT** | Nõutav. Luba JIT kuni StikDebug, SideStore, TrollStore või jailbroken seadistus |
| **Konto** | Microsoft konto, mis omab Minecraft ametlikuks allalaadimiseks; saadaval on ka kohalikud ja demorežiimid |
| **Salvestus** | Ruumi käivitusprogrammi, Java käitusaegade, mänguversioonide, modifikatsioonide ja maailmade jaoks |
| **Võrk** | Vajalik sisselogimiseks, versioonide allalaadimiseks, sisubrauseriks ja valikulisteks võrguteenusteks |

Witch **ei** hõlma Minecraft mängufaile. Mängufailid laaditakse alla käivitusprogrammi kaudu pärast sobilikule kontole sisselogimist.

### JIT märkused

Minecraft: Java Edition vajab JIT ja Witch ei saa ilma selleta mängu käivitada.

- **SideStore / AltStore-tüüpi installid:** lubage JIT Witch jaoks ja hoidke vajalik VPN/siluja ühendus aktiivsena. Rakendusesisene teade viitab **LocalDevVPN** ja `CS_DEBUGGED`-le.
- **StikDebug:** lisa StikDebug Witch-le ja luba JIT. **iOS 26/27** peab StikDebug jääma mängu ajal juurde. `UniversalJIT26.js` kopeeritakse vajadusel lõikepuhvrisse.
- **TrollStore:** luba TrollStore-s **URL Scheme**, kui Witch jääb ootama JIT.
- **Jailpurustatud seadmed:** kasutage eelistatud JIT lubajat.
- Kui käivitaja jääb kuvale **Ootan JIT**, kontrollige enne taaskäivitamist siluri ühendust, VPN ja TrollStore URL Scheme sätteid.

JIT käitumine sõltub iOS versioonist ja paigaldusviisist. Süsteemivärskendused võivad rikkuda olemasolevaid JIT seadistusi.

---

<a id="installation"></a>
## Paigaldamine

Witch peab olema oma seadme jaoks allkirjastatud. See hoidla ei tarni sertifikaate ega eelallkirjastatud IPA-sid.

### Kasutage konstruktsiooni

1. Laadige arendusjärg alla [arendustöövoost] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) või kasutage allkirjastatud järku usaldusväärsest allikast.
2. Allkirjastage ja installige see **SideStore**, **AltStore**, **TrollStore** või eelistatud külglaadimismeetodiga.
3. Enne mängu käivitamist lubage JIT ülalkirjeldatud viisil.

TrollStore konstruktsioonid kasutavad täiendavaid õigusi ja neid ei tohiks installida tavalise külglaadimise allkirjaga.

### Ehitage allikast

Witch koostamiseks on vaja macOS koos Xcode käsurea tööriistadega, iOS SDK 14.0 või uuem, CMake, JDK 8, `ldid`, `wget`, `zip` ja Git.

```bash
git kloon -- rekursiivne https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Pakitud ehitused on kirjutatud `artifacts/` järgi.

Selle asemel TrollStore paketi koostamiseks toimige järgmiselt.

```bash
make package TROLLSTORE_JIT_ENT=1
```

Renderdaja allika linkide ja järgu märkuste kohta vaadake artiklit [`note.md`](../../note.md).

---

<a id="languages"></a>
## Keeled

Witch Launcher tarnitakse **52 keelepaketiga**. Avage **Seaded → Üldine → Keel** ja valige keel või kasutage seadme keele jälgimiseks funktsiooni **Automaatne**.

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

Rakendus tarnib kõiki **52 keelepaketti**. README tõlked on saadaval **kõigis 52 keeles**, sealhulgas inglise keelde.

Mõned tõlked on masinabiga ja võivad sisaldada ebamugavaid tehnilisi termineid. Parandused on teretulnud.

Selle README lähtekeeleks on inglise keel. Lokaliseeritud README-d on saadaval selle lehe ülaosas oleva keelevalija kaudu ja kataloogis [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Märkused ja piirangud

- **JIT on kohustuslik.** Ilma toimiva JIT seadistuseta Minecraft ei käivitu.
- **iOS 26/27 JIT on habras.** StikDebug peab jääma lisatud ja tulevased OS-i värskendused võivad muuta seda, mis töötab.
- Renderderid, mis on märgitud **katseliseks**, võivad kokku jooksma või renderdada valesti. Kui te pole kindel, alustage valikuga **Automaatne**.
- **Frame Generation** nõuab MoltenVK renderdajat ja Metal arvutamise tuge. See võib suurendada aku kasutust ja seadme temperatuuri.
- Mõned modifikatsioonid, modifikatsioonipaketid, varjutajad ja maailmad võivad vajada konkreetset Minecraft versiooni, laadijat, renderdajat või lisamälu.
- CurseForge modpackid kasutavad `manifest.json`; kui ühe puudutusega installimine pole paketi jaoks saadaval, importige arhiiv käsitsi.
- Võrgufunktsioonid sõltuvad kolmanda osapoole teenustest ja ei pruugi olla saadaval.
- Ekraanipildid pärinevad arendusjärgust ja ei pruugi praegusele versioonile täpselt vastata.

---

<a id="project-lineage"></a>
## Projekti põlvnemine

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

### Seotud projektid

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Panustamine

Veaaruanded ja suhtekorraldajad on teretulnud. Probleemist teatades lisage:

- seadme mudel ja iOS/iPadOS versioon
- Witch Launcher versioon
- renderdaja ja Minecraft versioon
- mod loader ja installitud modifikatsioonide loend
- paljunemise sammud
- asjakohane logi või krahhiaruanne

Ärge kirjutage alla sertifikaate, varustamisprofiile, API võtmeid ega muid saladusi.

---

<a id="credits"></a>
## Krediidid

**Witch Launcher** haldab **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Ülesvool ja kogukond

Witch Launcher ja selle eelnevad projektid põhinevad paljude panustajate tööl, sealhulgas:

- **@crystall1nedev** — Amethyst projektijuht ja iOS sadama arendaja
- **@khanhduytran0** — iOS pordi arendaja
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Täiendavad tänud **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, projekt ANGLE, Khronos Group, Mesa projekt, PojavLauncher meeskond, Mozilla ja Minecraft kogukond.

Eriline tänu [MCHeads](https://mc-heads.net) Minecraft avatariteenuste osutamise eest.

Täielik kolmanda osapoole komponentide ja litsentside loend on saadaval jaotises [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Litsents

Witch Launcher levitatakse **GNU üldise avaliku litsentsi v3.0** alusel, vastavalt punktis [`credits.md`] (credits.md) loetletud kolmandate osapoolte komponentide litsentsidele ja autoriõiguse nõuetele.

Täieliku litsentsi teksti leiate [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft on Mojang Studios kaubamärk. Witch Launcher ei ole seotud Mojang Studios, Microsoft ega Amethyst projektiga.</sub>
</p>
