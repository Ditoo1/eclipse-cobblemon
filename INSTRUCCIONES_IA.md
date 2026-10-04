# Instrucciones para la IA: EclipseCobblemon para iPhone

Lee este archivo completo antes de tocar nada. Supone que no sabes nada del proyecto.

## 1. Qué es esto

**EclipseCobblemon** es un launcher de Minecraft Java para la comunidad del servidor "Eclipse Cobblemon"
(Minecraft **1.21.1** con el mod **Cobblemon**, sobre Fabric).

- **La versión Android ya existe y funciona.** Está hecha en Kotlin/Compose sobre Amethyst-Android y vive en este mismo repo, en **`android/`** (se compila con `.github/workflows/android.yml`).
- **Tu trabajo es la versión iPhone**: la misma experiencia y la misma marca, en iOS.

## 2. De qué partes

**Este repositorio ES un fork de [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS)**
(commit `9212a18`, del 10 de agosto de 2026). Amethyst-iOS es un launcher completo en Objective-C, sucesor de PojavLauncher iOS, que ya resuelve:
JVM en iOS, JIT, LWJGL, renderers GL, controles táctiles, login de Microsoft y descargas de Minecraft.

**No reescribas eso.** Tu trabajo es **cambiar la marca, simplificar y personalizar** su interfaz para que sea la de Eclipse.

| Carpeta | Qué es |
|---|---|
| `Natives/` | Código de la app (Objective-C, vistas UIKit). Aquí están casi todos tus cambios. |
| `Amethyst.xcodeproj`, `Makefile` | Build. |
| `.github/workflows/` | CI que compila el IPA en macOS (`development.yml`, `release.yml`). |
| `entitlements.*.xml` | Entitlements de sideload y TrollStore. |
| **`eclipse/`** | **Todo lo nuestro:** diseño, controles, código de referencia de Android y **las tareas**. |
| `eclipse/tareas/` | **Qué hay que hacer, por fases. Síguelas en orden.** |
| `eclipse/diseno/` | Fondo, fuente Lexend, capturas de la app Android y `TOKENS.md` (colores y tipografía). |
| `eclipse/controles/` | Layout táctil oficial del servidor (formato Pojav/Amethyst). |
| `eclipse/referencia-android/` | Copia antigua del código Android, **solo como referencia**. El código vigente está en `android/app/src/main/java/`. |
| **`android/`** | **App Android completa** (Gradle). Los cambios de interfaz se hacen en las dos plataformas a la par. |

El remoto `upstream` apunta al Amethyst-iOS original, para traer sus actualizaciones.

## 3. Entorno del dueño (importante)

- **Windows, sin Mac.** No hay Xcode local. **Todo se compila en GitHub Actions** (runners macOS).
- La cuenta de GitHub es **`Ditoo1`**. Git ya está configurado en este repo con
  `Ditoo1 <156104433+Ditoo1@users.noreply.github.com>`. No uses otra cuenta (en el PC también existe "Ditocl": **no es la correcta**).
- El repositorio destino debe ser **público** (`Ditoo1/eclipsecobblemon-ios`): lo exige la LGPL, y además da Actions macOS gratis. Si aún no existe, **pide al dueño que lo cree o que inicie sesión** (`gh auth login`). No metas credenciales tú.
- **Testing visual: "vibeview".** El dueño lo usará para probar. **Pregúntale qué es y cómo conectarlo** antes de asumir nada.
- Al dueño le queda poco uso de IA: sé concreto, no repitas trabajo y confirma antes de cualquier acción pública (push, crear repo, releases).

## 4. Decisiones ya tomadas (no las cambies sin preguntar)

1. **Idioma de la interfaz: portugués de Portugal (pt-PT)**, no de Brasil. Usa ficheiros, controlos, definições, registo, "Terminar sessão", "A transferir…" (a + infinitivo) y trato formal sin "você".
2. **Versión fija: Minecraft 1.21.1.** Sin selector de versiones.
3. **Login: Microsoft u Offline.** La etiqueta de la cuenta dice "Microsoft" u "Offline", **nunca** "Premium".
4. **Sin sesión hay una pantalla de acceso exclusiva** (fondo del castillo, luna, "ECLIPSE COBBLEMON" y un panel fijo con login). Al cerrar sesión se vuelve a ella, nunca al menú de jugar.
5. **Navegación: solo Perfil y Definições.** Sin pestaña de servidores, noticias ni perfiles de instalación.
6. **No mostrar los controles en la interfaz.** Se instalan y se usan por debajo; no aparecen como ajuste visible.
7. **Renderer:** el que trae la librería por defecto. Se muestra como información, no como selector.
8. **Perfil:**
   - cabeza de la skin (recortada de la textura real, en pixel art sin suavizado) que **llena todo el recuadro**;
   - el avatar de arriba a la derecha es un cuadrado redondeado, también lleno con la cabeza;
   - pestañas **Conta | Skin**.
