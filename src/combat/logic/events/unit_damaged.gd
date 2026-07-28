class_name UnitDamaged
extends Event

## Una unidad recibió daño. Se emite aunque el golpe sea letal: la vista anima el
## impacto y después la muerte, así que en ese caso salen `UnitDamaged` y `UnitDied`
## en ese orden.
##
## `amount` es el daño **efectivamente aplicado**, no el que pedía la carta. Si a una
## unidad con 2 de vida le pegas 7, aquí llega 2. La vista no debería mostrar un "-7"
## flotante sobre una barra que solo bajó 2.

var unit_id: int
var amount: int
var hp_after: int


func _init(p_unit_id: int, p_amount: int, p_hp_after: int) -> void:
	super(Type.UNIT_DAMAGED)
	unit_id = p_unit_id
	amount = p_amount
	hp_after = p_hp_after


func _to_string() -> String:
	return "UnitDamaged(unit=%d, -%d, hp=%d)" % [unit_id, amount, hp_after]
