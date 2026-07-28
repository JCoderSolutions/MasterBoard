class_name MoveSelfEffect
extends Effect

## Mueve a quien lanza hasta la casilla objetivo: el dash (GDD §6, Desplazamiento).
##
## Delega en `MoveCommand`, que ya sabe todo lo que hay que saber sobre moverse: exige
## alineación y camino despejado, y recorre casilla a casilla para que cruzar un abismo
## termine dentro del abismo. Reimplementarlo aquí sería tener dos versiones de la regla
## de movimiento que se desincronizarían a la primera.
##
## Que el alcance del dash sea 2 o 3 no se decide aquí: sale del `max_range` de la
## habilidad, que es un campo del `.tres`.

func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var command := MoveCommand.new(caster.id, target)
	if not command.validate(state):
		return events

	return command.apply(state)
