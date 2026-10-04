# Sincronización del pack

El `.minecraft` de los jugadores es un espejo del pack que publica el owner en el Worker ([`cloudflare/`](../cloudflare/README.md)). Las dos apps siguen exactamente las mismas reglas:

- Android: `android/app/src/main/java/dev/eclipsecobblemon/launcher/game/PackSync.kt` + `Fabric.kt`
- iOS: `Natives/eclipse/ECPackSync.m`

## Manifiesto (formato 1)

`GET /v1/manifest`:

```json
{
  "format": 1,
  "revision": 7,
  "minecraft": "1.21.1",
  "loader": { "type": "fabric", "version": "0.16.5" },
  "objects": "objects/",
  "exclusive": ["mods"],
  "files": [
    { "path": "mods/cobblemon.jar", "sha1": "…", "size": 52428800 },
    { "path": "config/sodium-options.json", "sha1": "…", "size": 312, "mode": "once" },
    { "path": "mods/solo-android.jar", "sha1": "…", "size": 1024, "platforms": ["android"] }
  ]
}
```

| Campo | Significado |
|---|---|
| `minecraft` | Debe ser `1.21.1`. Si no, la app pide actualizarse y no lanza el juego. |
| `loader` | Opcional. Solo `fabric`. Sin él, se lanza vanilla. |
| `objects` | Base de los archivos, relativa a la URL del manifiesto. El archivo con hash `h` está en `objects/<h[0:2]>/<h>`. |
| `exclusive` | Carpetas donde se borra todo lo que no esté en `files` (por defecto `["mods"]`). |
| `files[].mode` | `sync` (por defecto): siempre igual que el servidor. `once`: solo se instala si falta. |
| `files[].platforms` | Opcional: `android` y/o `ios`. Sin él, el archivo va a ambas. |

Los campos desconocidos se ignoran (por ejemplo `publishedAt`).

### Rutas

- Siempre relativas, separadas por `/`.
- No se aceptan:
  - rutas absolutas;
  - rutas con `\`, `:`, `.` o `..`;
  - segmentos vacíos;
  - dos rutas iguales salvo mayúsculas.
- Ni el panel ni las apps aceptan estas raíces protegidas:

  `.eclipse`, `saves`, `screenshots`, `logs`, `crash-reports`, `versions`, `libraries`, `assets`, `accounts`, `controlmap`, `options.txt`, `launcher_profiles.json`, `launcher_preferences.plist`.

Si el manifiesto trae una ruta no válida, se rechaza entero.

## Estado local

Todo vive en `.minecraft/.eclipse/`:

- `pack-state.json`: `{revision, etag, files: {path: {sha1, size, mtime, mode}}}`. Guarda lo que la app instaló.
- `pack-manifest.json`: el último manifiesto válido. Se usa cuando el servidor responde 304.
- `staging/<sha1>`: descargas en curso. Se reaprovechan si se cortó la conexión.

## Algoritmo

1. **Manifiesto**:
   - `GET` con `If-None-Match: <etag>`;
   - si responde 304, se usa el manifiesto guardado;
   - si hay error de red o no es 200/304, **no se juega**: «Sem ligação ao servidor do pack. É preciso internet para jogar.»
2. **Plan**, para cada archivo de esta plataforma:
   - Si existe y su tamaño y fecha coinciden con `pack-state.json`, está al día sin leerlo. Con *verify* («Verificar ficheiros») se relee siempre su SHA-1.
   - Si no, se calcula el SHA-1. Si es igual, está al día; si es distinto o falta, hay que descargarlo.
   - Si es `once` y ya existe, es del jugador y no se toca.
3. **Borrados**:
   - Lo que estaba en el estado anterior y ya no está en el manifiesto se borra. Un `once` solo se borra si el jugador no lo cambió.
   - En las carpetas `exclusive` se borra todo archivo que el pack no pida.
4. **Descarga**:
   - Cada hash se baja una sola vez, aunque lo usen varias rutas.
   - 6 descargas en paralelo y 3 reintentos.
   - Se comprueban el tamaño y el SHA-1.
5. **Commit**, solo si **todas** las descargas fueron bien:
   - se mueven los archivos a su sitio;
   - se borran los sobrantes;
   - se escribe `pack-state.json` de forma atómica.

   Si algo falla antes, el `.minecraft` queda como estaba.

`options.txt`, los mundos y las capturas nunca se tocan.

## Fabric

- Si el pack trae `loader`, la app baja el perfil de `https://meta.fabricmc.net/v2/versions/loader/1.21.1/<versión>/profile/json` a `versions/fabric-loader-<versión>-1.21.1/`.
- Comprueba que `inheritsFrom` sea `1.21.1` e instala sus librerías.
- El runtime de Amethyst combina el perfil con la versión vanilla al lanzar.

## Orden al pulsar «Jogar»

`Versão` → `Ficheiros` (vanilla) → `Mods` (Fabric + sync) → `Java` → `Iniciar`.

Sin URL de pack (`packUrl` / `ECPackURL` vacíos), la etapa `Mods` no aparece.

## Pruebas

`android/app/src/test/java/dev/eclipsecobblemon/launcher/PackSyncTest.kt` (13 casos) cubre:

- primera instalación y segunda sin descargas;
- actualizar, borrar y reparar;
- *verify*, archivos `once` y sin internet;
- descarga corrupta (no se toca nada) y hashes compartidos;
- filtro de plataforma;
- rutas protegidas y `saves` dentro de una carpeta exclusiva;
- id de Fabric.

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*PackSyncTest*'
```
