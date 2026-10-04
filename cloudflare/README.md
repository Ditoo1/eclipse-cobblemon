# Worker del pack (Cloudflare R2 + Workers)

Este Worker es el espejo del `.minecraft` del servidor.

- El owner sube mods, resource packs y configs desde el panel `/admin` y publica una revisión.
- Las apps (Android e iOS) descargan solo lo que cambió y borran lo que ya no está.
- Sin conexión, no se puede jugar.

Formato y reglas: [`docs/pack-sync.md`](../docs/pack-sync.md).

Solo usa Cloudflare, y cabe en el plan gratuito:

| Límite | Plan gratuito |
|---|---|
| R2 | 10 GB, descargas sin coste de salida |
| Workers | 100 000 peticiones/día |
| Subida por archivo | 100 MB |

## 1. Probar en local (sin cuenta)

```bash
cd cloudflare
npm install
cp .dev.vars.example .dev.vars   # edita la contraseña
npm run dev
```

- Panel: <http://localhost:8787/admin>.
- Manifiesto: <http://localhost:8787/v1/manifest>.

R2 se simula en disco, en `.wrangler/`.

Android bloquea `http://`, así que en el móvil prueba con el Worker ya desplegado (paso 2).

## 2. Desplegar en Cloudflare

1. Crea una cuenta gratuita en <https://dash.cloudflare.com>.
2. Activa R2 en el dashboard (R2 → *Get started*). Pide una tarjeta, pero el plan gratuito no cobra nada.
3. Desde `cloudflare/`, ejecuta:

   ```bash
   npx wrangler login
   npx wrangler r2 bucket create eclipse-pack
   npx wrangler secret put ADMIN_PASSWORD
   npx wrangler deploy
   ```

   - `wrangler login` abre el navegador para autorizar.
   - `wrangler secret put` te pide la contraseña del panel. No la guardes en ningún archivo.
4. `deploy` imprime la URL: `https://eclipse-pack.<tu-subdominio>.workers.dev`.
5. Abre `https://eclipse-pack.<tu-subdominio>.workers.dev/admin` y entra con la contraseña.
6. Elige **Fabric Loader** y sube las carpetas `mods`, `config`… de tu `.minecraft`. Después pulsa **Publicar**.

   Para cambiar la contraseña, vuelve a ejecutar `npx wrangler secret put ADMIN_PASSWORD`.

## 3. Conectar las apps

La URL que necesitan las apps es la del manifiesto:

```
https://eclipse-pack.<tu-subdominio>.workers.dev/v1/manifest
```

- **Android**: pon `packUrl=<URL>` en `android/gradle.properties`, o compila con `-PpackUrl=<URL>`.
- **iOS**: pon la URL en la clave `ECPackURL` de `Natives/Info.plist`.

Si la URL está vacía, la app lanza Minecraft vanilla sin pack.

Al pulsar «Jogar», cada app hace esto:

1. Baja el manifiesto. Sin internet, se para con un error.
2. Instala el perfil de Fabric que pide el pack.
3. Sincroniza los archivos. La etapa **Mods** muestra los MB.
4. Lanza `fabric-loader-<versión>-1.21.1`.

«Verificar ficheiros» además relee el SHA-1 de todo y repara lo que el jugador haya tocado.

## Panel

- **Carpetas exclusivas** (por defecto `mods`): las apps borran ahí todo lo que no esté en el pack.
- **Modo**:
  - `sync`: siempre igual que el servidor;
  - `once`: se instala si falta y después lo controla el jugador, útil para configs de cliente.
- **Plataformas**: un archivo puede ir solo a Android o solo a iOS.
- **Archivos protegidos**: `saves`, `options.txt`, `screenshots`, `logs`, las cuentas y lo que instala el launcher (`versions`, `libraries`, `assets`) no se pueden subir. Las apps nunca los tocan.
- **Borrador → Publicar**: los cambios no llegan a nadie hasta que publicas. Cada publicación es una revisión nueva.
- **Historial → Volver a esta**: vuelve a publicar una revisión anterior. Las apps la reciben como una actualización más.
- **Limpiar archivos sin uso**: borra de R2 lo que no usan ni el borrador ni las últimas 10 revisiones.

## API

| Método | Ruta | Uso |
|---|---|---|
| GET | `/v1/manifest` | Manifiesto publicado (ETag; 304 si no cambió) |
| GET | `/v1/objects/<aa>/<sha1>` | Archivo por SHA-1 (caché inmutable) |
| GET | `/admin` | Panel |
| GET | `/v1/admin/state` | Borrador, manifiesto e historial |
| PUT | `/v1/admin/objects/<sha1>` | Subir un archivo (R2 rechaza la subida si el SHA-1 no coincide) |
| PUT | `/v1/admin/draft` | Guardar el borrador |
| POST | `/v1/admin/publish` | Publicar |
| POST | `/v1/admin/rollback` | `{"revision": n}` |
| GET | `/v1/admin/fabric-loaders` | Versiones de Fabric para 1.21.1 |
| POST | `/v1/admin/gc` | Limpiar objetos sin uso |

Las rutas `/v1/admin/*` piden `Authorization: Bearer <ADMIN_PASSWORD>`.
