class_name ManaEffect
extends Effect

## Restaura o quema maná de la unidad objetivo (GDD §6, familia Maná).
##
## Un solo efecto para las dos caras de la familia: `amount` positivo restaura,
## negativo quema. Igual que `DamageEffect`, no distingue amigo de enemigo — restaurar
## y quemar son la misma operación con signo distinto, y quién es el objetivo lo decide
## el `targeting` de la habilidad (`SELF` para restaurar, `UNIT` para quemar), no este
## código.
##
## No es curación: manipula el maná, que es *tempo* y *opciones*, no vida. El GDD
## prohíbe curar para que la partida no se convierta en desgaste sin resolución, pero
## permite esto explícitamente por la misma razón contraria.

@export var amount: int = 1


func apply(state: CombatState, _caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var unit := state.unit_at(target)
	if unit == null or not unit.is_alive():
		return events

	var applied := unit.change_mana(amount)
	if applied == 0:
		return events

	events.append(UnitManaChanged.new(unit.id, applied, unit.mana))
	return events
