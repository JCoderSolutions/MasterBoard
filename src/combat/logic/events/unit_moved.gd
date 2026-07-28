class_name UnitMoved
extends Event

## Una unidad cambió de casilla.
##
## Lleva `from` y `to` en vez de solo el destino porque la vista necesita el origen
## para interpolar, y para cuando reciba el evento la unidad ya estará en `to`.

var unit_id: int
var from: Vector2i
var to: Vector2i


func _init(p_unit_id: int, p_from: Vector2i, p_to: Vector2i) -> void:
	super(Type.UNIT_MOVED)
	unit_id = p_unit_id
	from = p_from
	to = p_to


func _to_string() -> String:
	return "UnitMoved(unit=%d, %v -> %v)" % [unit_id, from, to]
