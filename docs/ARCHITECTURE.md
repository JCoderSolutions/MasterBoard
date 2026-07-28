# MasterBoard — Arquitectura

Registro de decisiones técnicas. Cada decisión indica el contexto, la elección y las
consecuencias — incluyendo las malas, para que en tres meses sepas por qué está así.

---

## A-01 — GDScript, no C#

**Contexto:** Godot soporta ambos. El proyecto es móvil, de un solo dev, asistido por IA.

**Decisión:** GDScript para todo.

**Por qué:** el export a Android con C# ha sido históricamente el camino con más fricción
(tamaño de build, runtime .NET, pasos extra de configuración). Además, hay muchísimo más
GDScript público que C# de Godot, así que un asistente de IA produce código notablemente más
correcto en GDScript — y vas a apoyarte mucho en eso.

**Consecuencia negativa aceptada:** GDScript es más lento en cálculo puro. Irrelevante aquí:
una grilla de 5×5 con 5 unidades no tiene un cuello de botella de CPU.

---

## A-02 — Separación lógica / presentación (la decisión importante)

**Contexto:** el impulso natural en Godot es meter la lógica del juego dentro de los nodos
(`CharacterBody2D` que se mueve y además decide reglas). Funciona al principio y se vuelve
inmanejable después.

**Decisión:** el combate se modela como **estado puro + comandos**, sin ninguna dependencia
del árbol de nodos.

```
src/combat/logic/     # GDScript puro. Cero nodos. Cero await. Cero señales de escena.
  combat_state.gd     #   Snapshot completo: grilla, unidades, mazo, energía, turno
  command.gd          #   Clase base: validate(state) -> bool, apply(state) -> [Event]
  commands/           #   play_card.gd, end_turn.gd, ...
  resolver.gd         #   Aplica un comando y devuelve la lista de eventos resultantes

src/combat/view/      # Nodos. Solo escucha eventos y anima. Nunca decide reglas.
```

**El flujo es de una sola dirección:**

```
Input táctil → Command → Resolver → CombatState mutado + [Event]
                                              ↓
                                    GameEvents (autoload)
                                              ↓
                                    Capa visual anima
```

La capa visual **nunca** consulta ni modifica el estado directamente. Solo reacciona a eventos.

**Por qué vale la pena la disciplina extra:**

1. **Tests sin abrir el editor.** Puedes testear "empujar al enemigo al borde lo mata" en
   milisegundos, sin escena, sin renderizado. Esto es lo que hace viable que un agente de IA
   trabaje rápido y verificado en tu proyecto.
2. **Multijugador futuro casi gratis.** Si el resolver es determinista, sincronizar online
   significa mandar comandos (`PlayCard(carta_3, casilla_2_4)`), no estado. Es la diferencia
   entre semanas y meses de trabajo.
3. **IA enemiga que simula.** El enemigo puede clonar el estado, probar 20 movimientos y elegir
   el mejor. Imposible si la lógica vive en nodos.
4. **Undo y replay.** Guardas la lista de comandos, la reproduces. Sale gratis.

**Regla que no se rompe:** si un archivo dentro de `src/combat/logic/` importa algo de
`scene`, `Node`, o usa `await`, la separación está rota. Es el primer sitio donde mirar cuando
algo se vuelva difícil de depurar.

---

## A-03 — Determinismo obligatorio

**Decisión:** toda aleatoriedad pasa por una única instancia de `RandomNumberGenerator` con
semilla explícita, guardada dentro del `CombatState`.

**Prohibido:** `randi()`, `randf()`, `Array.shuffle()` globales en cualquier parte de `logic/`.

**Por qué:** sin esto, A-02 no sirve para nada. Un bug reportado con la semilla `48211` debe
reproducirse idéntico en tu máquina. Y sin determinismo no hay multijugador por comandos.

---

## A-04 — Habilidades como recursos, no como código

> Escrita cuando el juego era un deckbuilder. La decisión sobrevive entera al pivote de
> `GDD.md` v0.2; solo cambia el vocabulario: *carta* → *habilidad*, y desaparece `Draw`
> porque ya no hay mazo (ver A-14).

**Decisión:** cada habilidad es un `Resource` (`.tres`) con datos: coste de maná, tipo de
targeting, lista de efectos. Los efectos son también recursos, componibles.

