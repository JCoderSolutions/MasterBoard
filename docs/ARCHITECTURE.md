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

## A-04 — Cartas como recursos, no como código

**Decisión:** cada carta es un `Resource` (`.tres`) con datos: coste, tipo de targeting,
lista de efectos. Los efectos son también recursos, componibles.

```
resources/cards/
  strike.tres        # coste 1, target: enemigo adyacente, efectos: [Damage(3)]
  shove.tres         # coste 1, target: enemigo adyacente, efectos: [Push(2)]
  reposition.tres    # coste 0, target: casilla vacía en rango 2, efectos: [MoveSelf]
```

`CardDatabase` (ya está en tus autoloads) carga y indexa estos recursos al arrancar.

**Por qué:** el balance de un deckbuilder son cientos de iteraciones pequeñas. Si cada ajuste
requiere tocar código y recompilar mentalmente el sistema, no vas a iterar lo suficiente y el
juego quedará mal balanceado. Además, un archivo de datos es un diff limpio en git.

**Consecuencia:** el conjunto de "efectos" posibles debe diseñarse con cuidado desde el
principio. Empieza con pocos y ortogonales: `Damage`, `Push`, `Pull`, `MoveSelf`, `Block`, `Draw`.

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
  autoloads/        AudioManager, CardDatabase, GameEvents, TurnSystem
  combat/
    logic/          Estado puro, sin nodos (ver A-02)
    view/           Nodos, animación, feedback
    ai/             Decisión enemiga. Consume logic/, nunca view/
  ui/               Menús, HUD, pantallas meta
  meta/             Run, progresión, recompensas
resources/
  cards/            .tres de cartas
  enemies/          .tres de arquetipos enemigos
  encounters/       .tres de composiciones de encuentro
assets/
  sprites/  audio/  fonts/
test/               Tests GdUnit4, espejando src/combat/logic/
docs/               Este documento, GDD, backlog
```

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
- Empujar una unidad fuera de la grilla la mata
- Una carta no se puede jugar sin energía suficiente
- El estado tras N comandos es idéntico con la misma semilla
- Un enemigo ejecuta exactamente la acción que telegrafió
