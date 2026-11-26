<p align="center">
  <img src="../../Natives/logo/logo-dev.png" width="120" alt="Witch Launcher logo">
</p>

<h1 align="center">Witch Launcher</h1>

<p align="center">
<strong>Minecraft: Java Edition em iPhone e iPad.</strong><br>
Uma bifurcação iOS e iPadOS de Amethyst construída pela comunidade, mantida por DuyAnh662 (Za_d626).
</p>

<div align="center">

[![Development Build](https://img.shields.io/github/actions/workflow/status/Witch-Launcher/Witch_launcher/development.yml?branch=beta&style=for-the-badge)](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml)
![Platform](https://img.shields.io/badge/platform-iOS%2014%2B%20%7C%20iPadOS-blue?style=for-the-badge)
![Version](https://img.shields.io/badge/version-0.0.4-8b5cf6?style=for-the-badge)
![Languages](https://img.shields.io/badge/languages-52-f59e0b?style=for-the-badge)
![License](https://img.shields.io/badge/license-GPL--3.0-22c55e?style=for-the-badge)

[Recursos](#features) · [Capturas de tela](#screenshots) · [Requisitos](#requirements) · [Instalação](#installation) · [Idiomas](#languages) · [Créditos](#credits) · [Licença](#license)

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
## Sobre

**Witch Launcher** é um fork independente e mantido pela comunidade de [Amethyst](https://github.com/AngelAuraMC/Amethyst-iOS) que traz **Minecraft: Java Edition** para iPhone e iPad. Ele combina uma interface de inicialização de toque com um gerenciador de tempo de execução Java completo, LWJGL e uma pilha de gráficos construída em torno das camadas de tradução Metal, MoltenVK e OpenGL.

Witch baseia-se no trabalho de [Boardwalk](https://github.com/zhuowei/Boardwalk), da comunidade [PojavLauncher](https://github.com/PojavLauncherTeam), Amethyst-iOS e Amethyst-iOS-25. É um projeto independente e não é afiliado a Mojang Studios, Microsoft ou à equipe upstream Amethyst.

> **Versão atual:** 0.0.4 · Veja [`news.md`](../../news.md) para notas de lançamento.

---

<a id="features"></a>
## Recursos

### Minecraft e mods

- Executa a maioria das versões **Minecraft: Java Edition**, desde os primeiros lançamentos Beta até os snapshots mais recentes.
- Suporta **Vanilla, Fabric, Quilt, Forge, NeoForge e OptiFine**.
- Crie **perfis de jogo** isolados com suas próprias configurações, mods, shaders, pacotes de recursos e mundos.
- Navegue e instale conteúdo de **Modrinth e CurseForge** sem sair do inicializador:
  - moda
  - modpacks
  - pacotes de shaders
  - pacotes de recursos
  - mapas e mundos de aventura
- Resolva e instale dependências de mod onde a fonte as fornece.
- Importe JARs do instalador Forge/NeoForge e instale carregadores Fabric/Quilt diretamente do seletor de versão.

### Gráficos e desempenho

- Alterne entre vários renderizadores em **Configurações → Renderizador e exibição**:
  - **gl4es** — OpenGL 2.1 caminho de compatibilidade
  - **ANGLE** — OpenGL ES até Metal ou Vulkan
  - **MobileGlues** — OpenGL 4.0, Minecraft 1.17+, experimental
  - **Zink** — OpenGL 4.1 até Mesa 25 e MoltenVK
  - **LTW** — OpenGL 3.3 a OpenGL ES/Metal, Minecraft 1.17+, experimental
  - **TGLMT** — OpenGL 4.6 Básico até Metal, A11 Bionic ou mais recente
- **TGLMT com suporte para Sodium e Iris** para configurações modernas baseadas em shaders.
- **Geração de quadros** com GPU adaptável ao movimento (MADI) e modos de reprojeto 3D da câmera, incluindo interpolação temporal e extrapolação preditiva.
- Escala de resolução, taxa de quadros máxima, upscaling FSR 1.0, caches de shader GLSL e ajuste por renderizador.
- HUD de desempenho com widgets configuráveis de FPS, CPU, GPU, RAM, temperatura, bateria, relógio e FPS de geração de quadros.
- Gravação de desempenho integrada com gráficos, exportação PNG/PDF e compartilhamento.

### Controles

- Layouts de controle na tela, tamanhos de botões e transparência totalmente personalizáveis.
- Suporte para **teclado e mouse**, incluindo mouse virtual e velocidade ajustável do ponteiro.
- Suporte para **controlador de jogo** com layouts e sensibilidade configuráveis.
- **Giroscópio** com sensibilidade ajustável e inversão de eixo.
- Gestos de mouse, rolagem e barra de atalho.
- Comportamento opcional: toque para colocar blocos, segure para quebrar blocos.
- Toque duas vezes na barra de atalho para trocar o item retido pela mão inábil.
- Hotbar deslizante e tempo de toque longo ajustável.

### Lançador e contas

- Suporte para contas **Microsoft**, **local/off-line**, **demo** e **Ely.by**.
- Gerencie os tempos de execução **Java 8, 17, 21 e 25**, baixe-os no aplicativo ou importe os seus próprios.
- Selecione versões LWJGL e ajuste argumentos JVM, variáveis de ambiente e alocação de memória.
- Gerenciamento automático de RAM para dispositivos com memória limitada.
- Temas, cores de destaque, desfoque, bordas, raio dos cantos, fontes personalizadas do iniciador e ícones de aplicativos.
- **F3 informações do dispositivo no jogo**: chip do dispositivo, iOS versão, nome/versão do iniciador, número da versão e tipo de versão.
- Integrações opcionais com **Witch Server**, CurseForge e AI para configurações avançadas.
- **52 idiomas no aplicativo**, incluindo pacotes de idiomas da direita para a esquerda e localidades divertidas.

---

<a id="screenshots"></a>
## Capturas de tela

Capturas de tela de uma versão de desenvolvimento de Witch Launcher 0.0.4. A interface pode mudar entre versões e temas.

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

| Requisito | Detalhes |
|---|---|
| **Dispositivo** | iPhone ou iPad com processador arm64 e suporte Metal |
| **Sistema** | iOS ou iPadOS **14.0 ou mais recente** |
| **JIT** | Obrigatório. Habilite JIT a StikDebug, SideStore, TrollStore ou uma configuração desbloqueada |
| **Conta** | Uma conta Microsoft que possui Minecraft para downloads oficiais; modos locais e de demonstração também estão disponíveis |
| **Armazenamento** | Espaço para o inicializador, Java tempos de execução, versões de jogos, mods e mundos |
| **Rede** | Obrigatório para login, downloads de versões, navegador de conteúdo e serviços online opcionais |

Witch **não** inclui arquivos de jogo Minecraft. Os arquivos do jogo são baixados através do inicializador após fazer login em uma conta qualificada.

### JIT notas

Minecraft: Java Edition precisa de JIT e Witch não pode iniciar o jogo sem ele.

- **Instalações estilo SideStore / AltStore:** habilite JIT para Witch e mantenha a conexão VPN/depurador necessária ativa. A mensagem no aplicativo refere-se a **LocalDevVPN** e `CS_DEBUGGED`.
- **StikDebug:** anexe StikDebug a Witch e ative JIT. Em **iOS 26/27**, StikDebug deverá permanecer conectado enquanto o jogo estiver rodando. `UniversalJIT26.js` é copiado para a área de transferência quando necessário.
- **TrollStore:** habilite **URL Scheme** em TrollStore se Witch continuar esperando por JIT.
- **Dispositivos desbloqueados:** use seu ativador JIT preferido.
- Se o inicializador permanecer na tela **Aguardando JIT**, verifique a conexão do depurador, o VPN e a configuração TrollStore URL Scheme antes de reiniciar.

O comportamento do JIT depende da versão do iOS e do método de instalação. As atualizações do sistema podem quebrar as configurações JIT existentes.

---

<a id="installation"></a>
## Instalação

Witch deve ser assinado para o seu dispositivo. Este repositório não envia certificados ou IPAs pré-assinados.

### Usar uma compilação

1. Baixe uma versão de desenvolvimento do [fluxo de trabalho de desenvolvimento](https://github.com/Witch-Launcher/Witch_launcher/actions/workflows/development.yml) ou use uma versão assinada de uma fonte confiável.
2. Assine e instale-o com **SideStore**, **AltStore**, **TrollStore** ou seu método de sideload preferido.
3. Habilite JIT conforme descrito acima antes de iniciar o jogo.

As compilações TrollStore usam direitos adicionais e não devem ser instaladas com um assinante de sideload normal.

### Construir a partir da fonte

Compilar Witch requer macOS com ferramentas de linha de comando Xcode, um iOS SDK 14.0 ou mais recente, CMake, JDK 8, `ldid`, `wget`, `zip` e Git.

```bash
clone git --recursivo https://github.com/Witch-Launcher/Witch_launcher.git
cd Witch_launcher
make jre-download
make -j"$(sysctl -n hw.ncpu)" package
```

As compilações empacotadas são gravadas em `artifacts/`.

Para construir um pacote TrollStore:

```bash
make package TROLLSTORE_JIT_ENT=1
```

Para links de fontes de renderização e notas de construção, consulte [`note.md`](../../note.md).

---

<a id="languages"></a>
## Idiomas

Witch Launcher vem com **pacotes de 52 idiomas**. Abra **Configurações → Geral → Idioma** e selecione um idioma ou use **Automático** para seguir o idioma do dispositivo.

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

O aplicativo fornece todos os **52 pacotes de idiomas**. As traduções README estão disponíveis para **todos os 52 idiomas**, incluindo inglês.

Algumas traduções são assistidas por máquina e podem conter termos técnicos inadequados. Correções são bem-vindas.

Inglês é o idioma de origem deste README. READMEs localizados estão disponíveis no seletor de idioma no topo desta página e no diretório [`docs/readme/`](./).

---

<a id="notes-and-limitations"></a>
## Notas e limitações

- **JIT é obrigatório.** Sem uma configuração funcional de JIT, Minecraft não será iniciado.
- **iOS 26/27 JIT é frágil.** StikDebug deve permanecer anexado e atualizações futuras do sistema operacional podem alterar o que funciona.
- Os renderizadores marcados como **experimentais** podem travar ou renderizar incorretamente. Comece com **Auto** se não tiver certeza.
- **A geração de quadros** requer o renderizador MoltenVK e o suporte computacional Metal. Pode aumentar o uso da bateria e a temperatura do dispositivo.
- Alguns mods, modpacks, shaders e mundos podem exigir uma versão Minecraft específica, carregador, renderizador ou memória adicional.
- CurseForge modpacks usam `manifest.json`; se a instalação com um toque não estiver disponível para um pacote, importe o arquivo manualmente.
- Os recursos online dependem de serviços de terceiros e podem estar indisponíveis.
- As capturas de tela são de uma versão de desenvolvimento e podem não corresponder exatamente à versão atual.

---

<a id="project-lineage"></a>
## Linhagem do projeto

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

### Projetos relacionados

- [AmethystAndroid](https://github.com/AngelAuraMC/Amethyst-Android)
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)
- [Amethyst-iOS-25](https://github.com/catsruledogs/Amethyst-iOS-25)
- [Boardwalk](https://github.com/zhuowei/Boardwalk)
- [PojavLauncher](https://github.com/PojavLauncherTeam)

---

<a id="contributing"></a>
## Contribuindo

Relatórios de bugs e PRs são bem-vindos. Ao relatar um problema, inclua:

- modelo do dispositivo e versão iOS/iPadOS
- Witch Launcher versão
- renderizador e versão Minecraft
- carregador de mod e uma lista de mods instalados
- passos para reproduzir
- o log relevante ou relatório de falha

Não comprometa certificados de assinatura, perfis de provisionamento, chaves API ou outros segredos.

---

<a id="credits"></a>
## Créditos

**Witch Launcher** é mantido por **DuyAnh662 (Za_d626)**.

- [TikTok](https://tiktok.com/@za_d626)
- [YouTube](https://youtube.com/@za_d626)
- [X](https://x.com/duyanh662)

### Upstream e comunidade

Witch Launcher e seus projetos upstream baseiam-se no trabalho de muitos colaboradores, incluindo:

- **@crystall1nedev** — Amethyst gerente de projeto e iOS desenvolvedor de porto
- **@khanhduytran0** — iOS desenvolvedor de portas
- **@artdeell**
- **@Mathius-Boulay**
- **@zhuowei**
- **@jkcoxson**
- **@Diatrus**
- **@Catsruledogs**
- **@T1k-T1k**

Agradecimentos adicionais a **@lunixbochs**, **@ptitSeb**, **@kakashidinho**, ao Projeto ANGLE, Grupo Khronos, Projeto Mesa, Equipe PojavLauncher, Mozilla e à comunidade Minecraft.

Agradecimentos especiais a [MCHeads](https://mc-heads.net) por fornecer serviços de avatar Minecraft.

A lista completa de componentes de terceiros e licenças está disponível em [`credits.md`](../../credits.md).

---

<a id="license"></a>
## Licença

Witch Launcher é distribuído sob a **Licença Pública Geral GNU v3.0**, sujeito às licenças e requisitos de direitos autorais dos componentes de terceiros listados em [`credits.md`](../../credits.md).

Consulte [`LICENSE`](../../LICENSE) para o texto completo da licença.

---

<p align="center">
<sub>Minecraft é uma marca registrada de Mojang Studios. Witch Launcher não é afiliado a Mojang Studios, Microsoft ou ao projeto Amethyst.</sub>
</p>
