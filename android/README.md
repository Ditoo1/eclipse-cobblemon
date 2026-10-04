# EclipseCobblemon

Launcher básico de Minecraft Java para Android, con login **premium** (Microsoft) y **offline**.

```
Android → Kotlin (UI, auth, descargas) + Rust (libeclipse_core) → Amethyst/Pojav (JRE + LWJGL + GL) → Minecraft Java
```

Apple tiene su sitio reservado en [`ios/`](ios/README.md): el núcleo Rust ya exporta una C ABI.

## Estructura

```
app/                      App Android (Kotlin + Jetpack Compose)
  auth/                   MicrosoftAuth (device code → Xbox → XSTS → Minecraft), OfflineAuth, AccountStore
  game/                   VersionManager (manifest, client.jar, librerías, assets), LaunchSpec
  launch/AmethystBridge   Escribe launch_spec.json y arranca el runtime
  nativecore/NativeCore   Puente JNI a Rust (con fallback Kotlin si no está la .so)
  MainActivity            Interfaz de prueba
native/                   Crate Rust eclipse_core: JNI (Android) + C ABI (Apple)
ios/                      Reservado para el cliente Apple
scripts/                  build-native.ps1, build-apple.sh
amethyst/                 Runtime Amethyst vendorizado (LGPL-3.0): JNI, JRE, LWJGL, renderers, Activity del juego
amethyst-nsbypass/        Dependencia nativa de Amethyst
```

## Compilar

```powershell
.\scripts\build-native.ps1        # Rust → app/src/main/jniLibs (opcional; sin él se usa Kotlin)
.\gradlew assembleDebug           # APK en app/build/outputs/apk/debug/
.\gradlew testDebugUnitTest       # Tests Kotlin
cd native; cargo test             # Tests Rust
```

## Login premium

Igual que `template-launcher` (`session.rs`): OAuth en `login.live.com` dentro de un WebView
(`MicrosoftLoginActivity`) → Xbox Live → XSTS → Minecraft Services → licencia → perfil.
Usa el client ID público del launcher oficial (`00000000402b5328`, el mismo que PojavLauncher/Amethyst),
así que **no hace falta registrar nada en Azure**. Para producción propia puedes cambiarlo en
`MicrosoftAuth.CLIENT_ID`. Es una práctica extendida, pero no oficial: Microsoft podría bloquearla.

## Interfaz

- **Pantalla principal**: título, tarjeta con el fondo (`res/drawable/bg_eclipse.webp`, desde `ASSETS/`) y botón de play.
  Sin sesión, el play abre Perfil. Mientras descarga, el botón muestra el progreso.
- **Perfil**: login Premium (Microsoft) / Offline y cerrar sesión.
- **Servers**: por ahora vacío.
- **Settings**: versión (por defecto 1.21.1, la de Cobblemon), RAM, descargar/verificar y consola.

## Runtime Amethyst/Pojav

El núcleo de [Amethyst-Android](https://github.com/AngelAuraMC/Amethyst-Android) 1.1.7 está incluido como
módulo librería `:amethyst` (más `:amethyst-nsbypass`). Qué se copió y qué se cambió: [amethyst/VENDORED.md](amethyst/VENDORED.md).

Flujo al pulsar **JUGAR** (`launch/AmethystBridge.kt`):

1. Al arrancar, igual que Amethyst: se cargan las preferencias y se extraen LWJGL, caciocavallo, los parches log4j y los controles.
2. `VersionManager` descarga la versión en el mismo `.minecraft` que usa Amethyst.
3. Se registran la cuenta (`accounts/<nombre>.json`) y el perfil (`launcher_profiles.json`) con la RAM elegida.
4. `NewJREUtil` instala el Java que pide la versión (21 para 1.21.1). Lo descarga de los builds de AngelAuraMC: solo la primera vez, unos ~60 MB.
5. Se abre `net.kdt.pojavlaunch.MainActivity` (proceso `:game`), que arranca la JVM con el renderer y los controles táctiles.

La compilación necesita **SDK 37, NDK 27.3.13750724 y AGP 9.3.1 / Gradle 9.6.1**, igual que Amethyst.
Amethyst es **LGPL-3.0**: si distribuyes el APK, incluye la licencia y el código del módulo `amethyst/`.

## Siguientes pasos (Cobblemon)

- Instalar Fabric Loader 1.21.1: añadir su perfil JSON a `versions/`. `VersionManager` ya soporta librerías con formato Maven.
- Descargar el modpack (Cobblemon + Fabric API) en `mods/`.
- Guardar los tokens cifrados (EncryptedSharedPreferences / Keystore).
