class_name PullEffect
extends Effect

## Tira de la unidad objetivo **hacia quien lanza** (GDD §6, Desplazamiento).
##
## Es `PushEffect` con la dirección invertida, y esa es toda la implementación: la firma
## por dirección de `Displacement.push()` se eligió en 1.7 precisamente para que el tirón
## saliera gratis.
##
## Diseño: el tirón no es un empuje simétrico. Acerca al rival, así que prepara tu propio
## golpe cuerpo a cuerpo la ronda siguiente en vez de resolver ahora — y de paso lo saca
## de donde él quería estar. Es la herramienta contra el que huye, no contra el que
## presiona.

@export var distance: int = 1


func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var victim := state.unit_at(target)
	if victim == null:
		return events

	var direction := Grid.direction(target, caster.position)
	if direction == Vector2i.ZERO:
		return events

	return Displacement.push(state, victim.id, direction, distance)
