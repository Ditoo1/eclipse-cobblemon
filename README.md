# Eclipse Cobblemon

[Español](#español) · [English](#english)

---

## Español

Launcher de Minecraft: Java Edition **1.21.1** para la comunidad del servidor **Eclipse Cobblemon**, para **Android** y **iPhone**.
Las dos apps tienen la misma interfaz: inicia sesión con Microsoft (u offline), toca jugar y entra al mundo.

Basado en [Amethyst-Android](https://github.com/AngelAuraMC/Amethyst-Android) y [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) (LGPL-3.0).

### Descarga

Todo está en **Releases**:

| Archivo | Para |
|---|---|
| `EclipseCobblemon-X.Y.Z-android.apk` | Android 8.0 o superior |
| `EclipseCobblemon-X.Y.Z-ios.ipa` | iPhone con SideStore o AltStore |
| `EclipseCobblemon-X.Y.Z-ios-trollstore.tipa` | iPhone con TrollStore |

### Android

1. Descarga el `.apk` en el teléfono y ábrelo. Si Android lo pide, permite instalar apps de esta fuente.
2. Abre la app, inicia sesión y toca **Jugar**. La primera vez se descargan Minecraft 1.21.1 y Java
   (varios cientos de MB; usa Wi-Fi).

Las versiones nuevas se instalan encima de la anterior sin perder datos.

### iPhone

**Requisitos**

- **iOS 14 o superior**, iPhone 6s o posterior.
- **Recomendado:** iPhone 12 Pro, 13 Pro, 14 o superior · **Mínimo:** iPhone XS.
  La app detecta la memoria del iPhone y elige la memoria de Java y la distancia de renderizado.
- **JIT** activo para jugar (ver abajo). En iOS 17 y 18 hace falta un computador para activarlo.
  En iOS 26 la compatibilidad aún no está confirmada.

**Instalación**

La app no está en la App Store: se instala un archivo IPA.

1. Descarga el IPA de la última release.
2. Instálalo con **SideStore** o **AltStore** (con un Apple ID gratuito la app caduca a los 7 días y
   hay que renovarla) o con **TrollStore** (solo en algunas versiones de iOS, no caduca).
3. Abre la app, inicia sesión y toca **Jogar**. La primera vez se descarga Minecraft 1.21.1.
4. Cuando la app pida el JIT, actívalo con StikDebug, SideStore o AltStore y vuelve a la app.

**Activar el JIT**

| | AltStore | SideStore | StikDebug | TrollStore | Jailbreak |
|---|---|---|---|---|---|
| Necesita computador | Sí | Solo la 1.ª vez | Solo la 1.ª vez | No | No |
| Necesita Wi-Fi | Sí | Solo la 1.ª vez | Solo la 1.ª vez | No | No |
| Automático | Sí (*) | No | Sí | Sí | Sí |

(*) Con AltServer funcionando en la red local.

### Desarrollo

| | Android | iPhone |
|---|---|---|
| Código | `android/` (Kotlin + Compose, núcleo Rust en `android/native/`) | raíz del repo (fork de Amethyst-iOS); la interfaz está en `Natives/eclipse/` |
| Build en GitHub Actions | `android.yml` (Ubuntu) | `development.yml` (macOS) |
| Capturas de la interfaz | — | `ui-preview.yml` (simulador) |

Las dos apps deben verse igual: un cambio de interfaz o de textos se hace en ambas.
Para publicar una versión: crea la etiqueta `vX.Y.Z`. `release.yml` compila el APK firmado y el IPA y deja un borrador en Releases.

### Licencias

El código de Amethyst y PojavLauncher está bajo la **GNU LGPL-3.0** (ver `LICENSE`). Quien reciba la app
puede pedir el código de esas partes y de sus modificaciones. Fuente Lexend bajo la SIL Open Font License 1.1
(`LICENSES/`). Minecraft es una marca de Mojang AB; esta app no es oficial.

---

## English

Minecraft: Java Edition **1.21.1** launcher for the **Eclipse Cobblemon** server community, for **Android** and **iPhone**.
Both apps share the same interface: sign in with Microsoft (or offline), tap play and jump into the world.

Based on [Amethyst-Android](https://github.com/AngelAuraMC/Amethyst-Android) and [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) (LGPL-3.0).

### Download

Everything is in **Releases**:

| File | For |
|---|---|
| `EclipseCobblemon-X.Y.Z-android.apk` | Android 8.0 or later |
| `EclipseCobblemon-X.Y.Z-ios.ipa` | iPhone with SideStore or AltStore |
| `EclipseCobblemon-X.Y.Z-ios-trollstore.tipa` | iPhone with TrollStore |

### Android

1. Download the `.apk` on your phone and open it. If Android asks, allow installing apps from this source.
2. Open the app, sign in and tap **Jugar**. The first time, Minecraft 1.21.1 and Java are downloaded
   (several hundred MB; use Wi-Fi).

New versions install over the previous one without losing data.

### iPhone

**Requirements**

- **iOS 14 or later**, iPhone 6s or newer.
- **Recommended:** iPhone 12 Pro, 13 Pro, 14 or newer · **Minimum:** iPhone XS.
  The app detects the iPhone's memory and picks the Java memory and render distance.
- **JIT** enabled to play (see below). On iOS 17 and 18 you need a computer to enable it.
  iOS 26 compatibility is not confirmed yet.

**Installation**

The app is not on the App Store: you install an IPA file.

1. Download the IPA from the latest release.
2. Install it with **SideStore** or **AltStore** (with a free Apple ID the app expires after 7 days and
   must be refreshed) or with **TrollStore** (only some iOS versions, never expires).
3. Open the app, sign in and tap **Jogar**. The first time, Minecraft 1.21.1 is downloaded.
4. When the app asks for JIT, enable it with StikDebug, SideStore or AltStore and return to the app.

**Enabling JIT**

| | AltStore | SideStore | StikDebug | TrollStore | Jailbreak |
|---|---|---|---|---|---|
| Needs a computer | Yes | First time only | First time only | No | No |
| Needs Wi-Fi | Yes | First time only | First time only | No | No |
| Automatic | Yes (*) | No | Yes | Yes | Yes |

(*) With AltServer running on the local network.

### Development

| | Android | iPhone |
|---|---|---|
| Code | `android/` (Kotlin + Compose, Rust core in `android/native/`) | repo root (Amethyst-iOS fork); the UI is in `Natives/eclipse/` |
| GitHub Actions build | `android.yml` (Ubuntu) | `development.yml` (macOS) |
| UI screenshots | — | `ui-preview.yml` (simulator) |

Both apps must look the same: a UI or text change goes into both.
To publish a version, push the tag `vX.Y.Z`. `release.yml` builds the signed APK and the IPA and leaves a draft in Releases.

### Licenses

Amethyst and PojavLauncher code is under the **GNU LGPL-3.0** (see `LICENSE`). Anyone who receives the app
can request the source of those parts and their modifications. Lexend font under the SIL Open Font License 1.1
(`LICENSES/`). Minecraft is a trademark of Mojang AB; this app is not official.

---

## Amethyst credits

### Contributors
Amethyst is amazing, and surprisingly stable, and it wouldn't be this way without the commmunity that helped and contribute to the project! Some notable names:

@crystall1nedev - Project manager, iOS port developer  
@khanhduytran0 - iOS port developer  
@artdeell  
@Mathius-Boulay  
@zhuowei  
@jkcoxson   
@Diatrus 

### Third party components and their licenses
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
