<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition w iPhone i iPad.</strong><br>
Stworzone przez społeczność rozwidlenie iOS i iPadOS Amethyst, obsługiwane przez DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Funkcje](#features) · [Zrzuty ekranu](#screenshots) · [Wymagania](#requirements) · [Instalacja](#installation) · [Języki](#languages) · [Napisy](#credits) · [Licencja](#license)

<details>
<summary><strong>Języki</strong></summary>

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

**Witch Launcher** to niezależne, utrzymywane przez społeczność rozwidlenie [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS), które przenosi **Minecraft: Java Edition** do iPhone i iPad. Łączy w sobie interfejs użytkownika uruchamiający uruchamiany dotykiem z pełnym menedżerem czasu wykonywania Java, LWJGL i stosem graficznym zbudowanym wokół warstw tłumaczeń Metal, MoltenVK i OpenGL.

Witch opiera się na pracy [Boardwalk](https://github.com/zhuowei/Boardwalk), wspólnoty [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS i Amethyst-iOS-25. Jest to niezależny projekt i nie jest powiązany z Mojang Studios, Microsoft ani zespołem wyższego szczebla Amethyst.

> **Aktualna wersja:** 0.0.4 · Zobacz [`news.md`](../../news.md), aby uzyskać informacje o wydaniu.

---

<a id="features"></a>
## Funkcje

### Minecraft i mody

- Obsługuje większość wersji **Minecraft: Java Edition**, od wczesnych wersji Beta po najnowsze migawki.
- Obsługuje **Vanilla, Fabric, Quilt, Forge, NeoForge i OptiFine**.
- Twórz izolowane **profile gier** z własnymi ustawieniami, modami, shaderami, pakietami zasobów i światami.
- Przeglądaj i instaluj zawartość z **Modrinth i CurseForge** bez opuszczania programu uruchamiającego:
  - mody
  - paczki modów
  - pakiety shaderów
  - pakiety zasobów
  - mapy i światy przygodowe
- Rozwiąż i zainstaluj zależności modów, jeśli źródło je udostępnia.
- Zaimportuj pliki JAR instalatora Forge/NeoForge i zainstaluj moduły ładujące Fabric/Quilt bezpośrednio z selektora wersji.

### Grafika i wydajność

- Przełączaj się między wieloma modułami renderującymi w **Ustawienia → Mechanizm renderujący i wyświetlanie**:
  - **gl4es** — OpenGL 2.1 ścieżka zgodności
  - **ANGLE** — OpenGL ES do Metal lub Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, eksperymentalne
  - **Zink** — OpenGL 4.1 do Mesa 25 i MoltenVK
  - **LTW** — OpenGL 3.3 do OpenGL ES/Metal, Minecraft 1.17+, eksperymentalne
  - **TGLMT** — OpenGL 4.6 Od wersji podstawowej do Metal, A11 Bionic lub nowszej
- **TGLMT z obsługą Sodium i Iris** dla nowoczesnych konfiguracji opartych na modułach cieniujących.
- **Generowanie klatek** za pomocą procesora graficznego z funkcją adaptacji ruchu (MADI) i trybów odtwarzania obrazu 3D z kamery, w tym interpolacji czasowej i ekstrapolacji predykcyjnej.
- Skalowanie rozdzielczości, maksymalna liczba klatek na sekundę, skalowanie w górę FSR 1.0, pamięć podręczna modułu cieniującego GLSL i dostrajanie według renderera.
- Wydajność HUD z konfigurowalnymi widżetami FPS, CPU, GPU, RAM, temperaturą, baterią, zegarem i generowaniem klatek.
- Wbudowane nagrywanie występów z wykresami, eksport PNG/PDF i udostępnianie.

### Sterowanie

- W pełni konfigurowalne układy elementów sterujących na ekranie, rozmiary przycisków i przezroczystość.
- **Obsługa klawiatury i myszy**, w tym wirtualnej myszy i regulowanej szybkości wskaźnika.
- Obsługa **kontrolera gier** z konfigurowalnymi układami i czułością.
- **Żyroskop** celowanie z regulowaną czułością i inwersją osi.
- Gesty myszy, przewijania i paska skrótów.
- Opcjonalne zachowanie: dotknij, aby umieścić bloki, przytrzymaj, aby rozbić bloki.
- Kliknij dwukrotnie pasek skrótów, aby zamienić trzymany przedmiot na drugą rękę.
- Przesuwany pasek skrótów i regulowany czas długiego naciśnięcia.

### Launcher i konta

- Pomoc dotycząca kont **Microsoft**, **lokalnego/offline**, **demo** i **Ely.by**.
- Zarządzaj środowiskami wykonawczymi **Java 8, 17, 21 i 25**, pobieraj je w aplikacji lub importuj własne.
- Wybierz wersje LWJGL i dostosuj argumenty JVM, zmienne środowiskowe i alokację pamięci.
- Automatyczne zarządzanie pamięcią RAM dla urządzeń z ograniczoną pamięcią.
- Motywy, kolory akcentujące, rozmycie, obramowania, promień narożnika, niestandardowe czcionki programu uruchamiającego i ikony aplikacji.
- **Informacje o urządzeniu w grze F3**: chip urządzenia, wersja iOS, nazwa/wersja programu uruchamiającego, numer kompilacji i typ kompilacji.
- Opcjonalne integracje **Witch Server**, CurseForge i AI dla zaawansowanych konfiguracji.
- **52 języki w aplikacji**, w tym pakiety językowe pisane od prawej do lewej i ciekawe lokalizacje.

---

<a id="screenshots"></a>
## Zrzuty ekranu

Zrzuty ekranu z wersji rozwojowej Witch Launcher 0.0.4. Interfejs może zmieniać się pomiędzy wersjami i motywami.

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
## Wymagania

| Wymóg | Szczegóły |
|---|---|
| **Urządzenie** | iPhone lub iPad z procesorem arm64 i obsługą Metal |
| **System** | iOS lub iPadOS **14.0 lub nowszy** |
| **JIT** | Wymagany. Włącz JIT do StikDebug, SideStore, TrollStore lub konfigurację po jailbreaku |
| **Konto** | Konto Microsoft, które jest właścicielem Minecraft do oficjalnych plików do pobrania; dostępne są także tryby lokalne i demo |
| **Przechowywanie** | Miejsce na program uruchamiający, środowiska wykonawcze Java, wersje gier, mody i światy |
| **Sieć** | Wymagane do logowania, pobierania wersji, przeglądarki treści i opcjonalnych usług online |

Witch **nie** obejmuje plików gry Minecraft. Pliki gry są pobierane poprzez program uruchamiający po zalogowaniu się na kwalifikujące się konto.

### JIT notatki

Minecraft: Java Edition wymaga JIT, a Witch nie może bez niego uruchomić gry.

- **Instalacje w stylu SideStore / AltStore:** włącz JIT dla Witch i utrzymuj wymagane połączenie VPN/debuggera aktywne. Wiadomość w aplikacji odnosi się do **LocalDevVPN** i `CS_DEBUGGED`.
- **StikDebug:** dołącz StikDebug do Witch i włącz JIT. W przypadku **iOS 26/27**, StikDebug musi pozostać podłączony podczas trwania gry. W razie potrzeby `UniversalJIT26.js` jest kopiowany do schowka.
- **TrollStore:** włącz **URL Scheme** w TrollStore, jeśli Witch czeka na JIT.
- **Urządzenia po jailbreaku:** użyj preferowanego modułu JIT.
- Jeśli program uruchamiający pozostaje na ekranie **Oczekiwanie na JIT**, przed ponownym uruchomieniem sprawdź połączenie debugera, ustawienia VPN i TrollStore URL Scheme.

Zachowanie JIT zależy od wersji iOS i metody instalacji. Aktualizacje systemu mogą przerwać istniejące konfiguracje JIT.

---

<a id="installation"></a>
## Instalacja

Witch musi być podpisany dla Twojego urządzenia. To repozytorium nie dostarcza certyfikatów ani wstępnie podpisanych umów IPA.

### Użyj kompilacji

1. Pobierz wersję rozwojową z [przebiegu prac programistycznych] (https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) lub użyj podpisanej kompilacji z zaufanego źródła.
2. Podpisz i zainstaluj za pomocą **SideStore**, **AltStore**, **TrollStore** lub preferowanej metody bocznego ładowania.
3. Włącz JIT zgodnie z powyższym opisem przed uruchomieniem gry.

Kompilacje TrollStore korzystają z dodatkowych uprawnień i nie powinny być instalowane przy użyciu zwykłego programu podpisującego ładowanego z boku.

### Kompiluj ze źródła

Kompilacja Witch wymaga macOS z narzędziami wiersza poleceń Xcode, iOS SDK 14.0 lub nowszy, CMake, JDK 8, `ldid`, `wget`, `zip` i Git.

```bash
git clone --rekurencyjny https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

Kompilacje pakietowe są zapisane w `artifacts/`.

Aby zamiast tego zbudować pakiet TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Linki do źródeł modułu renderującego i notatki dotyczące kompilacji można znaleźć w [`note.md`](../../note.md).

---

<a id="languages"></a>
## Języki

Witch Launcher jest dostarczany z **52 pakietami językowymi**. Otwórz **Ustawienia → Ogólne → Język** i wybierz język lub użyj opcji **Auto**, aby dostosować się do języka urządzenia.

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

Aplikacja zawiera wszystkie **52 pakiety językowe**. Tłumaczenia README są dostępne dla **wszystkich 52 języków**, w tym angielskiego.

Niektóre tłumaczenia są wspomagane maszynowo i mogą zawierać niezręczne terminy techniczne. Poprawki mile widziane.

Językiem źródłowym tego pliku README jest język angielski. Zlokalizowane pliki README są dostępne w menu wyboru języka na górze tej strony oraz w katalogu [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Uwagi i ograniczenia

- **JIT jest obowiązkowy.** Bez działającej konfiguracji JIT, Minecraft nie zostanie uruchomiony.
- **iOS 26/27 JIT jest delikatny.** StikDebug musi pozostać dołączony, a przyszłe aktualizacje systemu operacyjnego mogą zmienić to, co działa.
- Moduły renderujące oznaczone jako **eksperymentalne** mogą ulec awarii lub renderować nieprawidłowo. Jeśli nie masz pewności, zacznij od opcji **Auto**.
- **Generowanie ramek** wymaga modułu renderującego MoltenVK i obsługi obliczeń Metal. Może zwiększyć zużycie baterii i temperaturę urządzenia.
- Niektóre mody, pakiety modów, shadery i światy mogą wymagać określonej wersji Minecraft, modułu ładującego, modułu renderującego lub dodatkowej pamięci.
- Pakiety modów CurseForge korzystają z `manifest.json`; jeśli dla pakietu nie jest dostępna instalacja jednym dotknięciem, zaimportuj archiwum ręcznie.
- Funkcje online zależą od usług stron trzecich i mogą być niedostępne.
- Zrzuty ekranu pochodzą z wersji rozwojowej i mogą nie odpowiadać dokładnie bieżącej wersji.

---

<a id="project-lineage"></a>
## Pochodzenie projektu

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

### Powiązane projekty

- [Amethyst Android](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Wkład

Raporty o błędach i PR są mile widziane. Zgłaszając problem, podaj:

- model urządzenia i wersja iOS/iPadOS
- Wersja Witch Launcher
- renderer i wersja Minecraft
- moduł ładujący mod i lista zainstalowanych modów
- kroki do odtworzenia
- odpowiedni dziennik lub raport o awarii

Proszę nie podpisywać certyfikatów, profili udostępniania, kluczy API ani innych tajemnic.

---

<a id="credits"></a>
## Kredyty

**Witch Launcher** jest utrzymywany przez **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream i społeczność

Witch Launcher i związane z nim projekty wydobywcze opierają się na pracy wielu autorów, w tym:

- **@crystall1nedev** — kierownik projektu Amethyst i programista portu iOS
- **@khanhduytran0** — iOS programista portu
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Dodatkowe podziękowania dla **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, projektu ANGLE, Khronos Group, projektu Mesa, zespołu PojavLauncher, Mozilli i społeczności Minecraft.

Specjalne podziękowania dla [MCHeads](https://mc-heads.net) za udostępnienie usługi awatara Minecraft.

Pełna lista komponentów i licencji innych firm jest dostępna w [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licencja

Witch Launcher jest rozpowszechniany na podstawie **GNU General Public License v3.0**, z zastrzeżeniem licencji i wymogów dotyczących praw autorskich komponentów stron trzecich wymienionych w [`credits.md`](../../credits.md).

Pełny tekst licencji znajdziesz w [`LICENSE`](../../LICENSE).

---

<p align="center">
<sub>Minecraft jest znakiem towarowym Mojang Studios. Witch Launcher nie jest powiązany z projektem Mojang Studios, Microsoft ani Amethyst.</sub>
</p>