9. **Pestaña Skin (Microsoft):**
   - vista previa de frente y espalda con la capa;
   - modelo Clássico/Fino;
   - "Escolher imagem" (PNG de 64×64), "Aplicar skin", "Repor";
   - cuadrícula de capas.

   Usa la API oficial `api.minecraftservices.com/minecraft/profile/skins` y `/capes/active`; ver `referencia-android/auth/SkinApi.kt`. En **Offline** solo hay vista previa, con un aviso de que la skin se definirá en el servidor más adelante.
10. **Definições:**
    - versión (solo lectura);
    - memoria con un slider y el valor recomendado;
    - renderer (solo lectura);
    - "Verificar ficheiros";
    - registo;
    - "Apagar dados do Minecraft", con confirmación y el tamaño en MB.
11. **Dispositivos:** se puede instalar desde **iOS 14 en iPhone 6s o posterior** (igual que Amethyst). La app detecta la RAM y aplica un nivel automático:

| Nivel | RAM | Modelos | Memoria Java | Render | Aviso |
|---|---|---|---|---|---|
| Óptimo | 8 GB o más | 15 Pro, serie 16 y 17 | 3 GB | 8–10 chunks | no |
| Recomendado | 6 GB | 12 Pro, 13 Pro, 14, 15 | 2–2,5 GB | 6–8 | no |
| Mínimo | 4 GB | XS, 11, 12, 13, 13 mini, SE 3 | 1,5 GB | 4–5 | suave |
| No recomendado | 3 GB o menos | 6s–8, X, XR, SE 1 y 2 | 1 GB | 2–3 | fuerte, sin bloquear |

   Hacia fuera se comunica: "Recomendado: iPhone 12 Pro, 13 Pro, 14 o superior · Mínimo: iPhone XS". Son valores de partida que hay que validar en un dispositivo real.

## 5. Restricciones de iOS (explícaselas al dueño si pregunta)

- **No hay App Store**: Apple no permite JIT ni ejecutar código descargado. Se distribuye un IPA por **SideStore/AltStore** (con Apple ID gratis caduca a los 7 días) o **TrollStore** (solo algunas versiones de iOS).
- **JIT obligatorio** para que vaya fluido. En iOS 17 y 18 se necesita un computador para activarlo. **iOS 26: compatibilidad sin confirmar.**

## 6. Licencias (obligatorio)

- Amethyst-iOS es **LGPL-3.0**: conserva `LICENSE` y los créditos y mantén el repositorio **público** con todos los cambios.
- Añade en Definições una sección **"Licenças"** con los créditos de Amethyst-iOS/PojavLauncher (LGPL-3.0) y Lexend (OFL, ver `eclipse/diseno/Lexend-OFL.txt`).
- No uses marcas de Mojang/Microsoft en el icono.

## 7. Cómo trabajar

1. Lee `eclipse/tareas/README.md` y haz las fases **en orden**. Cada una tiene un criterio de "hecho".
2. **Commits pequeños** con mensajes en español. No hagas push sin que el dueño lo confirme la primera vez.
3. Después de cada cambio, compila en Actions y revisa los logs. Si algo falla, arréglalo antes de seguir.
4. Para la lógica, copia el comportamiento de `eclipse/referencia-android/`: `MainActivity.kt` (UI y textos pt-PT), `LauncherViewModel.kt` (estados, RAM recomendada, borrado de datos), `auth/` (Microsoft, offline, skins).
5. Antes de reescribir algo, mira si Amethyst-iOS ya lo hace y **reutilízalo** (login, descargas, JRE, lanzamiento del juego).
6. Si no estás seguro de una decisión de producto, **pregunta al dueño**; no inventes.
