# MasterBoard — Backlog / WBS

Estimaciones asumiendo ~5h/día con asistencia de Claude Code, y que vas aprendiendo patrones
de Godot sobre la marcha. **Total MVP: ~175-230h ≈ 6-9 semanas.**

Una tarea está *hecha* cuando pasa sus criterios de aceptación y está commiteada, no cuando
"funciona en mi máquina".

---

## Fase 0 — Fundación (8-12h)

Objetivo: el repo queda listo para que cualquier sesión de trabajo empiece sin fricción.

- [x] **0.1** Alinear `project.godot`: `config/features` a 4.7, orientación portrait (D-01/A-09)
- [x] **0.2** Crear estructura de carpetas de `ARCHITECTURE.md` A-06 con `.gitkeep`
- [ ] **0.3** Añadir `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md`, este backlog
- [x] **0.4** Instalar GdUnit4 en `addons/`, verificar que corre en headless
  - gdUnit4 **6.1.3**, instalado a mano desde el release de GitHub (esta máquina no tiene
    salida de red desde la terminal, SSL error 35). Requiere `--ignoreHeadlessMode`; el
    comando correcto está en `CLAUDE.md`.
- [ ] **0.5** Añadir `.mcp.json` y `.claude/settings.json` al repo (config que viaja entre PCs)
- [ ] **0.6** GitHub Action: correr tests en cada push a `main`
- [x] **0.7** Verificar `.gitignore` cubre `.godot/`, `.import/`, `export_presets.cfg`, `builds/`
- [ ] **0.8** Importar el asset pack, verificar licencia (D-03), documentar atribución en `CREDITS.md`

**Criterio de fase:** clonas el repo en tu otra PC, abres Claude Code, y todo funciona sin
configuración manual.

---

## Fase 1 — Vertical slice de combate (60-80h)

Objetivo: **un encuentro completo, jugable y divertido.** Es la fase que decide si el juego existe.
Si al terminarla no te apetece rejugar el encuentro, para y rediseña antes de seguir.

### 1A — Núcleo lógico, sin gráficos (20-25h)

- [x] **1.1** `CombatState`: grilla 5×5, unidades con posición/vida/equipo, energía, turno, RNG con semilla
- [ ] **1.2** `Command` base con `validate()` / `apply()` y `Event` como resultado
- [ ] **1.3** Sistema de coordenadas y utilidades: adyacencia, distancia, línea, casilla ocupada
- [ ] **1.4** `MoveCommand` + regla de caída: mover fuera de grilla mata la unidad
  - Test: empujar unidad en el borde hacia afuera → muerta, casilla liberada
- [ ] **1.5** `Effect` como recurso componible: `Damage`, `Push`, `MoveSelf`, `Block`, `Draw`
- [ ] **1.6** `PlayCardCommand`: valida energía, valida targeting, aplica efectos en orden
- [ ] **1.7** Mazo: robar, descartar, remezclar descarte al agotarse (determinista con semilla)
- [ ] **1.8** `EndTurnCommand`: descarta mano, resuelve enemigos, restaura energía, roba
- [ ] **1.9** Condiciones de fin: sin enemigos = victoria, héroe muerto/caído = derrota

**Criterio de fase 1A:** puedes jugar un combate entero desde un test, sin abrir el editor,
y el resultado es idéntico con la misma semilla.

### 1B — IA enemiga (8-12h)

- [ ] **1.10** `EnemyIntent`: el enemigo decide su acción al inicio del turno del jugador y la guarda
- [ ] **1.11** Arquetipo *melee*: se acerca por el camino más corto y golpea si está adyacente
- [ ] **1.12** Arquetipo *empujador*: prioriza empujarte hacia un borde
  - Test: con el héroe a una casilla del borde, el empujador elige empujar, no golpear
- [ ] **1.13** Garantía de honestidad: lo ejecutado == lo telegrafiado (test explícito)

### 1C — Capa visual (20-28h)

- [ ] **1.14** TileMap de la arena + conversión coordenada lógica ↔ pixel
- [ ] **1.15** Escena de unidad: sprite del asset pack, idle/walk/attack/hurt/death
- [ ] **1.16** Suscripción a `GameEvents` → animaciones (mover, dañar, empujar, morir)
- [ ] **1.17** Cola de animación: los eventos se reproducen en secuencia, no todos a la vez
- [ ] **1.18** UI de mano de cartas, contador de energía, barra de vida
- [ ] **1.19** Visualización de intención enemiga (flecha/icono sobre el objetivo)
- [ ] **1.20** Preview de targeting: al seleccionar carta, resaltar casillas válidas y resultado

