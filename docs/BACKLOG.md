# MasterBoard — Backlog / WBS

> **v2 (2026-07-28)** — reescrito tras el cambio de género de `GDD.md` v0.2. La Fase 0 se
> conserva casi entera. La Fase 1 se rehace: ya no hay run, ni mazo, ni intención
> telegrafiada. Lo que sobrevive del trabajo hecho está marcado como heredado.

Estimaciones asumiendo ~5h/día con asistencia de Claude Code. **Total MVP: ~150-205h ≈ 6-8 semanas.**

Una tarea está *hecha* cuando pasa sus criterios de aceptación y está commiteada, no cuando
"funciona en mi máquina".

---

## Fase 0 — Fundación (8-12h)

- [x] **0.1** Alinear `project.godot`: `config/features` a 4.7, orientación portrait (D-01/A-09)
- [x] **0.2** Crear estructura de carpetas de `ARCHITECTURE.md` A-06 con `.gitkeep`
- [x] **0.3** Añadir `CLAUDE.md`, `docs/GDD.md`, `docs/ARCHITECTURE.md`, este backlog
- [x] **0.4** Instalar GdUnit4 en `addons/`, verificar que corre en headless
  - gdUnit4 **6.1.3**, instalado a mano desde el release de GitHub (esta máquina no tiene
    salida de red desde la terminal, SSL error 35). Requiere `--ignoreHeadlessMode`; el
    comando correcto está en `CLAUDE.md`.
- [x] **0.5** Añadir `.mcp.json` y `.claude/settings.json` al repo (config que viaja entre PCs)
- [x] **0.6** GitHub Action: correr tests en cada push a `main`
  - `.github/workflows/tests.yml`. **Sin verificar**: esta máquina no tiene red, así que
    no se ha podido comprobar ni la URL de descarga de Godot ni que el job pase. La
    primera ejecución en GitHub es la prueba real.
- [x] **0.7** Verificar `.gitignore` cubre `.godot/`, `.import/`, `export_presets.cfg`, `builds/`
- [ ] **0.8** Importar el asset pack, verificar licencia (D-03), documentar atribución en `CREDITS.md`
  - Bloqueado: `assets/` solo tiene `.gitkeep`, el pack no está en el repo. Lo tienes que
    copiar tú.
  - Cambia de alcance con el pivote: ya no hacen falta sprites de *arquetipos enemigos*
    sino de **personajes jugables** (D-06 pide un mínimo de 3 para que exista lectura de
    matchup). El de clembod cubre uno.

**Criterio de fase:** clonas el repo en tu otra PC, abres Claude Code, y todo funciona sin
configuración manual.

---

## Fase 1 — Vertical slice: una partida 1v1 contra la IA (75-100h)

Objetivo: **una partida completa, jugable y que premie leer al rival.** Es la fase que decide
si el juego existe. El criterio de éxito no es "funciona": es el goal #3 del GDD — quien
conoce el kit del rival gana más que quien no. Si eso no pasa, el juego es azar disfrazado.

### 1A — Núcleo lógico, sin gráficos (30-40h)

- [x] **1.1** `CombatState`: tablero 5×5, unidades con posición/vida/equipo, RNG con semilla
  - Heredado. 9 tests en verde.
- [x] **1.2** `Command` base con `validate()` / `apply()`, `Event` como resultado, `Resolver`
  - Heredado. 9 tests en verde. Sobrevive entero al pivote (A-12).
- [x] **1.3** Adaptar `CombatState` al diseño nuevo
  - `turn` pasa a `round_number`: `round()` es función incorporada de GDScript y la
    sombra silenciaría llamadas legítimas.
- [x] **1.4** Capa de terreno (A-13): `FLOOR`, `WALL`, `VOID`, `HAZARD` por casilla
  - Fuera del tablero devuelve `WALL`, así ninguna consulta necesita caso especial
    para "me salí" y el tablero cerrado del GDD §4 sale gratis.
- [x] **1.5** Utilidades de coordenadas: adyacencia, distancia, línea, línea de visión
  - `Grid` es geometría pura; la línea de visión vive en `CombatState` porque depende
    del terreno. Solo hay líneas en las 8 direcciones: una línea Bresenham arbitraria
    no se puede prever mirando la pantalla, y una habilidad imprevisible está rota.
