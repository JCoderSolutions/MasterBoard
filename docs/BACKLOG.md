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
  - gdUnit4 **6.1.3**, instalado a mano desde el release de GitHub. Requiere
    `--ignoreHeadlessMode`; el comando correcto está en `CLAUDE.md`.
- [x] **0.5** Añadir `.mcp.json` y `.claude/settings.json` al repo (config que viaja entre PCs)
- [x] **0.6** GitHub Action: correr tests en cada push a `main`
  - `.github/workflows/tests.yml`. **Verificado en GitHub**: el primer run pasó en verde
    (81 tests, commit `b3bbbaa`). Descarga de Godot, caché, `--import` y el CLI de
    gdUnit4 funcionan tal cual estaban escritos.
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
- [x] **1.7** Empuje y colisión
  - `Displacement.push()` no es un `Command`: el empuje nunca lo elige el jugador, es
    consecuencia de una habilidad, y `validate()` no tendría nada que validar. Toma una
    **dirección** en vez de un destino, así que el efecto `Pull` de 1.8 es la misma
    llamada con la dirección invertida — sale gratis.
  - El que bloquea recibe el daño pero **no se desplaza**: encadenar empujes haría
    imposible previsualizar la jugada antes de confirmarla (R-07).
  - Empujar a quien ya está pegado al muro duele igual. Acorralar tiene que ser una
    posición perdedora, no un empuje desperdiciado.
  - `Damage.apply()` queda como único punto de paso del daño. Los escudos (1.11) se
    interceptan ahí, en un sitio, no en los cuatro que lo necesitan.
- [x] **1.8** `Ability` como recurso componible
  - Efectos implementados: `Damage`, `Push`, `Pull`, `MoveSelf`. **`Barrier`, `Shield` y
    `Mana` se quedan para 1.10, 1.11 y 1.12**, que es donde nace el estado del que
    dependen (duración, absorción, economía). Un efecto no puede escribirse antes que
    el estado que modifica.
  - `Ability.apply()` comprueba el maná pero **no lo cobra**: se paga al comprometer la
    elección, no al resolverla (1.9). Si cobrara aquí, esquivar devolvería el maná del
    golpe fallado y desaparecería el castigo por leer mal.
  - `CardDatabase` **eliminado**, no renombrado: era un `Node` que `logic/` no puede
    tocar y que solo envolvía un `load()` ya cacheado. Las habilidades llegan dentro del
    personaje. Ver A-04.
  - Targeting tiene un modo `REACHABLE_TILE` que pregunta a `MoveCommand.validate()` en
    vez de reimplementar "alineada, libre y despejada". Sin él la previsualización
    ofrecería casillas que el movimiento rechaza.
  - 5 habilidades en `resources/abilities/` generadas con el motor. `embestida` es la
    prueba de la composición: `[Daño(1), Empuje(2)]` pega el doble contra el borde
    porque se suma el impacto, y eso no está programado en ningún sitio.
- [x] **1.9** **`Round`: selección simultánea + resolución por fases (A-12)**
  - **Los ataques son simultáneos: morir en la fase de ataques no cancela tu golpe.**
    Sin eso, el orden interno de la fase decidiría partidas —justo lo que A-12 quiso
    evitar— y el empate por doble muerte del GDD §4 sería imposible. Morir *antes*
    (una caída al vacío al moverse) sí te deja fuera: las fases están ordenadas.
  - Los conflictos de movimiento salen de **una sola idea**: un movimiento se ejecuta
    en cuanto es posible, y lo que nunca llega a serlo se cancela. El intercambio es
    un ciclo y se queda fuera solo; la persecución no lo es y funciona sola. Solo el
    "mismo destino" necesita comprobación aparte.
  - `Ability` gana `phase`, que determina además en qué ranura se elige. Se separa
    `resolve()` de `apply()`: la ronda ya validó al cobrar y no puede revalidar,
    porque un golpe cuyo objetivo se movió **tiene** que dar al aire.
  - Nuevo evento `PhaseStarted`, siempre los cuatro. Lo necesitan la cola de animación
    (1.23) y el indicador de fase (1.27) para no adivinar qué fase se saltó.
  - `paso.tres`: el movimiento básico gratis y ortogonal del GDD §4, como habilidad de
    coste 0. `Ability.orthogonal_only` existe solo por él.
  - **Pendiente para 1.10:** GDD §5 dice que un movimiento bloqueado por una barrera
    "se detiene contra ella"; hoy se cancela entero, porque `MoveCommand` no hace
    movimiento parcial. Se resuelve cuando existan las barreras.
