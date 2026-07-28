# MasterBoard — Documento de Diseño (MVP)

> Estado: v0.2 · Motor: Godot 4.7.1 · Plataforma objetivo: Android (móvil)
> Este documento define **solo el MVP**. Todo lo posterior vive en "Parking Lot".

> **v0.2 (2026-07-28) — cambio de género.** La v0.1 describía un deckbuilder roguelite
> de un héroe contra varios enemigos, con intención enemiga telegrafiada y run de 5
> encuentros. Se sustituye por un **duelo táctico de selección simultánea**. El motivo
> está en `ARCHITECTURE.md` A-12: el telégrafo no sobrevive al PvP, y el PvP es a donde
> apunta el juego. Lo que se conserva de la v0.1 es la arquitectura (A-02, A-03), no el
> diseño de juego.

---

## 1. Pitch

Un duelo táctico por rondas sobre un tablero pequeño y cerrado. Cada ronda, **ambos bandos
eligen su movimiento y su habilidad sin ver lo que eligió el otro**, y las dos decisiones se
resuelven a la vez en un orden fijo y público.

No hay azar en el combate: no se roban cartas, no se tiran dados. Toda la información —vida,
maná, habilidades del rival, tablero— está a la vista. Lo único que no sabes es **qué va a
elegir el otro en esta ronda**, y ese es el juego entero.

**Referencias:** Into the Breach (el tablero como sistema de daño), Frozen Synapse (órdenes
simultáneas), juegos de lucha (leer al rival conociendo su kit y sus recursos).

## 2. Fantasía del jugador

"Sabía que ibas a hacer eso."

La victoria se siente como haber leído a una persona, no como haber sacado mejores números.
Y la derrota se siente como haber sido leído — que escuece, pero enseña.

## 3. Loop core (una ronda)

1. **Ves todo:** posiciones, vida y maná de ambos, y el kit completo del rival con qué
   habilidades le alcanza el maná ahora mismo.
2. **Eliges en secreto** una carta de movimiento y una de habilidad. El rival hace lo mismo,
   a la vez, sin verte.
3. **Se revelan y se resuelven** en el orden fijo de §5.
4. Repetir hasta que alguien llegue a 0 de vida.

**El truco de diseño:** como el maná es público, cada ronda puedes *descartar* opciones del
rival. Si le quedan 3 y su embestida cuesta 5, la embestida no existe esta ronda. Eso
convierte adivinar en deducir, y es lo que separa este juego del piedra-papel-tijera.

## 4. Reglas del combate (MVP)

| Elemento | Definición MVP |
|---|---|
| Tablero | 5×5 cerrado. Sin salir: los bordes son muro, salvo que la arena diga otra cosa |
| Unidades | 1 por bando (el 2v2 es post-MVP) |
| Por ronda | **Una carta de movimiento + una de habilidad.** Cualquiera de las dos puede omitirse |
| Vida | 10. Sin curación en el MVP (ver §6) |
| Maná | Empieza en 3, +2 al inicio de cada ronda, tope 8. **Público** |
| Movimiento básico | 1 casilla ortogonal, **coste 0**. Siempre disponible, para no quedarte sin opciones |
| Información | Perfecta salvo la elección de la ronda en curso. Kit, stats y maná del rival visibles |
| Aleatoriedad | **Solo qué arena toca.** Ni robo, ni tiradas de daño, ni críticos |
| Fin de partida | Vida a 0. Si ambos caen la misma ronda, empate |
| Presión | Desde la ronda 8 el anillo exterior del tablero se derrumba por capas |

**Por qué el maná se acumula** en vez de recargarse entero cada ronda: un maná que sube crea
la lectura "lleva tres rondas sin gastar, tiene algo grande listo". Si se rellenara siempre al
máximo, esa lectura no existiría y perderías la mitad de la profundidad.

**Por qué el movimiento básico es gratis:** para que nunca haya una ronda en la que no puedas
hacer nada. Es deliberadamente flojo —una casilla, ortogonal— porque su función es evitar la
parálisis, no ser una opción competitiva.

**Por qué el tablero se derrumba:** sin presión temporal, dos jugadores que se leen bien
pueden orbitar sin comprometerse indefinidamente. El derrumbe fuerza la resolución y hace que
el posicionamiento tardío sea tenso en vez de cómodo.

## 5. Orden de resolución (la regla más importante del juego)

Las dos elecciones se resuelven en **fases fijas**, siempre en este orden, y el orden está
visible en la UI:

```
1. Barreras y bloqueos    Se colocan antes de que nadie se mueva
2. Movimiento             Ambos bandos a la vez
3. Ataques                Desde las posiciones YA actualizadas
4. Terreno                Trampas y peligros de la casilla donde acabaste
```

Cada corte gana algo concreto:

- **Barreras primero** hace que negar sea una apuesta real: pones el muro donde crees que va
  a ir. Si se resolvieran después del movimiento, no bloquearían nunca.
