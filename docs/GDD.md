# MasterBoard — Documento de Diseño (MVP)

> Estado: borrador v0.1 · Motor: Godot 4.7.1 · Plataforma objetivo: Android (móvil)
> Este documento define **solo el MVP**. Todo lo posterior vive en "Parking Lot".

---

## 1. Pitch

Un deckbuilder táctico por turnos donde peleas 1-contra-varios sobre una arena pequeña.
Cada carta es simultáneamente **movimiento y ataque**: la posición es el recurso principal,
no los puntos de vida. Los enemigos telegrafían su acción antes de tu turno, así que cada
turno es un puzzle con información perfecta.

**Referencias:** Fights in Tight Spaces (cartas = posicionamiento), Into the Breach
(intención telegrafiada, turno como puzzle resoluble).

## 2. Fantasía del jugador

"Estoy rodeado y con desventaja numérica, pero leí el tablero mejor que ellos."
La victoria se siente como haber resuelto un problema, no como haber tenido buenos números.

## 3. Loop core (primeros 60 segundos)

1. Inicia el turno. Ves la arena, tus enemigos, y **una flecha/marca en cada enemigo indicando
   exactamente qué hará al terminar tu turno** (a quién ataca, hacia dónde empuja).
2. Robas una mano de 5 cartas. Tienes 3 puntos de energía.
3. Juegas cartas: cada una te mueve, ataca, empuja, o bloquea. Gastas energía.
4. Terminas el turno → los enemigos ejecutan exactamente lo que telegrafiaron.
5. Repetir hasta que la arena quede limpia.

**El truco de diseño:** los bordes de la plataforma matan. Empujar un enemigo al vacío es más
eficiente que matarlo a golpes. Eso convierte el posicionamiento en el sistema de daño real y
hace que un personaje débil pueda ganar a tres enemigos fuertes.

## 4. Reglas del combate (MVP)

| Elemento | Definición MVP |
|---|---|
| Grilla | 5×5, sin obstáculos en las primeras peleas |
| Unidades del jugador | 1 (el héroe) |
| Enemigos | 2-4 por encuentro |
| Energía | 3 por turno, no acumula |
| Mano | Robas hasta 5 al inicio del turno; descartas el resto al terminar |
| Mazo | ~12 cartas al empezar una run |
| Muerte por caída | Salir de la grilla = muerte instantánea, para jugador y enemigos |
| Información | Perfecta. El jugador ve todo el estado y toda la intención enemiga |
| Aleatoriedad | Solo en el robo de cartas. El combate en sí es determinista |

**Por qué información perfecta:** es lo que hace que un turno perdido se sienta como tu error y
no como mala suerte. También es lo que permite que el juego sea justo en una pantalla de móvil,
donde no puedes desplegar mucha información a la vez.

## 5. La "run" (MVP)

Una run son **5 encuentros encadenados**. Entre encuentros eliges una recompensa de 3 cartas
ofrecidas. Tu vida **no** se restaura entre peleas. Si mueres, la run termina y vuelves al menú.
No hay progresión persistente entre runs en el MVP.

## 6. Personalización

**Solo cosmética.** Paleta de colores del sprite + variantes de arma visual. No altera stats,
no altera cartas, no altera balance. Es intencional: mantiene el balance manejable para un dev
solo y no complica el multijugador futuro.

## 7. Goals (cómo sabemos que el MVP funcionó)

1. Un jugador nuevo entiende el loop sin tutorial escrito, solo jugando el primer encuentro.
2. Un encuentro se resuelve en 2-4 minutos — sesión de móvil real.
3. Al menos 3 formas distintas de ganar el mismo encuentro (empuje, daño directo, control).
4. El build corre a 60fps estables en un Android de gama media.
5. Añadir una carta nueva no requiere tocar código de lógica, solo un archivo de datos.

El #5 no es un capricho técnico: es lo que determina si el juego puede crecer después.

## 8. Non-Goals del MVP (y por qué)

