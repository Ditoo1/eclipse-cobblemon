# Eclipse Cobblemon para iPhone

Launcher de Minecraft: Java Edition **1.21.1** para a comunidade do servidor **Eclipse Cobblemon**.
É a versão iPhone da app Android, com a mesma interface: inicie sessão com a Microsoft (ou sem ligação),
toque em jogar e entre no mundo.

Baseado no [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) (LGPL-3.0).

## Requisitos

- **iOS 14 ou superior**, iPhone 6s ou posterior.
- **Recomendado:** iPhone 12 Pro, 13 Pro, 14 ou superior · **Mínimo:** iPhone XS.
  A app deteta a memória do iPhone e escolhe a memória do Java e a distância de visão.
- **JIT** ativo para jogar (ver abaixo). Em iOS 17 e 18 é preciso um computador para o ativar.
  Em iOS 26 a compatibilidade ainda não está confirmada.

## Instalação

A app não está na App Store: instala-se um ficheiro IPA.

1. Descarregue o IPA mais recente em **Actions → Development build → Artifacts**
   (`EclipseCobblemon-ipa`; para TrollStore use `EclipseCobblemon-trollstore-tipa`).
2. Instale-o com o **SideStore** ou o **AltStore** (com um Apple ID gratuito, a app expira ao fim de 7 dias e
   tem de ser renovada) ou com o **TrollStore** (só em algumas versões do iOS, sem expirar).
3. Abra a app, inicie sessão e toque em **Jogar**. Na primeira vez, o Minecraft 1.21.1 é transferido
   (várias centenas de MB; use Wi-Fi).
4. Quando a app pedir o JIT, ative-o com o StikDebug, SideStore ou AltStore e volte à app.

### Ativar o JIT

| Aplicação           | AltStore | SideStore | StikDebug | TrollStore | Jailbreak |
|---------------------|----------|-----------|-----------|------------|-----------|
| Precisa de computador | Sim    | Só a 1.ª vez | Só a 1.ª vez | Não     | Não       |
| Precisa de Wi-Fi    | Sim      | Só a 1.ª vez | Só a 1.ª vez | Não     | Não       |
| Automático          | Sim (*)  | Não       | Sim       | Sim        | Sim       |

(*) Com o AltServer a correr na rede local.

## Para quem desenvolve

- A interface Eclipse está em `Natives/eclipse/` (`ECLauncherViewController` é o ecrã principal).
- O IPA compila no GitHub Actions (`.github/workflows/development.yml`, runner `macos-26`).
- O workflow `ui-preview.yml` compila para o simulador e guarda capturas de cada ecrã.
- Contexto, decisões e tarefas: `INSTRUCCIONES_IA.md` e `eclipse/tareas/README.md`.

## Licenças

O código do Amethyst-iOS e do PojavLauncher está sob a **GNU LGPL-3.0** (ver `LICENSE`); este repositório
é público com todas as alterações. Tipo de letra Lexend sob a SIL Open Font License 1.1.
Minecraft é uma marca da Mojang AB; esta app não é oficial.

## Créditos do Amethyst

## Contributors
Amethyst is amazing, and surprisingly stable, and it wouldn't be this way without the commmunity that helped and contribute to the project! Some notable names:

@crystall1nedev - Project manager, iOS port developer  
@khanhduytran0 - iOS port developer  
@artdeell  
@Mathius-Boulay  
@zhuowei  
@jkcoxson   
@Diatrus 

## Third party components and their licenses
- [Caciocavallo](https://github.com/PojavLauncherTeam/caciocavallo): [GNU GPLv2 License](https://github.com/PojavLauncherTeam/caciocavallo/blob/master/LICENSE).
- [jsr305](https://code.google.com/p/jsr-305): [3-Clause BSD License](http://opensource.org/licenses/BSD-3-Clause).
- [Boardwalk](https://github.com/zhuowei/Boardwalk): [Apache 2.0 License](https://github.com/zhuowei/Boardwalk/blob/master/LICENSE) 
- [GL4ES](https://github.com/ptitSeb/gl4es) by @lunixbochs @ptitSeb: [MIT License](https://github.com/ptitSeb/gl4es/blob/master/LICENSE).
- [Mesa 3D Graphics Library](https://gitlab.freedesktop.org/mesa/mesa): [MIT License](https://docs.mesa3d.org/license.html).
- [MetalANGLE](https://github.com/khanhduytran0/metalangle) by @kakashidinho and ANGLE team: [BSD 2.0 License](https://github.com/kakashidinho/metalangle/blob/master/LICENSE).
- [MoltenVK](https://github.com/KhronosGroup/MoltenVK): [Apache 2.0 License](https://github.com/KhronosGroup/MoltenVK/blob/master/LICENSE).
- [openal-soft](https://github.com/kcat/openal-soft): [LGPLv2 License](https://github.com/kcat/openal-soft/blob/master/COPYING).
- [Azul Zulu JDK](https://www.azul.com/downloads/?package=jdk): [GNU GPLv2 License](https://openjdk.java.net/legal/gplv2+ce.html).
- [LWJGL3](https://github.com/PojavLauncherTeam/lwjgl3): [BSD-3 License](https://github.com/LWJGL/lwjgl3/blob/master/LICENSE.md).
- [LWJGLX](https://github.com/PojavLauncherTeam/lwjglx) (LWJGL2 API compatibility layer for LWJGL3): unknown license.
- [DBNumberedSlider](https://github.com/khanhduytran0/DBNumberedSlider): [Apache 2.0 License](https://github.com/immago/DBNumberedSlider/blob/master/LICENSE)
- [fishhook](https://github.com/khanhduytran0/fishhook): [BSD-3 License](https://github.com/facebook/fishhook/blob/main/LICENSE).
- [shaderc](https://github.com/khanhduytran0/shaderc) (used by Vulkan rendering mods): [Apache 2.0 License](https://github.com/google/shaderc/blob/main/LICENSE).
- [NRFileManager](https://github.com/mozilla-mobile/firefox-ios/tree/b2f89ac40835c5988a1a3eb642982544e00f0f90/ThirdParty/NRFileManager): [MPL-2.0 License](https://www.mozilla.org/en-US/MPL/2.0)
- [AltKit](https://github.com/rileytestut/AltKit)
- [UnzipKit](https://github.com/abbeycode/UnzipKit): [BSD-2 License](https://github.com/abbeycode/UnzipKit/blob/master/LICENSE).
- [DyldDeNeuralyzer](https://github.com/xpn/DyldDeNeuralyzer): bypasses Library Validation for loading external runtime
- Thanks to [MCHeads](https://mc-heads.net) for providing Minecraft avatars.
