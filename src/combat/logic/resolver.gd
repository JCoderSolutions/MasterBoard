class_name Resolver
extends RefCounted

## Único punto por el que un comando llega al estado (A-02).
##
## Existe para que el orden `validate()` → `apply()` no dependa de que cada quien se
## acuerde de respetarlo, y para llevar el historial que hace posibles el undo y el
## replay.
##
## **No emite a `GameEvents`.** `GameEvents` es un autoload, o sea un `Node`, y esta
## carpeta es GDScript puro. Quien conecte lógica y vista vive fuera de `logic/` y se
## limita a pasar los eventos que `execute()` devuelve.

## Comandos aplicados, en orden. Con esto y `CombatState.rng_seed` se reconstruye el
## combate entero desde cero: es lo que vuelve reproducible un bug reportado.
var history: Array[Command] = []


## Valida y aplica. Si el comando es ilegal devuelve un array vacío y **el estado
## queda intacto**.
##
## Un array vacío no significa por sí solo "rechazado": un comando legal también
## puede no producir eventos. Para distinguirlos está `history`, que solo crece con
## lo que se aplicó de verdad.
func execute(state: CombatState, command: Command) -> Array[Event]:
	if not command.validate(state):
		return []
	history.append(command)
	return command.apply(state)


## Para que la UI sepa qué ofrecer sin ejecutar nada (A-07: sin hover, todo se
## previsualiza antes del segundo tap).
func can_execute(state: CombatState, command: Command) -> bool:
	return command.validate(state)