```
resources/abilities/
  strike.tres        # coste 1, target: enemigo adyacente, efectos: [Damage(3)]
  shove.tres         # coste 1, target: enemigo adyacente, efectos: [Push(2)]
  dash.tres          # coste 0, target: casilla libre en rango 2, efectos: [MoveSelf]
  bulwark.tres       # coste 2, target: casilla libre adyacente, efectos: [Barrier(1)]
```

**No hay registro global.** A-04 pedía originalmente un autoload `AbilityDatabase` que
cargara e indexara los recursos al arrancar; al implementarlo (backlog 1.8) resultó que no
lo necesita nadie. Un autoload es un `Node`, así que `logic/` no puede tocarlo (A-02), y las
habilidades no llegan al combate buscándolas por id: llegan dentro del personaje, porque
cargar `guerrero.tres` arrastra su kit entero — Godot sigue las referencias entre recursos
solo. El singleton habría sido un envoltorio de `load()` sobre una caché que `ResourceLoader`
ya tiene.

Si los replays o el PvP acaban necesitando resolver un id de habilidad a su recurso, se añade
entonces, y como clase estática. `Ability.id` existe desde el principio precisamente para que
esa puerta quede abierta.

**Por qué:** el balance son cientos de iteraciones pequeñas. Si cada ajuste requiere tocar
código y recompilar mentalmente el sistema, no vas a iterar lo suficiente y el juego quedará
mal balanceado. Además, un archivo de datos es un diff limpio en git.

**Consecuencia:** el conjunto de "efectos" posibles debe diseñarse con cuidado desde el
principio. Empieza con pocos y ortogonales: `Damage`, `Push`, `Pull`, `MoveSelf`, `Barrier`,
`Shield`, `Mana`. La duración de una barrera es un campo del recurso, no una regla global
(`GDD.md` §6).

---

## A-05 — Eventos vía autoload, no señales encadenadas

**Contexto:** ya tienes `GameEvents` como autoload. Buen instinto, formalicémoslo.

**Decisión:** `GameEvents` es el único bus entre lógica y presentación. La capa lógica emite
eventos, la visual se suscribe.

**Por qué:** con señales nodo-a-nodo, cada vez que reorganizas la escena rompes conexiones. Un
bus central sobrevive a la reorganización, que en un juego pasa constantemente.

**Cuidado:** un bus global es fácil de convertir en un basurero. Regla: solo eventos del dominio
del combate y del meta-juego. Nada de `GameEvents.button_pressed`.

---

## A-06 — Estructura de carpetas

```
src/
  autoloads/        AudioManager, GameEvents
  combat/
    logic/          Estado puro, sin nodos (ver A-02)
      events/       Subclases de Event
      commands/     Subclases de Command
      effects/      Subclases de Effect (piezas de habilidad)
    view/           Nodos, animación, feedback
    ai/             Decisión del rival. Consume logic/, nunca view/
  ui/               Menús, HUD, pantallas de loadout
  meta/             Perfil, loadouts guardados, desbloqueos
resources/
  abilities/        .tres de habilidades
  characters/       .tres de personajes (kit de ~15 habilidades)
  arenas/           .tres de arenas: terreno y posiciones de salida
assets/
  sprites/  audio/  fonts/
test/               Tests GdUnit4, espejando src/combat/logic/
docs/               Este documento, GDD, backlog
```

> Los nombres de `resources/` cambiaron con el pivote de `GDD.md` v0.2: `cards/` →
> `abilities/` (A-14, ya no hay mazo), `enemies/` → `characters/` (el rival es un
> personaje con kit, no un arquetipo de IA) y `encounters/` → `arenas/` (no hay
> encuentros encadenados, hay partidas sueltas). `TurnSystem` se eliminó al alinear
> el repo con A-06; el turno lo lleva el `CombatState`.

---

## A-09 — Orientación: portrait

**Decisión (resuelve D-01):** portrait, `viewport_width=270`, `viewport_height=480` (se
intercambian los valores actuales, que están en landscape).

**Por qué:** con menús estilo Clash Royale, mano de cartas abajo y una sola mano sosteniendo
el teléfono, portrait es el estándar del género en móvil. Cambiarlo después implica rehacer
todo el layout de UI, así que se fija ahora.

