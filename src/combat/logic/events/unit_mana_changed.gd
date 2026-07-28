class_name UnitManaChanged
extends Event

## El maná de una unidad cambió por un efecto (familia Maná, GDD §6).
##
## Un solo tipo de evento cubre restaurar y quemar: `amount` lleva el signo de lo que
## **de verdad** pasó —positivo restaura, negativo quema— ya recortado por el tope o por
## el suelo de 0. Separar `ManaRestored`/`ManaBurned` obligaría a la vista a tratar dos
## eventos que solo se diferencian en el signo de un número que ya tiene.
##
## No cubre el reparto pasivo de `CombatState.begin_round()`: eso es economía base, no
## un efecto de habilidad, y mezclarlos en el mismo evento le haría creer a la vista que
## el maná de inicio de ronda vino de una carta.

var unit_id: int
var amount: int
var mana_after: int


func _init(p_unit_id: int, p_amount: int, p_mana_after: int) -> void:
	super(Type.UNIT_MANA_CHANGED)
	unit_id = p_unit_id
	amount = p_amount
	mana_after = p_mana_after


func _to_string() -> String:
	return "UnitManaChanged(unit=%d, %+d, mana=%d)" % [unit_id, amount, mana_after]