- **Ataques después del movimiento** es lo que convierte moverse en esquivar. Es la principal
  expresión de habilidad del juego: tu movimiento hace que su ataque golpee el aire.
- **Terreno al final** permite que empujar a alguien a la lava funcione en la misma ronda.

**Conflictos en la fase de movimiento:**

| Situación | Resultado |
|---|---|
| Ambos van a la misma casilla | Ninguno entra. Rebotan y se quedan donde estaban |
| Intercambio de posiciones (A→B, B→A) | Bloqueado. No se atraviesan |
| A entra donde estaba B, que se está yendo | Permitido. A persigue a B |
| El destino quedó bloqueado por una barrera | El movimiento se detiene contra la barrera |

**Por qué rebotar y no desempatar por velocidad:** un desempate por stat convierte una
decisión en una consulta de tabla, y le da ventaja permanente al personaje rápido en cada
casilla disputada. Rebotar es simétrico, determinista y se aprende en una partida.

**Empuje contra un obstáculo:** la unidad avanza lo que pueda, se detiene y recibe 1 de daño
por impacto. Empujar a un rival contra otra unidad daña a las dos. Es lo que le da al empuje
un premio que no depende de que haya vacío en la arena.

## 6. Habilidades: qué entra y qué no

Cada personaje tiene un **kit fijo** de ~15 habilidades. Antes de la partida eliges **8** como
tu loadout. Todas están disponibles todas las rondas: lo único que las limita es el maná.

**Sin robo de cartas.** Un mazo aleatorio encima de selección oculta es azar sobre azar, y
"no robé la respuesta" en un juego de lectura se siente pésimo. La personalización vive en el
loadout previo, donde es una decisión informada.

Familias de habilidad del MVP:

| Familia | Qué hace | Por qué está |
|---|---|---|
| **Daño** | Golpe directo en un patrón (adyacente, línea, área) | El reloj de la partida |
| **Desplazamiento** | Empuje, tirón, dash, intercambio | Convierte la posición en daño |
| **Barrera** | Muro temporal que bloquea movimiento y línea de tiro | Negar es apostar dónde irá |
| **Escudo** | Absorbe una cantidad fija y caduca | Defensa que no empata la partida |
| **Maná** | Restaura maná propio o quema el del rival | Manipula el espacio de posibilidades |

**Las barreras duran lo que diga su carta**, no lo que diga una regla global: las baratas se
desvanecen al final de la ronda en que se pusieron (apuesta pura de predicción), las caras
aguantan hasta el final de la siguiente (negación de zona). Es un campo del `.tres`, así que
balancear no toca código.

**No hay curación en el MVP.** El sustain produce partidas de desgaste sin resolución: dos
jugadores que se curan y no se comprometen. Los escudos hacen el trabajo defensivo sin ese
riesgo, porque absorben una vez y se acaban. Restaurar **maná** sí está permitido: eso es
tempo, no es alargar la partida.

## 7. Terreno

El tablero no es uniforme. Cada casilla tiene un tipo, y es **dato de la arena**, no regla del
juego:

| Tipo | Efecto |
|---|---|
| `FLOOR` | Normal |
| `WALL` | Intransitable. Bloquea movimiento y empuje |
| `VOID` | Entrar mata. Solo existe en las arenas que lo declaran |
| `HAZARD` | Daña al terminar la fase de movimiento sobre ella (lava, pinchos) |

Esto sustituye a la regla global "salir de la grilla mata" de la v0.1. Que los bordes maten
pasa a ser una propiedad de cada arena: unas son tableros cerrados de ajedrez, otras tienen
vacío en dos lados, otras lava en el centro. Un solo sistema cubre las tres cosas y da
variedad de encuentro sin código nuevo.

**Las arenas son simétricas y hechas a mano.** Nada de generación procedural: si la
disposición decide partidas, la maestría no paga. Simetría en el eje para que ningún bando
reciba la mitad buena, y revelada antes de elegir.

## 8. El oponente: IA primero, PvP después

El MVP es **1v1 contra la IA**. La IA elige **a ciegas**, exactamente igual que un humano:
nunca recibe la decisión del jugador. Evalúa qué puede hacer el jugador dado su maná visible
y su kit, y responde por valor esperado.

Esto no es una versión reducida del PvP, es el mismo juego con el rival cambiado. Si leer al
oponente es divertido contra un bot, lo será contra personas — y mientras tanto tienes algo
lanzable, sin netcode, sin matchmaking y sin depender de que haya población.

## 9. Goals (cómo sabemos que el MVP funcionó)

1. Un jugador nuevo entiende el orden de resolución tras dos rondas, sin tutorial escrito.
2. Una partida dura 3-6 minutos — sesión de móvil real.
3. Un jugador que conoce el kit del rival gana significativamente más que uno que no. **Si
   esto no se cumple, el juego es azar disfrazado y hay que rediseñar.**
