<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition na iPhone i iPad.</strong><br>
Račvanje iOS i iPadOS od Amethyst koje je izgradila zajednica, održava DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Značajke](#features) · [Snimke zaslona](#screenshots) · [Zahtjevi](#requirements) · [Instalacija](#installation) · [Jezici](#languages) · [Zasluge](#credits) · [Licenca](#license)

<details>
<summary><strong>Jezici</strong></summary>

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
## O

**Witch Launcher** je neovisno račvanje [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) koje održava zajednica i koje dovodi **Minecraft: Java Edition** do iPhone i iPad. Kombinira korisničko sučelje pokretača s prvim dodirom s punim Java upraviteljem vremena izvođenja, LWJGL, i grafičkim stogom izgrađenim oko slojeva prijevoda Metal, MoltenVK i OpenGL.

Witch izgrađen je na radu [Boardwalk](https://github.com/zhuowei/Boardwalk), zajednice [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS i Amethyst-iOS-25. To je neovisan projekt i nije povezan s timom Mojang Studios, Microsoft ili uzvodnim timom Amethyst.

> **Trenutna verzija:** 0.0.4 · Pogledajte [`news.md`](../../news.md) za napomene o izdanju.

---

<a id="features"></a>
## Značajke

### Minecraft i mod

- Pokreće većinu **Minecraft: Java Edition** verzija, od ranih Beta izdanja do najnovijih snimaka.
- Podržava **Vanilla, Fabric, Quilt, Forge, NeoForge i OptiFine**.
- Stvorite izolirane **profile igara** s vlastitim postavkama, modovima, shaderima, paketima resursa i svjetovima.
- Pregledajte i instalirajte sadržaj iz **Modrinth i CurseForge** bez napuštanja pokretača:
  - modovi
  - modpackovi
  - shader paketi
  - paketi resursa
  - pustolovne karte i svjetove
- Razriješite i instalirajte mod ovisnosti tamo gdje ih izvor pruža.
- Uvezite JAR-ove programa za instalaciju Forge/NeoForge i instalirajte učitavače Fabric/Quilt izravno iz alata za odabir verzija.

### Grafika i performanse

- Prebacivanje između više iscrtivača iz **Postavke → Iscrtivač i prikaz**:
  - **gl4es** — put kompatibilnosti OpenGL 2.1
  - **ANGLE** — OpenGL ES do Metal ili Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperimentalno
  - **Zink** — OpenGL 4.1 do Mesa 25 i MoltenVK
  - **LTW** — OpenGL 3.3 do OpenGL ES/Metal, Minecraft 1.17+, eksperimentalno
  - **TGLMT** — OpenGL 4.6 Temeljni do Metal, A11 Bionic ili noviji
- **TGLMT s podrškom za Sodium i Iris** za moderne postavke temeljene na shaderima.
- **Frame Generation** s Motion-Adaptive GPU (MADI) i Camera 3D Reproject modovima, uključujući vremensku interpolaciju i prediktivnu ekstrapolaciju.
- Skaliranje razlučivosti, maksimalni broj sličica u sekundi, povećanje FSR 1.0, GLSL predmemorije shadera i podešavanje po rendereru.
- Performansni HUD s podesivim FPS, CPU, GPU, RAM, temperaturom, baterijom, satom i FPS widgetima za generiranje okvira.
- Ugrađeno snimanje izvedbe s grafikonima, PNG/PDF izvoz i dijeljenje.

### Kontrole

- Potpuno prilagodljivi izgledi kontrola na zaslonu, veličina gumba i transparentnost.
- Podrška za **tipkovnicu i miš**, uključujući virtualni miš i podesivu brzinu pokazivača.
- Podrška za **kontroler igre** s podesivim izgledima i osjetljivošću.
- **Žiroskop** ciljanje s podesivom osjetljivošću i inverzijom osi.
- Pokreti mišem, pomicanjem i vrućom trakom.
- Izborno ponašanje: dodirnite za postavljanje blokova, držite za razbijanje blokova.
- Dvaput dodirnite vruću traku da biste zamijenili zadržanu stavku u izvan ruke.
- Klizna vruća traka i podesivo vrijeme dugog pritiska.

### Pokretač i računi

- Podrška za **Microsoft**, **lokalno/izvanmrežno**, **demo** i **Ely.by** račun.
- Upravljajte **Java 8, 17, 21 i 25** vremenima izvođenja, preuzmite ih u aplikaciji ili uvezite vlastite.
- Odaberite LWJGL verzije i podesite JVM argumente, varijable okruženja i dodjelu memorije.
- Automatsko upravljanje RAM-om za uređaje s ograničenom memorijom.
- Teme, naglašene boje, zamućenje, obrubi, radijus uglova, prilagođeni fontovi pokretača i ikone aplikacija.
- **Informacije o uređaju F3** u igri: čip uređaja, verzija iOS, naziv/verzija pokretača, broj verzije i vrsta izrade.
- Izborne integracije **Witch poslužitelja**, CurseForge i AI za napredne postavke.
- **52 jezika u aplikaciji**, uključujući jezične pakete koji se pišu zdesna nalijevo i zabavne jezike.

---

<a id="screenshots"></a>
## Snimke zaslona

Snimke zaslona iz razvojne verzije Witch Launcher 0.0.4. Sučelje se može mijenjati između verzija i tema.

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
## Zahtjevi

| Zahtjev | Detalji |
|---|---|
| **Uređaj** | iPhone ili iPad s arm64 procesorom i Metal podrškom |
| **Sustav** | iOS ili iPadOS **14.0 ili noviji** |
| **JIT** | Potreban. Omogući JIT do StikDebug, SideStore, TrollStore ili jailbroken postavku |
| **Račun** | Račun Microsoft koji posjeduje Minecraft za službena preuzimanja; lokalni i demo način rada također su dostupni |
| **Skladištenje** | Prostor za pokretač, Java runtimes, verzije igre, modifikacije i svjetove |
| **Mreža** | Potreban za prijavu, preuzimanje verzije, preglednik sadržaja i dodatne online usluge |

Witch **ne** uključuje Minecraft datoteke igre. Datoteke igara preuzimaju se putem pokretača nakon prijave na račun koji ispunjava uvjete.

### JIT bilješke

Minecraft: Java Edition treba JIT, a Witch ne može pokrenuti igru bez njega.

- **Instalacije u stilu SideStore / AltStore:** omogućite JIT za Witch i ostavite potrebnu vezu VPN/debugger aktivnom. Poruka unutar aplikacije odnosi se na **LocalDevVPN** i `CS_DEBUGGED`.
- **StikDebug:** pridružite StikDebug Witch i omogućite JIT. Na **iOS 26/27**, StikDebug mora ostati priključen dok igra traje. `UniversalJIT26.js` se po potrebi kopira u međuspremnik.
- **TrollStore:** omogućite **URL Scheme** u TrollStore ako Witch čeka JIT.
- **Jailbroken uređaji:** koristite svoj preferirani JIT enabler.
- Ako pokretač ostane na zaslonu **Čeka se JIT**, prije ponovnog pokretanja provjerite vezu programa za ispravljanje pogrešaka, postavke VPN i TrollStore URL Scheme.

Ponašanje JIT ovisi o verziji iOS i načinu instalacije. Ažuriranja sustava mogu pokvariti postojeće postavke JIT.

---

<a id="installation"></a>
## Instalacija

Witch mora biti potpisan za vaš uređaj. Ovaj repozitorij ne isporučuje certifikate ili unaprijed potpisane IPA-e.

### Koristite izgradnju

1. Preuzmite razvojnu međugradnju iz [tijek rada razvoja](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) ili upotrijebite potpisanu međugradnju iz izvora kojem vjerujete.
2. Potpišite ga i instalirajte pomoću **SideStore**, **AltStore**, **TrollStore** ili željenom metodom bočnog učitavanja.
3. Omogućite JIT kao što je gore opisano prije pokretanja igre.

TrollStore građenja koriste dodatna ovlaštenja i ne bi se trebala instalirati s normalnim potpisivačem bočnog učitavanja.

### Izgradite iz izvora

Prevođenje Witch zahtijeva macOS s Xcode alatima naredbenog retka, iOS SDK 14.0 ili noviji, CMake, JDK 8, `ldid`, `wget`, `zip` i Git.

```bash
git klon --rekurzivni https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Pakirane građevine napisane su u `artifacts/`.

Da biste umjesto toga izgradili paket TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Za izvorne veze renderera i napomene o izradi, pogledajte [`note.md`](../../note.md).

---

<a id="languages"></a>
## jezici

Witch Launcher isporučuje se s **52 jezična paketa**. Otvorite **Postavke → Općenito → Jezik** i odaberite jezik ili koristite **Automatski** za praćenje jezika uređaja.

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

Aplikacija isporučuje sva **52 jezična paketa**. Prijevodi README dostupni su za **sva 52 jezika**, uključujući engleski.

Neki prijevodi su strojno potpomognuti i mogu sadržavati nezgodne tehničke pojmove. Ispravci su dobrodošli.

Engleski je izvorni jezik za ovaj README. Lokalizirani README-ovi dostupni su u biraču jezika na vrhu ove stranice i u direktoriju [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Napomene i ograničenja

- **JIT je obavezan.** Bez ispravnog postavljanja JIT, Minecraft se neće pokrenuti.
- **iOS 26/27 JIT je krhak.** StikDebug mora ostati priključen, a buduća ažuriranja OS-a mogu promijeniti ono što radi.
- Rendereri označeni kao **eksperimentalni** mogu se srušiti ili neispravno prikazati. Počnite s **Automatski** ako niste sigurni.
- **Generacija okvira** zahtijeva MoltenVK renderer i Metal podršku za računanje. Može povećati potrošnju baterije i temperaturu uređaja.
- Neki modovi, paketi modifikacija, shaderi i svjetovi mogu zahtijevati određenu Minecraft verziju, učitavač, renderer ili dodatnu memoriju.
- CurseForge modpakovi koriste `manifest.json`; ako instalacija jednim dodirom nije dostupna za paket, ručno uvezite arhivu.
- Online značajke ovise o uslugama trećih strana i mogu biti nedostupne.
- Snimke zaslona su iz razvojne verzije i možda neće točno odgovarati trenutnom izdanju.

---

<a id="project-lineage"></a>
## Projektna loza

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

### Povezani projekti

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Doprinos

Izvješća o greškama i PR-ovi su dobrodošli. Prilikom prijave problema uključite:

- model uređaja i verzija iOS/iPadOS
- Witch Launcher verzija
- renderer i verzija Minecraft
- mod loader i popis instaliranih modova
- korake za reprodukciju
- relevantni dnevnik ili izvješće o padu

Nemojte predavati certifikate za potpisivanje, profile za dodjelu, API ključeve ili druge tajne.

---

<a id="credits"></a>
## Zasluge

**Witch Launcher** održava **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Uzvodno i zajednica

Witch Launcher i njegovi uzvodni projekti izgrađeni su na radu mnogih suradnika, uključujući:

- **@crystall1nedev** — voditelj projekta Amethyst i programer porta iOS
- **@khanhduytran0** — iOS programer portova
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Dodatna zahvala **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, projektu ANGLE, Khronos grupi, projektu Mesa, timu PojavLauncher, Mozilli i zajednici Minecraft.

Posebna zahvala [MCHeads](https://mc-heads.net) za pružanje usluga avatara Minecraft.

Kompletan popis komponenti treće strane i licenci dostupan je u [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licenca

Witch Launcher se distribuira pod **GNU Općom javnom licencom v3.0**, podložno licencama i zahtjevima za autorska prava komponenti trećih strana navedenih u [`credits.md`](../../credits.md).

Pogledajte [`LICENSE`](../../LICENSE) za potpuni tekst licence.

---

<p align="center">
<sub>Minecraft je zaštitni znak Mojang Studios. Witch Launcher nije povezan s Mojang Studios, Microsoft ili projektom Amethyst.</sub>
</p>
