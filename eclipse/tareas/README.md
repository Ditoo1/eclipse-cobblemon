# Tareas por fases

Hazlas en orden y marca cada casilla al terminar. No pases a la fase siguiente sin cumplir su criterio de "hecho".

## Fase 0: repositorio y CI
- [ ] Confirmar con el dueño que existe `Ditoo1/eclipsecobblemon-ios` (público) y que hay sesión de GitHub en el PC.
- [ ] Primer commit: añadir `INSTRUCCIONES_IA.md`, `CLAUDE.md` y `eclipse/`. El remoto `origin` apunta al repo de Ditoo1 y `upstream` sigue apuntando a Amethyst-iOS.
- [ ] Push (con confirmación del dueño) y comprobar que el workflow de `.github/workflows/development.yml` compila.
- [ ] Preguntar al dueño qué es **vibeview** y cómo se conecta para el testing visual.

**Hecho cuando:** Actions genera un IPA del Amethyst-iOS original sin errores.

## Fase 1: probar el original en un iPhone
- [ ] El dueño instala el IPA (SideStore/AltStore/TrollStore) y activa JIT.
- [ ] Abrir Minecraft 1.21.1 vanilla con una cuenta Microsoft.
- [ ] Anotar el modelo, la versión de iOS y el rendimiento.

**Hecho cuando:** 1.21.1 vanilla entra al mundo en el iPhone del dueño.

## Fase 2: marca Eclipse
- [ ] Bundle ID `dev.eclipsecobblemon.ios` y nombre visible "Eclipse Cobblemon".
- [ ] Icono: la luna creciente dorada sobre fondo `Night`. Ver `diseno/TOKENS.md`.
- [ ] Fuente Lexend (`diseno/lexend.ttf`) en toda la interfaz.
- [ ] Colores de `diseno/TOKENS.md`.
- [ ] Interfaz en pt-PT. Quitar los demás idiomas o dejar pt-PT por defecto.

**Hecho cuando:** la app instalada se ve como Eclipse y no como Amethyst; sus créditos solo quedan en "Licenças".

## Fase 3: interfaz simplificada (igual que en Android)

Ver `diseno/android_inicio.png`, `diseno/android_acceso.png` y `referencia-android/MainActivity.kt`.

- [ ] Pantalla de acceso exclusiva sin sesión (Microsoft + Offline con validación de nombre 3–16, `[A-Za-z0-9_]`).
- [ ] Inicio:
  - cabecera con la luna, "ECLIPSE COBBLEMON" y el avatar de la cabeza;
  - tarjeta con el fondo del castillo;
  - botón de jugar grande con anillo de progreso (versão → ficheiros → Java → iniciar);
  - estado debajo;
  - barra inferior **Perfil | Definições**.
- [ ] Versión fija 1.21.1. Ocultar el selector de versiones y los perfiles de instalación.
- [ ] Perfil con las pestañas Conta | Skin (ver `INSTRUCCIONES_IA.md` §4.8–4.9 y `referencia-android/auth/SkinApi.kt`).
- [ ] Definições: memoria, renderer (solo lectura), verificar ficheiros, registo, apagar dados (con confirmación) y Licenças.
- [ ] Nivel automático por RAM (tabla en `INSTRUCCIONES_IA.md` §4.11), con avisos.
- [ ] Ocultar en la interfaz los controles, las noticias, el gestor de JRE y el gestor de archivos (pueden quedar accesibles desde el registo para depurar).

**Hecho cuando:** un jugador nuevo puede entrar, jugar, cambiarse la skin y cerrar sesión sin ver nada de Amethyst.

## Fase 4: contenido del servidor
- [ ] Instalar Fabric Loader para 1.21.1 y el modpack del servidor. Preguntar al dueño la lista exacta de mods y versiones, y la dirección del servidor.
- [ ] Usar por defecto `controles/Controles_Eclipse.json` (verificar que el formato es compatible con Amethyst-iOS).
- [ ] Opcional, a confirmar con el dueño: entrar directo al servidor al jugar.

**Hecho cuando:** "Jogar" abre 1.21.1 con Fabric y Cobblemon y los controles de Eclipse.

## Fase 5: distribución
- [ ] Workflow de release que publique el IPA en GitHub Releases.
- [ ] "Source" de SideStore/AltStore (JSON) para actualizaciones desde la app.
- [ ] README público con instalación paso a paso en pt-PT y los requisitos de dispositivo.

**Hecho cuando:** un jugador puede instalar y actualizar siguiendo solo el README.