## A-10 — Perspectiva: vista de "escenario" (stage), no top-down puro

**Contexto (resuelve D-02):** el asset de clembod es side-view (mira izquierda/derecha). En un
top-down puro eso es un problema porque las unidades nunca podrían mirar arriba/abajo.

**Decisión:** en vez de forzar top-down, adoptamos la misma solución que usan las dos
referencias que diste — **Into the Breach y Fights in Tight Spaces**: la arena se presenta
como un escenario visto desde un ángulo elevado (3/4), con los personajes siempre de perfil,
enfrentados a través del tablero. La grilla lógica (`CombatState`) sigue siendo una grilla 2D
abstracta con coordenadas `(fila, columna)` — la perspectiva es solo cómo se dibuja, no cómo
se calcula.

**Por qué esta y no top-down puro:**
1. Es exactamente la solución de tus dos referencias — no es una concesión, es el estándar del
   género para esta razón específica.
2. **El asset de clembod sirve tal cual**, sin resprite. Un personaje top-down real necesita
   sprites de 4 direcciones (arriba/abajo/izq/der) — cuadruplica el trabajo de animación para
   un dev solo. Con vista de escenario, un set de animaciones izquierda/derecha alcanza.
3. Los enemigos se leen mejor en una fila frente al jugador que dispersos en una grilla vista
   desde arriba, sobre todo en una pantalla pequeña.

**Consecuencia práctica:** la licencia del asset ya la confirmaste como correcta, así que el
héroe **no necesita cambiarse.** Sí vas a necesitar sprites adicionales para enemigos —
ver A-11 sobre generación con IA para eso.

## A-11 — Generación de sprites con IA (opcional, para contenido nuevo)

No hace falta para el héroe (A-10), pero sí para enemigos y variantes futuras. Herramientas
evaluadas, todas con capa gratuita:

- **PixelLab** — la más alineada a este flujo: genera personajes, rotaciones direccionales y
  hojas de animación, y **tiene servidor MCP oficial** (`api.pixellab.ai/mcp`), así que se
  puede invocar directo desde Claude Code. 40 generaciones gratis sin tarjeta; de ahí en
  adelante es de pago por créditos o suscripción.
- **Retro Diffusion** — mejor calidad de pixel art "auténtico" (grilla real, paleta limitada,
  sin el suavizado típico de otros generadores). 50 créditos gratis; extensión de Aseprite de
  pago única si se vuelve una herramienta recurrente.

**Recomendación:** empezar con los créditos gratis de PixelLab cuando llegues a la tarea 1.15
(enemigos). Si el volumen de assets crece, agregar Retro Diffusion como complemento para
piezas clave que necesiten mejor terminado.

## A-07 — Móvil: restricciones que condicionan el diseño

- **Renderer `mobile`** (ya configurado). No usar features del renderer `forward+`.
- **Filtro de textura nearest** (ya configurado, valor `0`). Correcto para pixel art.
- **Resolución base fija + stretch `viewport`** (ya configurado). Confirmar orientación (D-01).
- **Targets táctiles ≥ 48dp.** Es la razón principal por la que la grilla es 5×5 y no 8×8:
  en una pantalla de teléfono, 64 casillas no son tocables con el pulgar sin errores.
- **Sin hover.** Todo estado que en PC mostrarías al pasar el mouse necesita otra solución:
  tap para previsualizar, segundo tap para confirmar.
- **Presupuesto de draw calls.** Agrupar sprites en atlas. Un TileMap para la grilla, no 25 nodos Sprite2D.

---

## A-08 — Testing

**Decisión:** GdUnit4, cobertura obligatoria en `src/combat/logic/`, opcional en el resto.

**Por qué solo en logic/:** ahí viven las reglas que, si se rompen, arruinan el juego en silencio.
Testear animaciones y UI en un proyecto solo es un mal uso de tu tiempo.

**Casos que deben tener test desde el día 1:**
- Entrar en una casilla `VOID` mata la unidad
- Una habilidad no se puede usar sin maná suficiente
- El estado tras N rondas es idéntico con la misma semilla y las mismas elecciones
- La IA nunca recibe la elección del jugador antes de decidir (ver A-15)

---

## A-12 — Resolución simultánea por fases

