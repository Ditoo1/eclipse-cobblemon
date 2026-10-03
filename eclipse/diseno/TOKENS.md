# Diseño Eclipse: tokens (copiados de la app Android)

Estilo sobrio, oscuro y dorado. Fondo nocturno, acentos dorados y texto marfil.

## Colores

| Token | Hex | Uso |
|---|---|---|
| Gold | `#F5C542` | Acento principal: botón de jugar, títulos, selección |
| GoldHi | `#F8D46A` | Brillo del dorado |
| GoldLo | `#E5B33A` | Dorado apagado, avisos |
| Night | `#07070A` | Fondo de la app |
| Surface | `#0F0E13` | Tarjetas, barra inferior, campos |
| SheetBg | `#111015` | Paneles inferiores (sheets) |
| Ivory | `#F3EEDF` | Texto principal |
| Muted | `#A39C88` | Texto secundario |
| Dim | `#6E6858` | Texto terciario, desactivado |
| Hair | Ivory al 10 % | Bordes de 1 px |
| Online | `#7BD88F` | Éxito |
| Danger | `#E07A6B` | Acciones destructivas ("Apagar dados") |

## Tipografía
- **Lexend** (`lexend.ttf`, fuente variable, licencia OFL).
- Marca "ECLIPSE COBBLEMON": 16 pt, SemiBold, color Gold, tracking 0.16 em, en mayúsculas.
- Títulos de panel: 22 pt, SemiBold, Ivory. Cuerpo: 13–15 pt.

## Formas
- Tarjeta principal: radio 26. Botones: radio 16, altura 50–54. Paneles: radio 28 arriba.
- Botón de jugar: círculo dorado de 112 pt con triángulo oscuro, montado sobre el borde inferior de la tarjeta del castillo.
- Bordes de 1 px en Hair. La tarjeta del castillo lleva un borde Gold al 32 %.

## Imágenes
- `fondo_eclipse.webp`: castillo nocturno. Se usa en la tarjeta de inicio y a pantalla completa en la pantalla de acceso, con un degradado hacia Night.
- Luna creciente: un disco Gold tapado por otro disco del color del fondo, desplazado. Se dibuja por código.
- Cabezas y skins: pixel art **sin suavizado** (nearest neighbor).

## Referencias visuales
- `android_inicio.png`: inicio con sesión.
- `android_acceso.png`: pantalla de acceso sin sesión.
