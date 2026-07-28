@abstract class_name Command
extends RefCounted

## Una intención del jugador o de la IA, todavía sin ejecutar (A-02).
##
## Un comando es un **dato**, no una acción: se puede construir, inspeccionar, guardar
## en una lista y aplicar más tarde. De ahí salen casi gratis el undo, el replay y el
## multijugador (mandas comandos, no estado).
##
## Contrato entre los dos métodos:
##
## - `validate()` es puro. No toca el estado. Se puede llamar mil veces seguidas —
##   la UI lo usa para saber qué casillas resaltar antes de que toques nada.
## - `apply()` asume que `validate()` ya dijo que sí. No revalida. Quien salta ese
##   orden se lleva un estado corrupto, y por eso el único camino recomendado es
##   `Resolver.execute()`, que encadena los dos.
##
## Un comando puede estar compuesto de varios efectos, pero se aplica entero o nada:
## no existe el medio comando.

## Devuelve `true` si el comando es legal sobre este estado. Nunca lo modifica.
@abstract func validate(state: CombatState) -> bool


## Ejecuta el comando y devuelve, en orden cronológico, todo lo que ocurrió.
##
## El orden importa: la vista los reproduce en secuencia (backlog 1.17), así que un
## empujón que mata debe emitir el movimiento antes que la muerte, no al revés.
@abstract func apply(state: CombatState) -> Array[Event]