4. Al menos 3 formas distintas de ganar la misma partida (daño directo, empuje a peligro,
   asfixia por maná).
5. El build corre a 60fps estables en un Android de gama media.
6. Añadir una habilidad nueva no requiere tocar código de lógica, solo un archivo de datos.

El #3 es el goal que de verdad importa. Los demás son higiene.

## 10. Non-Goals del MVP (y por qué)

| Fuera de alcance | Razón |
|---|---|
| **PvP online** | Backend autoritativo, matchmaking, anti-cheat y —lo peor— problema de población. Es infraestructura para responder una pregunta que aún no está contestada: ¿leer al rival es divertido? |
| **2v2** | Multiplica por cuatro las decisiones ocultas y añade coordinar con un aliado. Si el 1v1 no engancha, el 2v2 no lo salva |
| **Curación** | Ver §6. Riesgo alto de partidas sin resolución |
| **Progresión meta / desbloqueos** | Trabajo de retención que no valida si el combate es bueno |
| **Campaña con historia** | Multiplica arte, UI de diálogo y escritura. Una buena historia no salva un mal combate |
| **iOS** | Duplica el pipeline de export y requiere hardware Apple |
| **Audio original** | Placeholders libres en el MVP |

## 11. Requisitos priorizados

### P0 — Sin esto no hay MVP

- **R-01 Tablero y unidades.** 5×5 con capa de terreno; una unidad por casilla.
  - [ ] El estado es consultable sin instanciar la escena
  - [ ] Entrar en `VOID` mata; `WALL` bloquea; `HAZARD` daña
- **R-02 Ronda simultánea.** Ambos bandos eligen en secreto, se resuelve por fases.
  - [ ] El resultado es idéntico con la misma semilla y las mismas elecciones
  - [ ] Ninguna fase puede leer la elección del otro bando antes de la revelación
- **R-03 Habilidades data-driven.** Cada habilidad es un `.tres` con coste, patrón y efectos.
  - [ ] Añadir una habilidad no requiere modificar ningún `.gd` de lógica
  - [ ] Mínimo 15 habilidades cubriendo las 5 familias de §6
- **R-04 Maná y stats públicos.** El jugador ve en todo momento el maná del rival y qué
  habilidades suyas están disponibles con ese maná.
  - [ ] Las habilidades que el rival no puede pagar se muestran atenuadas
- **R-05 IA que elige a ciegas.** Evalúa el espacio de acciones del jugador y responde.
  - [ ] Test explícito: la función de decisión de la IA nunca recibe el comando del jugador
- **R-06 Fin de partida.** Vida a 0 = derrota. Ambos a 0 la misma ronda = empate.
- **R-07 Input táctil.** Elegir movimiento y habilidad con tap, previsualizar, confirmar.
  - [ ] Todos los targets táctiles ≥ 48dp
  - [ ] Toda elección es cancelable antes de confirmar la ronda
- **R-08 Legibilidad de la resolución.** Las fases se animan en secuencia, no a la vez.
  - [ ] El jugador puede reconstruir por qué pasó lo que pasó, sin repetición

### P1 — Mejora mucho, pero se puede lanzar sin ello

- Feedback de impacto (screen shake, hitstop, partículas de empuje)
- Repetición de la última ronda a petición
- Derrumbe del tablero con aviso visual anticipado
- Personalización cosmética (paleta)
- Más arenas

### P2 — No se construye ahora, pero la arquitectura debe permitirlo

- PvP online por comandos (ver `ARCHITECTURE.md` A-02)
- 2v2, con selección visible entre aliados
- Replays y espectador
- Más personajes y draft/ban previo a la partida
- Tienda y moneda meta

## 12. Preguntas abiertas

| # | Pregunta | Estado |
|---|---|---|
| D-01 | Orientación | ✅ Resuelto: portrait 270×480. Ver `ARCHITECTURE.md` A-09 |
| D-02 | Perspectiva / facing del asset | ✅ Resuelto: vista de escenario 3/4. Ver A-10 |
| D-03 | Licencia del asset pack | ✅ Confirmado por el autor: sin problemas de uso |
| D-04 | ¿5×5 se siente bien para un duelo, o se queda pequeño? | Playtest |
| D-05 | Números de maná (3 inicial, +2/ronda, tope 8) y vida (10) | Playtest |
| D-06 | ¿Cuántos personajes hacen falta para que la lectura de matchup exista? Mínimo teórico 3 | Playtest |
| D-07 | ¿La ronda necesita temporizador? Contra IA no, contra humanos sí | Se decide al llegar al PvP |

## 13. Parking Lot

Ideas buenas que **no** entran ahora, anotadas para no discutirlas dos veces: draft/ban de
personaje, habilidades pasivas, ultimates que se cargan por daño recibido, arenas con
mecánica propia, modo por equipos 3v3, daily challenge con arena fija, y un modo puzzle
single-player con soluciones exactas.
