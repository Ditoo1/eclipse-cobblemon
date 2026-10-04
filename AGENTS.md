# EclipseCobblemon (iOS + Android)

Monorepo: la app iOS (fork de Amethyst-iOS) está en la raíz y la app Android está en **`android/`**.
Las dos apps deben verse y comportarse igual: un cambio de interfaz o de textos se hace en ambas.

Antes de cualquier trabajo, lee **`INSTRUCCIONES_IA.md`** (contexto, decisiones y restricciones) y después **`eclipse/tareas/README.md`** (qué hacer, por fases). Para Android, `android/README.md`.

Reglas rápidas:
- iOS es un fork de Amethyst-iOS: cambia su marca y simplifícalo; no reescribas el runtime.
- La interfaz va en pt-PT, la versión es fija en 1.21.1 y la cuenta de GitHub es `Ditoo1`.
- Sin Mac: iOS se compila en GitHub Actions (`development.yml`); Android en `android.yml`.
- Confirma con el dueño antes de hacer push, crear repos o publicar releases.