| Fuera de alcance | Razón |
|---|---|
| **Multijugador online** | Requiere backend autoritativo, matchmaking, cuentas y anti-cheat. Es infraestructura para responder una pregunta que aún no tenemos contestada: ¿el combate es divertido? |
| **Tienda / economía** | Una tienda sin catálogo es una pantalla vacía. Se diseña cuando exista contenido que vender |
| **Campaña con historia** | La narrativa multiplica el trabajo de arte, UI de diálogo y escritura. Se añade cuando el combate ya sea bueno — una buena historia no salva un mal combate |
| **Múltiples personajes jugables** | Cada personaje = un mazo inicial balanceado + arte + animaciones. Uno solo, bien afinado, enseña más |
| **iOS** | Duplica el pipeline de export y requiere hardware/cuenta Apple. Android primero |
| **Audio original** | Placeholders libres en el MVP. La música se compone cuando el juego ya tiene forma |

## 9. Requisitos priorizados

### P0 — Sin esto no hay MVP

- **R-01 Grilla y unidades.** Grilla 5×5 con coordenadas lógicas; unidades ocupan una casilla; no dos unidades en la misma casilla.
  - [ ] El estado del combate es consultable sin instanciar la escena
  - [ ] Mover fuera de la grilla marca la unidad como muerta
- **R-02 Sistema de turnos.** Turno de jugador → resolución enemiga → siguiente turno.
  - [ ] El orden de resolución es determinista y reproducible con la misma semilla
- **R-03 Cartas data-driven.** Cada carta es un recurso (`.tres`) con coste, efectos y targeting.
  - [ ] Añadir una carta no requiere modificar ningún `.gd` de lógica
  - [ ] Mínimo 10 cartas jugables cubriendo: mover, atacar, empujar, bloquear, robar
- **R-04 Intención enemiga.** Cada enemigo decide su acción al inicio del turno del jugador y la muestra en pantalla.
  - [ ] Lo que el enemigo ejecuta coincide siempre con lo telegrafiado
- **R-05 IA enemiga.** Dos arquetipos: melee que persigue, y empujador que intenta tirarte al vacío.
- **R-06 Condición de victoria/derrota.** Arena limpia = victoria. Vida 0 o caída = derrota.
- **R-07 Input táctil.** Seleccionar carta con tap, previsualizar objetivos, confirmar con segundo tap. Cancelable.
  - [ ] Todos los targets táctiles ≥ 48dp
  - [ ] Toda acción es cancelable antes de confirmar
- **R-08 Encadenamiento de encuentros.** 5 peleas seguidas con elección de recompensa entre cada una.

### P1 — Mejora mucho, pero se puede lanzar sin ello

- Feedback visual de impacto (screen shake, hitstop, partículas de empuje)
- Deshacer el último movimiento antes de confirmar el fin de turno
- Guardado de run en progreso
- Personalización cosmética (paleta)
- Obstáculos y peligros en la arena (pinchos, agujeros interiores)

### P2 — No se construye ahora, pero la arquitectura debe permitirlo

- Multijugador online por comandos (ver `ARCHITECTURE.md`, decisión A-02)
- Replays y espectador
- Múltiples personajes con mazos distintos
- Modo historia con nodos de mapa ramificados
- Tienda y moneda meta

## 10. Preguntas abiertas

| # | Pregunta | Estado |
|---|---|---|
| D-01 | Orientación | ✅ Resuelto: portrait 270×480. Ver `ARCHITECTURE.md` A-09 |
| D-02 | Perspectiva / facing del asset | ✅ Resuelto: vista de escenario 3/4, el asset de clembod se usa sin cambios. Ver A-10 |
| D-03 | Licencia del asset pack | ✅ Confirmado por el autor: sin problemas de uso |
| D-04 | ¿5×5 se siente bien o hay que probar 6×6? Se decide jugando, no en papel | Playtest en Fase 1 |

## 11. Parking Lot

Ideas buenas que **no** entran ahora. Se anotan aquí para no discutirlas dos veces:
reliquias/artefactos pasivos, cartas de invocación, jefes con mecánica propia, eventos
aleatorios entre peleas, dificultades ascendentes, daily challenge con semilla fija.
