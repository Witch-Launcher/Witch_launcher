<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition dėl iPhone ir iPad.</strong><br>
Bendruomenės sukurta iOS ir iPadOS šakė iš Amethyst, prižiūrima DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funkcijos](#features) · [Ekrano kopijos](#screenshots) · [Reikalavimai](#requirements) · [Įdiegimas](#installation) · [Kalbos](#languages) · [Kreditai](#credits) · [Licencija](#license)

<details>
<summary><strong>Kalbos</strong></summary>

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
## Apie

**Witch Launcher** yra nepriklausoma, bendruomenės prižiūrima [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) šakė, kuri perkelia **Minecraft: Java Edition** į iPhone ir iPad. Jame sujungiama palietimo paleidimo vartotojo sąsaja su visa Java vykdymo tvarkykle, LWJGL, ir grafikos rinkiniu, sukurtu aplink Metal, MoltenVK ir OpenGL vertimo sluoksnius.

Witch remiasi [Boardwalk](https://github.com/zhuowei/Boardwalk), [PojavLauncher](https://github.com/PojavLauncherTeam) bendruomenės, Amethyst-iOS ir Amethyst-iOS-25 darbais. Tai yra nepriklausomas projektas ir nesusijęs su Mojang Studios, Microsoft ar prieš srovę esančia Amethyst komanda.

> **Dabartinė versija:** 0.0.4 · Išleidimo pastabas rasite [`news.md`](../../news.md).

---

<a id="features"></a>
## Savybės

### Minecraft ir modifikacijos

- Veikia dauguma **Minecraft: Java Edition** versijų, nuo ankstyvųjų beta versijų iki naujausių momentinių nuotraukų.
- Palaikomi **Vanilla, Fabric, Quilt, Forge, NeoForge ir OptiFine**.
- Kurkite atskirus **žaidimo profilius** su savo nustatymais, modifikacijomis, šešėliais, išteklių paketais ir pasauliais.
- Naršykite ir įdiekite turinį iš **Modrinth ir CurseForge** neišeidami iš paleidimo priemonės:
  - modifikacijos
  - modifikacijų paketai
  - šešėlių paketai
  - išteklių paketai
  - nuotykių žemėlapiai ir pasauliai
- Išspręskite ir įdiekite mod priklausomybes ten, kur jas pateikia šaltinis.
- Importuokite Forge/NeoForge diegimo JAR ir įdiekite Fabric/Quilt įkroviklius tiesiai iš versijų rinkiklio.

### Grafika ir našumas

- Perjunkite kelis atvaizdavimo įrenginius iš **Nustatymai → Pateikėjas ir rodymas**:
  - **gl4es** – OpenGL 2.1 suderinamumo kelias
  - **ANGLE** – OpenGL ES iki Metal arba Vulkan
  - **MobileGlues** – OpenGL 4.0, Minecraft 1.17+, eksperimentinis
  - **Zink** – OpenGL 4.1–Mesa 25 ir MoltenVK
  - **LTW** – OpenGL 3.3–OpenGL ES / Metal, Minecraft 1.17+, eksperimentinis
  - **TGLMT** – OpenGL 4.6 Pagrindinis iki Metal, A11 Bionic arba naujesnis
- **TGLMT su Sodium ir Iris palaikymu**, skirta modernioms atspalvių sąrankoms.
- **Kadrų generavimas** su judesiui prisitaikančiu GPU (MADI) ir fotoaparato 3D atkūrimo režimais, įskaitant laiko interpoliaciją ir nuspėjamąją ekstrapoliaciją.
- Rezoliucijos mastelio keitimas, maksimalus kadrų dažnis, FSR 1.0 padidinimas, GLSL šešėlių talpyklos ir reguliavimas pagal atvaizduotoją.
- Našumo HUD su konfigūruojamais FPS, CPU, GPU, RAM, temperatūros, akumuliatoriaus, laikrodžio ir kadrų kartos FPS valdikliais.
- Integruotas našumo įrašymas su diagramomis, PNG/PDF eksportavimas ir bendrinimas.

### Valdikliai

- Visiškai tinkinami ekrano valdymo išdėstymai, mygtukų dydžiai ir skaidrumas.
- **Klaviatūros ir pelės** palaikymas, įskaitant virtualią pelę ir reguliuojamą žymeklio greitį.
- **Žaidimų valdiklio** palaikymas su konfigūruojamais išdėstymais ir jautrumu.
- **Giroskopas** su reguliuojamu jautrumu ir ašies inversija.
- Pelės, slinkties ir karštosios juostos gestai.
- Pasirenkamas elgesys: palieskite, kad įdėtumėte blokus, laikykite, kad sulaužytumėte blokus.
- Dukart bakstelėkite karštąją juostą, kad pakeistumėte laikomą elementą į nenaudojamą.
- Stumdoma karštoji juosta ir reguliuojamas ilgo paspaudimo laikas.

### Paleidimo priemonė ir paskyros

- **Microsoft**, **vietinis / neprisijungęs**, **demonstracinės versijos** ir **Ely.by** paskyros palaikymas.
- Tvarkykite **Java 8, 17, 21 ir 25** vykdymo laiką, atsisiųskite juos programoje arba importuokite savo.
- Pasirinkite LWJGL versijas ir suderinkite JVM argumentus, aplinkos kintamuosius ir atminties paskirstymą.
- Automatinis RAM valdymas įrenginiams su ribota atmintimi.
- Temos, akcento spalvos, suliejimas, kraštinės, kampo spindulys, pasirinktiniai paleidimo šriftai ir programų piktogramos.
- Žaidimo **F3 įrenginio informacija**: įrenginio lustas, iOS versija, paleidimo priemonės pavadinimas / versija, versijos numeris ir versijos tipas.
- Pasirenkama **Witch serverio**, CurseForge ir AI integracija išplėstinei sąrankai.
- **52 kalbos programoje**, įskaitant kalbų paketus iš dešinės į kairę ir linksmas lokales.

---

<a id="screenshots"></a>
## Ekrano nuotraukos

Ekrano kopijos iš Witch Launcher 0.0.4 kūrimo versijos. Sąsaja gali keistis tarp versijų ir temų.

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
## Reikalavimai

| Reikalavimas | Išsami informacija |
|---|---|
| **Įrenginys** | iPhone arba iPad su arm64 procesoriumi ir Metal palaikymu |
| **Sistema** | iOS arba iPadOS **14.0 arba naujesnė** |
| **JIT** | Required. Enable JIT through StikDebug, SideStore, TrollStore, or a jailbroken setup |
| **Paskyra** | Microsoft paskyra, kuriai priklauso Minecraft oficialiems atsisiuntimams; taip pat galimi vietiniai ir demonstraciniai režimai |
| **Saugykla** | Vieta paleidimo priemonei, Java vykdymo laikas, žaidimų versijos, modifikacijos ir pasauliai |
| **Tinklas** | Reikalingas prisijungimui, versijų atsisiuntimui, turinio naršyklei ir pasirenkamoms internetinėms paslaugoms |

Witch **neapima** Minecraft žaidimų failų. Žaidimų failai atsisiunčiami per paleidimo priemonę prisijungus prie tinkamos paskyros.

### JIT pastabos

Minecraft: Java Edition reikia JIT, o Witch negali paleisti žaidimo be jo.

- **SideStore / AltStore stiliaus diegimai:** įgalinkite JIT, skirtą Witch, ir laikykite aktyvų reikiamą VPN/derinimo ryšį. Pranešimas programoje nurodo **LocalDevVPN** ir `CS_DEBUGGED`.
- **StikDebug:** pridėkite StikDebug prie Witch ir įgalinkite JIT. **iOS 26/27**, StikDebug turi likti prijungtas, kol žaidimas vyksta. `UniversalJIT26.js` prireikus nukopijuojamas į mainų sritį.
- **TrollStore:** įgalinkite **URL Scheme** TrollStore, jei Witch ir toliau laukia JIT.
- **Įrenginiai, sugadinti:** naudokite pageidaujamą JIT įgalinimo priemonę.
- Jei paleidimo priemonė lieka ekrane **Laukiama JIT**, prieš paleisdami iš naujo patikrinkite derinimo priemonės ryšį, VPN ir TrollStore URL Scheme nustatymus.

JIT elgsena priklauso nuo iOS versijos ir diegimo būdo. Sistemos naujiniai gali sugadinti esamas JIT nuostatas.

---

<a id="installation"></a>
## Montavimas

Witch turi būti pasirašytas jūsų įrenginiui. Ši saugykla nesiunčia sertifikatų ar iš anksto pasirašytų IPA.

### Naudokite konstrukciją

1. Atsisiųskite kūrimo versiją iš [kūrimo darbo eigos] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) arba naudokite pasirašytą versiją iš šaltinio, kuriuo pasitikite.
2. Pasirašykite ir įdiekite naudodami **SideStore**, **AltStore**, **TrollStore** arba pasirinktą šalutinio įkėlimo metodą.
3. Prieš paleisdami žaidimą, įjunkite JIT, kaip aprašyta aukščiau.

TrollStore versijose naudojamos papildomos teisės ir jos neturėtų būti įdiegtos naudojant įprastą šoninio įkėlimo signerą.

### Sukurkite iš šaltinio

Kompiliuojant Witch reikia macOS su Xcode komandų eilutės įrankiais, iOS SDK 14.0 ar naujesne, CMake, JDK 8, `ldid`, `wget`, `zip` ir Git.

```bash
git klonas -- rekursyvus https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Supakuotos versijos rašomos pagal `artifacts/`.

Jei norite sukurti TrollStore paketą:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Pateikimo šaltinio nuorodų ir kūrimo pastabų žr. [`note.md`](../../note.md).

---

<a id="languages"></a>
## Kalbos

Witch Launcher pristatomas su **52 kalbų paketais**. Atidarykite **Nustatymai → Bendrieji → Kalba** ir pasirinkite kalbą arba naudokite **Automatinis**, kad stebėtumėte įrenginio kalbą.

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

Programa pristato visus **52 kalbų paketus**. README vertimai galimi **visomis 52 kalbomis**, įskaitant anglų kalbą.

Kai kurie vertimai atliekami mašininiu būdu ir juose gali būti nepatogių techninių terminų. Pataisymai laukiami.

Anglų yra šios README šaltinio kalba. Lokalizuotas README galima rasti šio puslapio viršuje esančiame kalbos parinkiklyje ir [`docs/readme/`](./) kataloge.

---

<a id="notes-and-limitations"></a>
## Pastabos ir apribojimai

- **JIT yra privaloma.** Be veikiančios JIT sąrankos, Minecraft nebus paleista.
- **iOS 26/27 JIT yra trapi.** StikDebug turi likti pridėta, o būsimi OS naujiniai gali pakeisti tai, kas veikia.
- Pateikėjai, pažymėti **eksperimentiniais**, gali užstrigti arba pateikti netinkamai. Jei nesate tikri, pradėkite nuo **Automatinis**.
- **Kadrų generavimui** reikalingas MoltenVK pateikimas ir Metal skaičiavimo palaikymas. Tai gali padidinti akumuliatoriaus naudojimą ir įrenginio temperatūrą.
- Kai kurioms modifikacijoms, modifikacijų paketams, šešėliams ir pasauliams gali prireikti konkrečios Minecraft versijos, įkroviklio, atvaizdavimo priemonės arba papildomos atminties.
- CurseForge modifikavimo paketai naudoja `manifest.json`; jei paketo diegimas vienu paspaudimu negalimas, importuokite archyvą rankiniu būdu.
- Internetinės funkcijos priklauso nuo trečiųjų šalių paslaugų ir gali būti nepasiekiamos.
- Ekrano kopijos yra iš kūrimo versijos ir gali tiksliai neatitikti dabartinio leidimo.

---

<a id="project-lineage"></a>
## Projekto kilmė

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

### Susiję projektai

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Prisideda

Laukiami pranešimai apie klaidas ir viešieji ryšiai. Pranešdami apie problemą, įtraukite:

- įrenginio modelis ir iOS/iPadOS versija
- Witch Launcher versija
- atvaizduotojas ir Minecraft versija
- mod loader ir įdiegtų modifikacijų sąrašas
- dauginimosi žingsniai
- atitinkamą žurnalą arba avarijos ataskaitą

Neįsipareigokite pasirašyti sertifikatų, sudarymo profilių, API raktų ar kitų paslapčių.

---

<a id="credits"></a>
## Kreditai

**Witch Launcher** prižiūri **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Prieš srovę ir bendruomenė

Witch Launcher ir jos pirmieji projektai yra sukurti remiantis daugelio bendraautorių darbu, įskaitant:

- **@crystall1nedev** – Amethyst projekto vadovas ir iOS prievado kūrėjas
- **@khanhduytran0** – iOS prievado kūrėjas
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Papildoma ačiū **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ANGLE projektui, Khronos grupei, Mesa projektui, PojavLauncher komandai, Mozilla ir Minecraft bendruomenei.

Ypatingas ačiū [MCHeads](https://mc-heads.net) už Minecraft avataro paslaugų teikimą.

Visą trečiosios šalies komponentų ir licencijų sąrašą rasite [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licencija

Witch Launcher platinama pagal **GNU bendrąją viešąją licenciją v3.0**, atsižvelgiant į [`credits.md`](../../credits.md) išvardytų trečiųjų šalių komponentų licencijas ir autorių teisių reikalavimus.

Visą licencijos tekstą rasite [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft yra Mojang Studios prekės ženklas. Witch Launcher nėra susietas su Mojang Studios, Microsoft ar projektu Amethyst.</sub>
</p>