- [x] **1.6** `MoveCommand` + reglas de terreno
  - Entrar en `VOID` mata y libera la casilla; `WALL` bloquea destino y camino.
  - **`HAZARD` se movió a 1.9** (fase 4 de la ronda). Cobrarlo aquí lo duplicaría
    cuando un empujón mete a alguien en la lava: el daño de terreno tiene que
    aplicarse una sola vez, dé igual cómo llegaste a la casilla.
- [ ] **1.7** Empuje y colisión
  - Test: empujar contra un obstáculo detiene y hace 1 de daño; contra otra unidad daña a ambas
- [ ] **1.8** `Ability` como recurso componible: `Damage`, `Push`, `Pull`, `MoveSelf`, `Barrier`, `Shield`, `Mana`
  - Test: añadir una habilidad nueva no toca ningún `.gd` de lógica
- [ ] **1.9** **`Round`: selección simultánea + resolución por fases (A-12)** ← la pieza central
  - Recoge una elección de movimiento y una de habilidad por bando
  - Resuelve: barreras → movimiento → ataques → terreno
  - Test: mismas elecciones + misma semilla = mismo resultado
  - Test: los conflictos de movimiento de GDD §5 se resuelven según la tabla (rebote,
    intercambio bloqueado, persecución permitida)
- [ ] **1.10** Barreras con duración por carta, no global
  - Test: una barrera de 1 ronda desaparece al final de la ronda en que se puso
- [ ] **1.11** Escudos que absorben y caducan
- [ ] **1.12** Economía de maná: coste, acumulación, tope, quema del maná rival
- [ ] **1.13** Condiciones de fin: vida 0 = derrota; ambos a 0 la misma ronda = empate
- [ ] **1.14** Derrumbe del tablero desde la ronda 8 (GDD §4)
  - Test: una unidad atrapada por el derrumbe muere

**Criterio de fase 1A:** puedes jugar una partida entera desde un test, sin abrir el editor,
y el resultado es idéntico con la misma semilla y las mismas elecciones.

### 1B — IA que elige a ciegas (12-18h)

- [ ] **1.15** **Test de honestidad primero** (A-15): la decisión de la IA nunca recibe el
  comando del jugador. Se escribe **antes** que la IA, no después
- [ ] **1.16** Enumerar el espacio de acciones legales de una unidad dado su maná y kit
- [ ] **1.17** Evaluación por valor esperado: clonar el estado, simular las acciones posibles
  del jugador, elegir la respuesta con mejor resultado promedio
- [ ] **1.18** Función de evaluación del tablero: vida, maná, proximidad a peligro, casillas
  seguras disponibles
- [ ] **1.19** Niveles de dificultad como profundidad de simulación, no como stats inflados
  - La dificultad viene de que la IA lea mejor, no de que pegue más fuerte

### 1C — Capa visual (25-35h)

- [ ] **1.20** TileMap del tablero con los cuatro tipos de terreno + conversión lógica ↔ pixel
- [ ] **1.21** Escena de unidad: sprite del asset pack, idle/walk/attack/hurt/death
- [ ] **1.22** Puente `GameEvents`: suscribir la vista a los eventos del resolver
  - Es el único sitio donde lógica y nodos se tocan. Vive **fuera** de `logic/`
- [ ] **1.23** Cola de animación por fases: la resolución se reproduce en secuencia (R-08)
  - Es lo que compra la legibilidad que perdimos al no ir por equipos alternos (A-12)
- [ ] **1.24** **HUD de información pública** (R-04): vida y maná de ambos, siempre visibles
- [ ] **1.25** **Panel del kit rival**: sus habilidades, con las impagables atenuadas
  - Es el motor de deducción del juego (GDD §3). Si esto no se lee de un vistazo, el juego
    se convierte en adivinar
- [ ] **1.26** Previsualización de targeting: al elegir, resaltar casillas válidas y resultado
- [ ] **1.27** Indicador del orden de fases visible durante la resolución

### 1D — Input táctil y contenido (15-20h)