**Contexto (2026-07-28):** el juego pasó a ser un duelo de selección simultánea (ver `GDD.md`
v0.2). Ambos bandos eligen sin ver al otro, así que hace falta una regla de resolución. Las
dos candidatas eran fases fijas o "un bando ejecuta entero y luego el otro".

**Decisión:** fases fijas — barreras → movimiento → ataques → terreno.

**Por qué no equipos alternos:** dan ventaja estructural al que resuelve primero. Sus
unidades se mueven y matan antes de que el otro actúe, así que las acciones del segundo
apuntan a posiciones que ya cambiaron. Alternar quién empieza cada ronda no lo arregla:
convierte la paridad del número de ronda en un factor de victoria, que es ruido puro.

Y hay un daño de diseño más profundo: lo valioso de la selección simultánea es que **ambos
apostaron en las mismas condiciones**. Si uno resuelve primero, el otro apostó contra alguien
que ya sabía que actuaría antes. La simetría *es* el producto.

**El argumento a favor de los alternos era la legibilidad** —se siguen mucho mejor en una
pantalla de 270×480— y hay que reconocerlo. Pero ya está resuelto por otra vía: la lógica
resuelve simultáneo y **la presentación se reproduce en secuencia**. `Resolver` devuelve un
`Array[Event]` ordenado y la cola de animación los reproduce uno a uno. Se obtiene la simetría
de las fases con la legibilidad de los alternos.

**Consecuencia:** un comando ya no se aplica suelto. La unidad de ejecución es la **ronda**:
se recogen las elecciones de ambos bandos y se resuelven juntas. `Resolver.execute()` sigue
sirviendo para aplicar un comando individual dentro de una fase.

---

## A-13 — Terreno como capa de datos, no como reglas especiales

**Contexto:** la v0.1 del GDD tenía "salir de la grilla mata" como regla global. El diseño
nuevo quiere tableros cerrados, tableros con vacío, y peligros interiores tipo lava.

**Decisión:** cada casilla tiene un tipo — `FLOOR`, `WALL`, `VOID`, `HAZARD` — y es propiedad
de la arena, no del juego.

**Por qué:** las tres cosas que se querían son la misma cosa vista desde ángulos distintos. Un
sistema de terreno las cubre las tres; tres reglas especiales interactuarían mal entre ellas
(¿qué pasa si empujas hacia un borde que además tiene lava?). Además convierte "los bordes
matan" en una decisión de diseño de encuentro, que es lo que da variedad sin código nuevo.

**Consecuencia:** `CombatState.is_free()` deja de significar "dentro de la grilla y vacía" y
pasa a consultar el terreno. Salir del tablero es intentar entrar en una casilla que no existe,
y eso simplemente se bloquea.

---

## A-14 — Kit fijo, no mazo

**Decisión:** cada personaje tiene ~15 habilidades siempre disponibles, limitadas solo por
maná. El jugador elige 8 antes de la partida. **No hay robo de cartas.**

**Por qué:** el robo aleatorio sobre selección oculta es azar apilado sobre azar. "No robé la
respuesta" es aceptable en un roguelite single-player donde la run absorbe la varianza; en un
duelo de lectura es la razón número uno por la que un jugador siente que perdió injustamente.

**Consecuencia técnica:** `CombatState` pierde `deck`, `hand` y `discard`. La personalización
se mueve a un `Loadout` que se resuelve **antes** de que empiece el combate, así que el estado
de combate no la conoce: solo ve la lista de habilidades disponibles.

---

## A-15 — La IA elige a ciegas

**Decisión:** la función de decisión de la IA recibe el `CombatState` y su propio kit, y
**nunca** el comando que eligió el jugador esa ronda.

**Por qué:** es la única diferencia entre un rival y un tramposo. Como ambos eligen a la vez,
sería trivial —y tentador, por rendimiento— pasarle la elección del jugador "ya que la
tenemos". El juego seguiría funcionando y se volvería injusto en silencio, que es la peor
clase de bug: no crashea, solo hace que perder se sienta mal sin que nadie sepa por qué.

**Cómo se protege:** con un test explícito sobre la firma y el flujo de decisión, no con
disciplina. La IA sí puede clonar el estado y simular las acciones *posibles* del jugador
—eso es leer, no hacer trampa— usando `CombatState.clone()` (A-02, punto 3).