- [x] **1.10** Barreras con duración por carta, no global
  - Viven en un diccionario aparte del terreno, no pintadas encima: el terreno es dato
    de la arena (A-13) y una barrera es temporal. Mezclarlos obligaría a recordar qué
    había debajo para restaurarlo al caducar.
  - `terrain_at()` devuelve `WALL` donde hay barrera, así que bloquear movimiento,
    empuje y línea de tiro sale gratis: ninguna de esas tres reglas sabe que existen.
  - **Cierra el pendiente de 1.9**: `MoveCommand.apply()` ahora avanza lo que puede en
    vez de cancelar. `validate()` responde "¿puedo elegir esto?" y `apply()` "¿qué pasa
    de verdad?", y tienen que poder diferir porque entre elegir y resolver se levantan
    barreras.
  - La fase de ataques comprueba **una** cosa de nuevo: que el disparo llegue. Que el
    rival se moviera no cancela el golpe (eso es esquivar), pero una barrera en la
    trayectoria sí lo tapa — es lo que se pagó al levantarla.
  - Las barreras no se pueden poner sobre `VOID`: son un muro, no un puente. Taparlo
    dejaría que una carta de coste 1 anulara el peligro más letal de la arena.
  - `muro` (coste 1, 1 ronda) y `bastion` (coste 3, 2 rondas) en `resources/abilities/`.
- [x] **1.11** Escudos que absorben y caducan
  - Se intercepta en `Damage.apply()`, el único punto de paso del daño desde 1.7: la
    absorción funciona igual contra un ataque directo, el impacto de un empujón o la
    lava, sin que ninguno de los tres sepa que existen los escudos.
  - Un escudo nuevo **sustituye** al anterior, no se acumula. Apilar habría sido la
    estrategia de acumulación sin resolución que el GDD ya descartó para la curación.
  - Van en fase `BARRIER` junto con los muros: son el mismo tipo de jugada, un
    compromiso defensivo antes de que nadie se mueva, y protegen ya contra los ataques
    de la ronda en que se ponen.
  - Caducan al final de la ronda, en el mismo reloj que las barreras. Un escudo que se
    agota por absorción caduca aunque le quedaran rondas: a cero no es un escudo.
  - `coraza` (coste 2, 4 de absorción, 2 rondas) en `resources/abilities/`.
- [x] **1.12** Economía de maná: coste, acumulación, tope, quema del maná rival
  - Coste, acumulación y tope ya existían desde 1.1/1.3/1.9. Lo que faltaba era la
    familia **Maná** del GDD §6 como habilidad jugable.
  - `ManaEffect` es uno solo, con `amount` con signo: positivo restaura, negativo
    quema. Igual que `DamageEffect`, no distingue amigo de enemigo — quién es el
    objetivo lo decide el `targeting` del `.tres` (`SELF` para restaurar, `UNIT` para
    quemar), no el efecto.
  - `disipar` (quemar) va en fase `ATTACK` con línea de tiro, exactamente como
    `disparo`: se esquiva moviéndose fuera de rango y se tapa con una barrera de la
    fase 1. No es una regla nueva, es la misma que ya existía para el daño a distancia.
  - `meditar` (restaurar, coste 1, +3) y `disipar` (quemar, coste 2, -3, alcance 2) en
    `resources/abilities/`.
- [x] **1.13** Condiciones de fin: vida 0 = derrota; ambos a 0 la misma ronda = empate
  - `MatchResult.evaluate()` es consulta pura, no vive dentro de `Round`: el propio
    comentario de `Round.resolve()` ya pedía un hueco entre resolver la ronda y
    repartir el maná de la siguiente para comprobar si alguien murió, y ese hueco es
    de quien orqueste las rondas (el bucle de partida, fase posterior), no del
    resolver. Mismo patrón que `Grid`/`Terrain`: preguntas, no reglas que mutan.
  - El test que demuestra que 1.9 ya lo dejó listo: dos `tajo` simultáneos que se
    matan entre sí producen `DRAW`, no un ganador por accidente de orden.
- [x] **1.14** Derrumbe del tablero desde la ronda 8 (GDD §4)
  - `BoardCollapse` tampoco vive dentro de `Round`: reacciona al **número de ronda**,
    no a las elecciones de los bandos, y mezclar las tres cosas obligaría a leer las
    otras dos para entender esta. Mismo patrón que `MatchResult` — quien orqueste las
    rondas la llama junto a `begin_round()`.
  - Un anillo por ronda desde la 8, de fuera hacia dentro. **El anillo más interior
    nunca se derrumba**: un tablero es al menos esa casilla o deja de ser un tablero
    de ajedrez y pasa a ser un cronómetro que mata a los dos.
  - Idempotente a propósito: una casilla ya `VOID` no vuelve a contarse, así que
    llamarlo más de una vez en la misma ronda no repite el evento ni mata dos veces.
  - Los números exactos (ronda 8, un anillo por ronda) son una asunción de diseño, no
    algo que diga el GDD literalmente más allá de "desde la ronda 8, por capas".
    Pendiente de playtest, como el resto de números de combate (D-04, D-05).