- [ ] **1.28** Selección de dos ranuras (movimiento + habilidad), cancelable antes de confirmar
- [ ] **1.29** Verificar todos los targets ≥ 48dp en pantalla real
- [ ] **1.30** Un personaje completo: 15 habilidades cubriendo las 5 familias de GDD §6
- [ ] **1.31** Pantalla de loadout: elegir 8 de 15 antes de la partida
- [ ] **1.32** Tres arenas simétricas hechas a mano: una cerrada, una con vacío, una con lava
- [ ] **1.33** **Playtest.** ¿5×5 se siente bien en duelo? ¿Los números de maná? (D-04, D-05)

**Criterio de fase 1:** le pasas el teléfono a alguien, juega dos partidas, y en la segunda
toma decisiones basadas en el maná del rival. Si no mira el maná, el HUD falló o el diseño falló.

---

## Fase 2 — Contenido y profundidad (35-45h)

- [ ] **2.1** Segundo y tercer personaje con identidad distinta (D-06)
- [ ] **2.2** Balance entre personajes: ningún matchup peor que ~40/60
- [ ] **2.3** Tres arenas más, incluyendo una con terreno asimétrico por rondas
- [ ] **2.4** Pantalla de selección de personaje con lectura de su kit
- [ ] **2.5** Repetición de la última ronda a petición (P1 del GDD)
- [ ] **2.6** Tutorial jugable: enseña el orden de fases sin texto
- [ ] **2.7** Persistencia de loadouts y preferencias

**Criterio de fase 2:** dos partidas con personajes distintos se sienten dos juegos distintos.

---

## Fase 3 — Juice (25-30h)

- [ ] **3.1** Menú principal + navegación entre pantallas
- [ ] **3.2** Feedback de impacto: hitstop, screen shake, partículas de empuje
- [ ] **3.3** Momento de revelación: las dos elecciones se muestran antes de resolverse
  - Es el instante con más carga dramática de la partida. Merece su propia animación
- [ ] **3.4** Aviso visual anticipado del derrumbe del tablero
- [ ] **3.5** Transiciones entre pantallas
- [ ] **3.6** SFX: elegir, revelar, impacto, empuje, barrera, muerte, victoria
- [ ] **3.7** Música placeholder de combate y menú
- [ ] **3.8** Personalización cosmética: paletas del personaje (shader de swap)

**Nota sobre el juice:** el 3.3 no es decoración. En un juego de lectura, el momento en que
descubres si acertaste es el producto.

---

## Fase 4 — Endurecimiento móvil (25-35h)

- [ ] **4.1** Export preset Android + firma, generar APK instalable
- [ ] **4.2** Probar en dispositivo real de gama media, medir fps
- [ ] **4.3** Adaptar layout a distintas relaciones de aspecto y notch
- [ ] **4.4** Manejo de suspensión: minimizar la app no rompe el estado
- [ ] **4.5** Optimización: atlas de sprites, reducir draw calls
- [ ] **4.6** Pantalla de carga y arranque en frío < 3s
- [ ] **4.7** Icono, splash, nombre de app, versionado
- [ ] **4.8** Build de release y prueba de instalación limpia

**Criterio de MVP terminado:** APK instalable, 60fps en gama media, partida completa sin crashes.

---

## Post-MVP (no planificar todavía)

En orden de valor esperado, a revisar **después** de tener feedback real de jugadores:

1. **Más personajes y arenas.** Lo más barato y lo que más rinde.
2. **PvP online.** Gracias a A-02/A-12 el trabajo es sincronizar dos elecciones por ronda, no
   reescribir el combate. Pero trae matchmaking, anti-cheat y problema de población: no se
   empieza hasta que el 1v1 contra IA demuestre que engancha.
3. **2v2**, con selección visible entre aliados. Sin esa visibilidad no hay coordinación,
   hay cuatro personas apostando a la vez.
4. **Draft/ban de personaje** antes de la partida. Añade una capa de estrategia previa muy
   barata de implementar una vez hay varios personajes.
5. **Replays y espectador.** Casi gratis: la lista de elecciones por ronda más la semilla
   reconstruye la partida entera.
6. **Modo puzzle single-player** con soluciones exactas, sobre el mismo motor.
