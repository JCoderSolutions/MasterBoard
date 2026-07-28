class_name UnitShielded
extends Event

## Una unidad recibió un escudo.
##
## Lleva la duración por el mismo motivo que `BarrierPlaced`: con stats públicos, cuánto
## aguanta el escudo del rival es información suya y tuya. Esconderla convertiría en
## adivinar lo que el juego quiere que sea deducir.

var unit_id: int
var amount: int
var duration: int


func _init(p_unit_id: int, p_amount: int, p_duration: int) -> void:
	super(Type.UNIT_SHIELDED)
	unit_id = p_unit_id
	amount = p_amount
	duration = p_duration


func _to_string() -> String:
	return "UnitShielded(unit=%d, +%d, %d rondas)" % [unit_id, amount, duration]
