class_name PushEffect
extends Effect

## Empuja a la unidad objetivo **alejándola de quien lanza** (GDD §6, Desplazamiento).
##
## La dirección se deduce de las dos posiciones en vez de configurarse en el `.tres`:
## una habilidad de empuje que te dejara elegir hacia dónde sale despedido el rival
## sería un teletransporte con otro nombre, y el jugador no podría prever el resultado
## mirando el tablero. Empujar aleja. Siempre.
##
## Toda la regla de colisión —choque, daño de impacto, caída al vacío— vive en
## `Displacement`, no aquí.

@export var distance: int = 1


func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var victim := state.unit_at(target)
	if victim == null:
		return events

	var direction := Grid.direction(caster.position, target)
	if direction == Vector2i.ZERO:
		return events

	return Displacement.push(state, victim.id, direction, distance)
