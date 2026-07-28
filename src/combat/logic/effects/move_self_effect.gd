class_name MoveSelfEffect
extends Effect

## Mueve a quien lanza hasta la casilla objetivo: el dash (GDD §6, Desplazamiento).
##
## Delega en `MoveCommand`, que ya sabe todo lo que hay que saber sobre moverse: recorre
## casilla a casilla, se detiene contra los obstáculos y se cae si el camino cruza un
## abismo. Reimplementarlo aquí sería tener dos versiones de la regla de movimiento que
## se desincronizarían a la primera.
##
## Llama a `apply()` sin `validate()` a propósito: la legalidad de la casilla ya la
## comprobó el targeting al elegir, y entre elegir y resolver puede haberse levantado una
## barrera. Ahí hay que avanzar lo que se pueda, no cancelar (GDD §5).
##
## Que el alcance del dash sea 2 o 3 no se decide aquí: sale del `max_range` de la
## habilidad, que es un campo del `.tres`.

func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	return MoveCommand.new(caster.id, target).apply(state)
