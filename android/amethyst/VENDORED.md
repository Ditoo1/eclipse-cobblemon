# Código vendorizado de Amethyst-Android

| | |
|---|---|
| Origen | https://github.com/AngelAuraMC/Amethyst-Android (fork de PojavLauncher) |
| Versión | 1.1.7, commit `330c6ea` (2026-09-22) |
| Módulo de origen | `app_pojavlauncher/` → aquí `amethyst/` (`src/`, `libs/`, `proguard-rules.pro`) |
| Submódulo | `androidnsbypass` @ `9f57982` → `../amethyst-nsbypass/` (proyecto Gradle `:androidnsbypass`) |
| Licencia | **LGPL-3.0** (ver `LICENSE`). androidnsbypass: ver `../amethyst-nsbypass/LICENSE*` |

## Qué aporta a EclipseCobblemon

- `src/main/jni/`: `libpojavexec`. Contiene el arranque de la JVM en el proceso (`jre_launcher.c`), el puente EGL/GL (`egl_bridge.c`, `ctxbridges/`) y la entrada táctil, de ratón y de teclado para GLFW (`input_bridge_v3.c`).
- `libs/*.aar`: renderers y librerías nativas precompiladas, como MobileGlues, ANGLE, Kopper-Zink, los natives de LWJGL 3.3.3/3.4.1, OpenAL y SDL.
- `assets/components/`: LWJGL para Android, caciocavallo (AWT), parches de log4j y forge_installer.
- `net.kdt.pojavlaunch.multirt` + `NewJREUtil`: instalación del JRE de Android (8/17/21/25).
- `net.kdt.pojavlaunch.MainActivity`: la Activity del juego, con controles táctiles, en el proceso `:game`.

La app lo usa desde `app/.../launch/AmethystBridge.kt`.

## Cambios respecto al original

1. `build.gradle` propio: el módulo pasa de `com.android.application` a `com.android.library`. Se quitan la firma, el applicationId y las tareas de los subproyectos (sus jars ya vienen en `assets/components`).
2. `AndroidManifest.xml`: se quita el `intent-filter` LAUNCHER de `TestStorageActivity`, para que solo haya un icono (EclipseCobblemon).
3. `JavaGUILauncherActivity.java`: `switch (R.id…)` pasa a `if/else`.

4. `../amethyst-nsbypass/build.gradle.kts`: `ndkVersion` fijado al mismo que `:amethyst` (si no, prefab ignora la `.so` y `libpojavexec` no enlaza en release).
5. `build.gradle`: `configureNdkBuild*` depende de `:androidnsbypass:assemble*`.

Para actualizar: copiar de nuevo `app_pojavlauncher/src` y `libs` desde una versión nueva y reaplicar los cambios 2 a 5.