### 1D — Input táctil y contenido (12-15h)

- [ ] **1.21** Tap para seleccionar carta → tap en casilla para confirmar → cancelable
- [ ] **1.22** Verificar todos los targets ≥ 48dp en pantalla real
- [ ] **1.23** Crear las 10 cartas del mazo inicial como `.tres`
- [ ] **1.24** Crear 2 arquetipos enemigos + 1 encuentro de prueba como `.tres`
- [ ] **1.25** **Playtest.** ¿5×5 se siente bien? ¿3 de energía? ¿5 cartas? Ajustar números (D-04)

**Criterio de fase 1:** le pasas el teléfono a alguien sin explicarle nada y entiende qué hacer.

---

## Fase 2 — Loop de run (40-50h)

- [ ] **2.1** `RunState`: mazo persistente, vida arrastrada entre peleas, encuentro actual, semilla
- [ ] **2.2** Encadenar 5 encuentros con dificultad creciente
- [ ] **2.3** Pantalla de recompensa: elegir 1 de 3 cartas ofrecidas
- [ ] **2.4** Ampliar el pool a ~25 cartas para que la elección sea significativa
- [ ] **2.5** Tercer arquetipo enemigo (a distancia, para forzar movimiento)
- [ ] **2.6** Obstáculos y peligros en la arena (agujeros interiores, pinchos)
- [ ] **2.7** Pantalla de victoria / derrota de run con resumen
- [ ] **2.8** Guardado de run en progreso (cerrar la app y volver no pierde el avance)

**Criterio de fase 2:** una run completa se juega en 15-20 minutos y dos runs se sienten distintas.

---

## Fase 3 — Meta y juice (40-50h)

- [ ] **3.1** Menú principal + navegación entre pantallas
- [ ] **3.2** Pantalla de mazo: ver cartas, leer descripciones
- [ ] **3.3** Personalización cosmética: paletas de color del héroe (shader de swap)
- [ ] **3.4** Persistencia de preferencias y cosméticos desbloqueados
- [ ] **3.5** Feedback de impacto: hitstop, screen shake, partículas de empuje
- [ ] **3.6** Transiciones entre pantallas y entre encuentros
- [ ] **3.7** SFX: jugar carta, impacto, empuje, muerte, caída, victoria
- [ ] **3.8** Música placeholder de combate y menú
- [ ] **3.9** Deshacer último movimiento antes de confirmar fin de turno

**Nota sobre el juice:** el 3.5 es lo que separa un prototipo de un juego. No lo dejes fuera por
"no es funcionalidad" — un empuje sin screen shake se siente como mover una ficha de Excel.

---

## Fase 4 — Endurecimiento móvil (25-35h)

- [ ] **4.1** Export preset Android + firma, generar APK instalable
- [ ] **4.2** Probar en dispositivo real de gama media, medir fps
- [ ] **4.3** Adaptar layout a distintas relaciones de aspecto y notch
- [ ] **4.4** Manejo de suspensión: minimizar la app no rompe el estado
- [ ] **4.5** Optimización: atlas de sprites, reducir draw calls, revisar allocations por frame
- [ ] **4.6** Pantalla de carga y arranque en frío < 3s
- [ ] **4.7** Icono, splash, nombre de app, versionado
- [ ] **4.8** Build de release y prueba de instalación limpia

**Criterio de MVP terminado:** APK instalable, 60fps en gama media, run completa sin crashes.

---

## Post-MVP (no planificar todavía)

En orden de valor esperado, a revisar **después** de tener feedback real de jugadores:

1. **Contenido**: más cartas, más enemigos, más encuentros. Es lo más barato y lo que más rinde.
2. **Segundo personaje jugable** con mazo e identidad distinta.
3. **Progresión meta** entre runs (desbloqueos) — la puerta natural a la tienda.
4. **Modo historia** sobre la estructura de run ya existente.
5. **Multijugador online.** Último, y solo si el single player ya demostró que engancha.
   Gracias a A-02/A-03 el trabajo será sincronizar comandos, no reescribir el combate.
