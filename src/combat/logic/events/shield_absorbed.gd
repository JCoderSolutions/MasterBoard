class_name ShieldAbsorbed
extends Event

## Un escudo se comió parte de un golpe.
##
## Va **antes** del `UnitDamaged` del mismo golpe, y solo hay `UnitDamaged` si algo pasó
## de largo: un golpe absorbido entero no baja la vida, así que emitir un `UnitDamaged`
## de 0 sería mentirle a la vista y obligarla a filtrarlo.

var unit_id: int
var amount: int
var shield_after: int


func _init(p_unit_id: int, p_amount: int, p_shield_after: int) -> void:
	super(Type.SHIELD_ABSORBED)
	unit_id = p_unit_id
	amount = p_amount
	shield_after = p_shield_after


func _to_string() -> String:
	return "ShieldAbsorbed(unit=%d, %d, escudo=%d)" % [unit_id, amount, shield_after]
