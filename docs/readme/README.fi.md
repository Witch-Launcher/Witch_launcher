<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition iPhone:sta ja iPad:stä.</strong><br>
Yhteisön rakentama iOS ja iPadOS Amethyst:n haarukka, jota ylläpitää DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Ominaisuudet](#features) · [Kuvakaappaukset](#screenshots) · [Vaatimukset](#requirements) · [Asennus](#installation) · [Kielet](#languages) · [Tekijät](#credits) · [Lisenssi](#license)

<details>
<summary><strong>Kielet</strong></summary>

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
## Noin

**Witch Launcher** on itsenäinen, yhteisön ylläpitämä haarukka [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), joka tuo **Minecraft: Java Edition** iPhone ja iPad. Siinä yhdistyvät kosketuskäynnistyskäyttöliittymä, Java runtime manager, LWJGL ja Metal, MoltenVK ja OpenGL käännöstasojen ympärille rakennettu grafiikkapino.

Witch perustuu [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam)-yhteisön, Amethyst-iOS:n ja Amethyst-iOS-25:n työhön. Se on itsenäinen projekti, eikä se ole sidoksissa Mojang Studios, Microsoft tai ylävirran Amethyst-tiimiin.

> **Nykyinen versio:** 0.0.4 · Katso [`news.md`](../../news.md) julkaisutiedot.

---

<a id="features"></a>
## Ominaisuudet

### Minecraft ja modit

- Käyttää useimpia **Minecraft: Java Edition**-versioita varhaisista betaversioista uusimpiin tilannekuviin.
- Tukee **Vaniljaa, Fabric, Quilt, Forge, NeoForge ja OptiFine**.
- Luo eristettyjä **peliprofiileja** omilla asetuksilla, moduuksilla, varoittimilla, resurssipaketteilla ja maailmoilla.
- Selaa ja asenna sisältöä kohdista **Modrinth ja CurseForge** poistumatta käynnistysohjelmasta:
  - modit
  - modpackit
  - Shader-paketit
  - resurssipaketit
  - seikkailukarttoja ja maailmoja
- Ratkaise ja asenna mod-riippuvuudet sinne, missä lähde ne tarjoaa.
- Tuo Forge/NeoForge asennusohjelman JAR-tiedostot ja asenna Fabric/Quilt-lataajat suoraan versionvalitsimesta.

### Grafiikka ja suorituskyky

- Vaihda useiden renderöijien välillä valitsemalla **Asetukset → Renderöijä ja näyttö**:
  - **gl4es** – OpenGL 2.1 -yhteensopivuuspolku
  - **ANGLE** – OpenGL ES metallin tai Vulkanin kautta
  - **MobileGlues** – OpenGL 4.0, Minecraft 1.17+, kokeellinen
  - **Zink** – OpenGL 4.1–Mesa 25 ja MoltenVK
  - **LTW** – OpenGL 3.3–OpenGL ES/Metal, Minecraft 1.17+, kokeellinen
  - **TGLMT** — OpenGL 4.6 Ydin - Metal, A11 Bionic tai uudempi
- **TGLMT Sodium:n ja Iris:n tuella** nykyaikaisille shader-pohjaisille asetuksille.
- **Frame Generation** Motion-Adaptive GPU (MADI) ja Camera 3D Reproject -tilat, mukaan lukien ajallinen interpolointi ja ennakoiva ekstrapolointi.
- Resoluution skaalaus, enimmäiskehysnopeus, FSR 1.0:n nostaminen, GLSL-varjostimen välimuistit ja renderöijäkohtainen viritys.
- Suorituskykyinen HUD konfiguroitavilla FPS-, CPU-, GPU-, RAM-, lämpötila-, akku-, kello- ja kehyssukupolven FPS-widgeteillä.
- Sisäänrakennettu suoritustallennus kaavioilla, PNG/PDF vienti ja jakaminen.

### Säätimet

- Täysin muokattavissa olevat näytön ohjausasettelut, painikkeiden koot ja läpinäkyvyys.
- **Näppäimistön ja hiiren** tuki, mukaan lukien virtuaalinen hiiri ja säädettävä osoittimen nopeus.
- **Peliohjaimen** tuki konfiguroitavilla asetteluilla ja herkkyydellä.
- **Gyroskooppi**, jossa on säädettävä herkkyys ja akselin käännös.
- Hiiri-, vieritys- ja hotbar-eleet.
- Valinnainen toiminta: napauta asettaaksesi lohkoja, pidä painettuna murtaaksesi lohkoja.
- Kaksoisnapauta hotbaria vaihtaaksesi pidetyn kohteen kädestä toiseen.
- Liukuva hotbar ja säädettävä pitkä painallus.

### Käynnistysohjelma ja tilit

- **Microsoft**-, **paikallinen/offline-**-, **demo**- ja **Ely.by**-tilituki.
- Hallinnoi **Java 8, 17, 21 ja 25** suoritusaikoja, lataa ne sovelluksen sisällä tai tuo omasi.
- Valitse LWJGL-versiot ja viritä JVM-argumentit, ympäristömuuttujat ja muistin varaus.
- Automaattinen RAM-hallinta laitteille, joissa on rajoitettu muisti.
- Teemat, korostusvärit, sumennus, reunat, kulman säde, mukautetut käynnistyskirjasimet ja sovelluskuvakkeet.
- Pelin sisäiset **F3-laitteen tiedot**: laitesiru, iOS-versio, käynnistysohjelman nimi/versio, koontiversion numero ja versiotyyppi.
- Valinnaiset **Witch-palvelin**-, CurseForge- ja AI-integraatiot edistyneille asetuksille.
- **52 sovelluksen sisäistä kieltä**, mukaan lukien oikealta vasemmalle luettavat kielipaketit ja hauskat maa-asetukset.

---

<a id="screenshots"></a>
## Kuvakaappauksia

Kuvakaappauksia Witch Launcher 0.0.4:n kehitysversiosta. Käyttöliittymä voi vaihdella versioiden ja teemojen välillä.

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
## Vaatimukset

| Vaatimus | Tiedot |
|---|---|
| **Laite** | iPhone tai iPad arm64-prosessorilla ja Metal-tuella |
| **Järjestelmä** | iOS tai iPadOS **14.0 tai uudempi** |
| **JIT** | Pakollinen. Ota käyttöön JIT - StikDebug, SideStore, TrollStore tai jailbroken-asetus |
| **Tili** | Microsoft-tili, joka omistaa Minecraft virallisia latauksia varten; paikalliset ja demotilat ovat myös saatavilla |
| **Tallennustila** | Tilaa käynnistysohjelmalle, Java:n suoritusajoille, peliversioille, modeille ja maailmoille |
| **Verkko** | Vaaditaan kirjautumiseen, versioiden lataamiseen, sisältöselaimeen ja valinnaisiin verkkopalveluihin |

Witch **ei** sisällä Minecraft pelitiedostoja. Pelitiedostot ladataan käynnistysohjelman kautta, kun olet kirjautunut sisään kelvolliseen tiliin.

### JIT notes

Minecraft: Java Edition vaatii JIT, ja Witch ei voi käynnistää peliä ilman sitä.

- **SideStore / AltStore-tyyliset asennukset:** ota JIT käyttöön Witch:lle ja pidä vaadittu VPN/debugger-yhteys aktiivisena. Sovelluksen sisäinen viesti viittaa kohtiin **LocalDevVPN** ja `CS_DEBUGGED`.
- **StikDebug:** liitä StikDebug Witch:ään ja ota JIT käyttöön. Kohdissa **iOS 26/27** StikDebug on pysyttävä kiinni pelin ollessa käynnissä. `UniversalJIT26.js` kopioidaan tarvittaessa leikepöydälle.
- **TrollStore:** ota **URL Scheme** käyttöön TrollStore:ssa, jos Witch odottaa JIT:a.
- **Jailbroken-laitteet:** käytä haluamaasi JIT-toimintoa.
- Jos käynnistysohjelma pysyy **Odottaa JIT** -näyttöä, tarkista virheenkorjausyhteys, VPN ja TrollStore URL Scheme-asetukset ennen uudelleenkäynnistystä.

JIT toiminta riippuu iOS versiosta ja asennustavasta. Järjestelmäpäivitykset voivat rikkoa olemassa olevat JIT-asetukset.

---

<a id="installation"></a>
## Asennus

Witch on allekirjoitettava laitteellesi. Tämä arkisto ei lähetä varmenteita tai esiallekirjoitettuja IPA-sopimuksia.

### Käytä rakennelmaa

1. Lataa kehitysversio [kehitystyönkulusta](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) tai käytä allekirjoitettua koontiversiota luotettavasta lähteestä.
2. Allekirjoita ja asenna se seuraavilla tavoilla: **SideStore**, **AltStore**, **TrollStore** tai valitse haluamasi sivulataustapa.
3. Ota JIT käyttöön yllä kuvatulla tavalla ennen pelin käynnistämistä.

TrollStore koontiversiot käyttävät lisäoikeuksia, eikä niitä tule asentaa tavallisella sivulatausallekirjoituksella.

### Rakenna lähteestä

Witch:n kääntäminen edellyttää macOS Xcode-komentorivityökaluilla, iOSSDK14.0 tai uudempi, CMake, JDK 8, `ldid`, `wget`, `zip` ja Git.

```bash
git klooni -- rekursiivinen https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Pakatut rakennelmat kirjoitetaan `artifacts/`:ään.

TrollStore-paketin rakentaminen sen sijaan:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Renderöijän lähdelinkit ja koontimuistiinpanot ovat kohdassa [`note.md`](../../note.md).

---

<a id="languages"></a>
## Kielet

Witch Launcher toimitetaan **52 kielipaketin** kanssa. Avaa **Asetukset → Yleiset → Kieli** ja valitse kieli tai valitse **Automaattinen** laitteen kielen seuraamiseksi.

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

Sovellus toimittaa kaikki **52 kielipakettia**. README-käännökset ovat saatavilla **kaikille 52 kielelle**, mukaan lukien englanti.

Jotkut käännökset ovat koneavusteisia ja voivat sisältää hankalia teknisiä termejä. Oikaisut ovat tervetulleita.

Tämän README:n lähdekieli on englanti. Lokalisoidut README:t ovat saatavilla tämän sivun yläreunassa olevasta kielenvalitsimesta ja hakemistosta [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Huomautuksia ja rajoituksia

- **JIT on pakollinen.** Ilman toimivaa JIT-asetusta Minecraft ei käynnisty.
- **iOS 26/27 JIT on herkkä.** StikDebug on säilytettävä liitteenä, ja tulevat käyttöjärjestelmäpäivitykset voivat muuttaa sitä, mikä toimii.
- Renderöijät, jotka on merkitty **kokeelliseksi**, voivat kaatua tai renderöidä väärin. Aloita valitsemalla **Automaattinen**, jos olet epävarma.
- **Kehysten luominen** vaatii MoltenVK:n renderöijän ja Metal:n laskentatuen. Se voi lisätä akun käyttöä ja laitteen lämpötilaa.
- Jotkut modit, modpackit, shaderit ja maailmat saattavat vaatia tietyn Minecraft version, lataajan, renderöijän tai lisämuistin.
- CurseForge modpackit käyttävät `manifest.json`; jos yhden napautuksen asennus ei ole saatavilla paketille, tuo arkisto manuaalisesti.
- Online-ominaisuudet riippuvat kolmannen osapuolen palveluista, eivätkä ne välttämättä ole käytettävissä.
- Kuvakaappaukset ovat kehitysversiosta, eivätkä ne välttämättä vastaa nykyistä julkaisua tarkasti.

---

<a id="project-lineage"></a>
## Projektiperintö

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

### Aiheeseen liittyvät projektit

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Osallistuminen

Virheraportit ja PR:t ovat tervetulleita. Ilmoita ongelmasta:

- laitemalli ja iOS/iPadOS versio
- Witch Launcher versio
- renderöijä ja Minecraft versio
- mod loader ja luettelo asennetuista modeista
- lisääntymisvaiheet
- asiaankuuluva loki tai virheraportti

Älä sitoudu allekirjoittamaan varmenteita, hallintaprofiileja, API avaimia tai muita salaisuuksia.

---

<a id="credits"></a>
## Krediitit

**Witch Launcher** ylläpitää **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Ylävirta ja yhteisö

Witch Launcher ja sen alkuvaiheen projektit perustuvat monien avustajien työhön, mukaan lukien:

- **@crystall1nedev** — Amethyst-projektipäällikkö ja iOS-portin kehittäjä
- **@khanhduytran0** — iOS portin kehittäjä
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Lisäkiitos **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE Project, Khronos Group, Mesa Project, PojavLauncher Team, Mozilla ja Minecraft yhteisö.

Erityiset kiitokset [MCHeads](https://mc-heads.net) Minecraft avatarpalveluiden tarjoamisesta.

Täydellinen kolmannen osapuolen komponentti- ja lisenssiluettelo on saatavilla kohdassa [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Lisenssi

Witch Launcher jaetaan **GNU General Public License v3.0** -lisenssillä [`credits.md`](../../credits.md) lueteltujen kolmannen osapuolen komponenttien lisenssien ja tekijänoikeusvaatimusten mukaisesti.

Katso täydellinen lisenssiteksti [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft on Mojang Studios:n tavaramerkki. Witch Launcher ei liity Mojang Studios, Microsoft tai Amethyst-projektiin.</sub>
</p>
