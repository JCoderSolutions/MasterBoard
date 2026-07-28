class_name ShieldEffect
extends Effect

## Otorga un escudo a la unidad objetivo (GDD §6, familia Escudo).
##
## Casi siempre apunta a quien lanza (`Targeting.Mode.SELF`), pero el efecto no lo
## impone: nada impide una habilidad de soporte que escude a otra casilla, y esa
## decisión es del `.tres`, no de este código.

@export var amount: int = 1
@export var duration: int = 1


func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var receiver := caster if target == caster.position else state.unit_at(target)
	if receiver == null or not receiver.is_alive():
		return events

	receiver.grant_shield(amount, duration)
	events.append(UnitShielded.new(receiver.id, amount, duration))
	return events