**Criterio de fase 1A — cumplido.** Se puede jugar una partida entera desde un test, sin
abrir el editor, y el resultado es idéntico con la misma semilla y las mismas elecciones
(`round_test.gd::test_mismas_elecciones_mismo_resultado`). **Fase 1A cerrada.**

### 1B — IA que elige a ciegas (12-18h)

- [x] **1.15** **Test de honestidad primero** (A-15): la decisión de la IA nunca recibe el
  comando del jugador. Se escribe **antes** que la IA, no después
  - `Ai.decide(state, unit_id)` existe ya, pero su cuerpo es un placeholder deliberado
    ("no hacer nada"): la firma es lo que se protege en 1.15, la evaluación real la
    construyen 1.16-1.19 **encima** de esta misma firma, sin tocarla.
  - La garantía se congela con **reflexión**, no con disciplina: un test comprueba que
    `decide()` tiene exactamente 2 argumentos y que ninguno es de tipo `RoundChoice`,
    y otro comprueba que `CombatState` tampoco guarda un `RoundChoice` en un campo
    propio — la puerta de atrás por la que se filtraría igual sin cambiar la firma.
  - Sin esto, un cambio futuro que le pasara la elección del jugador "ya que la
    tenemos ahí" compilaría sin avisar. Con esto, rompe un test con nombre explícito.
- [x] **1.16** Enumerar el espacio de acciones legales de una unidad dado su maná y kit
  - `ActionSpace` vive en `ai/`, no en `logic/` (A-06): el jugador humano no necesita el
    producto cartesiano de sus opciones, elige habilidad y objetivo directamente en la
    UI apoyándose en `Ability.valid_targets()`. Esto es infraestructura de decisión que
    solo la IA recorre — 1.17 la usa para simular.
  - Una jugada es un `RoundChoice` **completo** (ranura de movimiento × ranura de
    acción), no pares (habilidad, objetivo) sueltos: el maná se paga de un único pozo
    para las dos ranuras (`Round._charge()`), así que la condición real es
    `coste_movimiento + coste_acción <= maná`, no cada coste por separado. Una
    combinación que junte no cabe no se enumera nunca.
  - Siempre incluye "quedarse quieto en las dos ranuras": una unidad viva nunca se
    queda sin jugadas, aunque sea sin maná.
  - Objetivo válido: `UNIT` no distingue amigo de enemigo (ya lo documentaba
    `DamageEffect` desde 1.8), así que una habilidad de golpe siempre puede apuntarse a
    uno mismo. No es un bug de la enumeración, es la regla ya existente.
- [x] **1.17** Evaluación por valor esperado: clonar el estado, simular las acciones posibles
  del jugador, elegir la respuesta con mejor resultado promedio
  - **Es promedio, no minimax**, a propósito: un rival que también decide a ciegas no
    puede jugar "y si hace lo peor para mí en concreto", porque tampoco sabe qué
    elegiste tú. Minimax asumiría un rival que ya conoce tu jugada — la ventaja
    injusta que A-15 existe para prohibir.
  - `Ai.decide()` sigue con la firma congelada en 1.15 (`state, unit_id`, nada más).
    Necesitaba leer el kit de las dos unidades sin romperla, así que el kit pasó a
    vivir en `Unit` (`var kit: Array[Ability]`): es tan público como la vida o el maná
    (GDD §3/R-04), no la elección oculta que A-15 protege.
  - `RoundChoice.clone()` nuevo: `Round.resolve()` anula la ranura que no se pudo
    pagar, así que reutilizar la misma instancia contra distintos clones filtraría el
    resultado de una simulación en la siguiente.
  - `BoardEvaluation.score()` es un **placeholder deliberado**: ganar/perder/empatar ya
    son definitivos (se apoya en `MatchResult`, 1.13), pero en una ronda no decisiva
    solo usa diferencia de vida. 1.18 amplía esa rama sin tocar el resto.
  - `Unit.opposing_team()` nuevo: el único bando enemigo de un equipo es un hecho sobre
    el enum, no una regla de combate.
