# EclipseCobblemon para iPhone (en preparación)

## Decisión: partir de un fork de Amethyst-iOS

En Android, Amethyst se integra como librería dentro de nuestra app. En iOS conviene hacerlo al revés:
**hacer un fork de [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS) y cambiarle la marca y la interfaz**.

Motivos:
- Amethyst-iOS es una app completa en Objective-C. Su runtime no está separado como librería, así que integrarlo dentro de una app SwiftUI nuestra supone meses de trabajo.
- Ya resuelve lo más difícil: la JVM en iOS, JIT, LWJGL, los renderers, los controles táctiles y el login de Microsoft.
- Usa la misma licencia que en Android (LGPL-3.0), con las mismas obligaciones: avisos y publicar el código del fork.

## Limitaciones de iOS (no tienen solución en nuestro lado)

| Tema | Realidad |
|---|---|
| App Store | **No es posible.** Apple no permite JIT ni ejecutar código descargado. |
| Instalación | Sideload con **SideStore/AltStore** (Apple ID gratis: 7 días y renovación) o **TrollStore** (solo algunas versiones de iOS). |
| JIT | Obligatorio para que Java vaya fluido. Se activa con StikDebug/SideStore en cada arranque. En iOS 26 o superior hay que revisar la compatibilidad de Amethyst-iOS. |
| Mac | No hace falta: el IPA se puede compilar en **GitHub Actions** (runners macOS gratis en repos públicos). |
| Rendimiento | Es menor que en Android. Hay que probar Cobblemon 1.21.1 en un iPhone con 6 GB de RAM o más. |

## Plan por fases

1. **Compilar el original (sin cambios)**
   - Fork de Amethyst-iOS en GitHub y activar su workflow de Actions.
   - Descargar el IPA sin firmar, instalarlo con SideStore y comprobar que 1.21.1 (vanilla) abre en tu iPhone.
2. **Marca Eclipse**
   - Bundle ID propio (`dev.eclipsecobblemon.ios`), nombre, icono, el fondo `ASSETS/3593.webp` y los colores y la fuente Lexend de la app Android (ver `MainActivity.kt`: Gold F5C542, Night 07070A…).
   - Versión fija 1.21.1 y textos en pt-PT.
3. **Interfaz simplificada**, igual que en Android:
   - acceso Microsoft u offline;
   - botón jugar con progreso;
   - perfil con la pestaña Skin (la API de skins es la misma, ver `auth/SkinApi.kt`);
   - definiciones con la RAM y el borrado de datos.
4. **Contenido del servidor**: Fabric + Cobblemon y los controles `ASSETS/Controles_Eclipse.json`. El formato de Amethyst-iOS es compatible con el de Pojav; hay que verificarlo.
5. **Distribución**:
   - Releases en GitHub con el IPA y una "source" de SideStore, para que se actualice desde la app;
   - repositorio público del fork, por la LGPL.

## Lo que ya está listo en este repo

| Pieza | Dónde |
|---|---|
| Núcleo Rust con C ABI (opcional en el fork) | `native/src/lib.rs` (`mod ffi`), `native/include/` |
| Script XCFramework (necesita macOS o un runner de Actions) | `scripts/build-apple.sh` |
| Lógica de referencia para portar | `app/.../auth/` (Microsoft, skins), `game/VersionManager.kt` |

## Pendiente de decidir por el dueño

- ¿Qué iPhone y qué versión de iOS se usarán para las pruebas? Eso determina si se usa SideStore o TrollStore y si JIT funciona.
- ¿Repositorio público en GitHub para el fork? Lo exige la LGPL y además da Actions macOS gratis.

## Repositorio de iOS

El desarrollo de iOS está en `D:/.TRABAJO/tauridev/eclipsecobblemon-ios` (fork de Amethyst-iOS, se subirá a `Ditoo1/eclipsecobblemon-ios`). Las instrucciones completas están en su `INSTRUCCIONES_IA.md`.