- [x] **1.18** Función de evaluación del tablero: vida, maná, proximidad a peligro, casillas
  seguras disponibles
  - Amplía `BoardEvaluation` **dentro** de la rama "sigue la partida" que 1.17 dejó
    marcada, sin tocar la firma ni la rama de ganar/perder/empatar (`MatchResult`).
  - Cada señal del bando contrario se **agrega una vez** (suma total de vida, de
    maná, etc.) y se compara contra la propia una sola vez — no por cada rival por
    separado. Fuera del alcance del MVP 1v1, pero sumar por rival habría duplicado el
    propio valor en cuanto hubiera más de un rival enfrente (post-MVP, 2v2); un test
    fija justo esa diferencia entre las dos fórmulas.
  - Peligro: 1 punto por estar parado sobre `HAZARD` (volverá a doler la ronda que
    viene si nadie se mueve) + 0.25 por cada vecino `VOID`/`HAZARD` (el rival podría
    empujar hacia ahí). Una unidad viva nunca está sobre `VOID`: entrar ahí mata en el
    acto, así que ese caso no hace falta comprobarlo.
  - Escape: cuántas de las 8 casillas alrededor son transitables, libres y sin
    peligro. Pocas casillas seguras es estar acorralado, aunque nadie te haya tocado
    todavía — y por eso un muro vecino penaliza igual que uno letal, sin que eso
    cuente además como "peligro" (`WALL` no es letal).
  - Los pesos relativos (`MANA_WEIGHT`, `HAZARD_WEIGHT`, `SAFE_TILES_WEIGHT`) son una
    asunción de diseño, pendiente de playtest, igual que los números de maná y vida
    (D-04, D-05). La vida pesa 1 porque es la moneda real de la partida; el resto solo
    importa porque acaba convirtiéndose en vida más adelante.
- [x] **1.19** Niveles de dificultad como profundidad de simulación, no como stats inflados
  - `Unit.search_depth` (por defecto 1) es el único dial. Está documentado como
    contrato: si algún día "difícil" empieza a significar más vida o más daño, A-15
    se rompe por otra puerta — ya no haría falta leer bien si al bicho le sobra vida.
  - `ExpectedValueSearch` pasó de recibir listas de jugadas ya calculadas a recibir
    los kits directamente: a partir de profundidad 2 las jugadas de la ronda
    siguiente no existen todavía, dependen de un estado que solo aparece después de
    resolver la anterior. `Ai.decide()` no lo nota — sigue con la firma de 1.15.
  - **Entre una ronda simulada y la siguiente se llama a `begin_round()` de verdad**,
    con su reparto de maná. Sin esto, mirar más hondo penalizaría sistemáticamente
    ahorrar maná esta ronda para algo grande la próxima — justo la lectura que el
    GDD quiere premiar (§4: "lleva tres rondas sin gastar, tiene algo grande listo").
  - Sigue siendo promedio en cada nivel de la profundidad, no solo en el primero: el
    rival decide a ciegas tanto dos rondas por delante como en la que se está jugando.
  - Coste real, no solo teórico: profundidad 1 con un kit de 2 jugadas por bando
    evalúa 4 hojas; profundidad 2 vuelve a abrir el árbol en cada una de esas 4, así
    que evalúa 16. Es el techo de rendimiento que limita cuánto puede crecer este
    dial en un teléfono de gama media (A-07).

**Criterio de fase 1B — cumplido.** La IA elige sin recibir nunca la elección del
jugador (test de reflexión, 1.15), lee el espacio de jugadas legales de las dos unidades
(1.16), evalúa por valor esperado sobre vida/maná/peligro/escape (1.17-1.18), y la
dificultad es cuánto profundiza, no cuánto pega (1.19). **Fase 1B cerrada.**

### 1C — Capa visual (25-35h)

- [x] **1.20** TileMap del tablero con los cuatro tipos de terreno + conversión lógica ↔ pixel
  - **Primera tarea que abre el editor de verdad.** `src/combat/view/` empieza a
    poblarse: `BoardView` (`TileMapLayer`) y `BoardCoordinates` (conversión pura,
    sin nodo, testeable igual que `Grid`).
  - `board_tileset.tres` es **arte de relleno a propósito**: cuatro cuadrados de
    color con la textura incrustada en el propio recurso, porque un `.png` recién
    escrito en `res://` no tiene `.import` todavía dentro de la misma ejecución del
    script que lo generó. 0.8 sigue bloqueada; cuando el pack llegue, se sustituye
    solo la textura del `TileSet` — ni `BoardView` ni el orden de los tiles cambian.
  - El orden de los tiles del atlas coincide con `Terrain.Type` (FLOOR=0, WALL=1,
    VOID=2, HAZARD=3) a propósito: pintar un terreno es usar el valor del enum como
    columna del atlas, sin una tabla de traducción aparte que se pueda desincronizar.
  - `BoardCoordinates.CELL_SIZE` tiene que coincidir a mano con el `tile_size` del
    `.tres`, porque un recurso no puede leer una constante de GDScript. Documentado
    como el único sitio donde revisar si algún día las unidades no calzan sobre su
    casilla.
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
