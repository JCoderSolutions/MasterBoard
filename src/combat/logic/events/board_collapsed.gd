class_name BoardCollapsed
extends Event

## Un anillo del tablero se derrumbó (GDD §4, presión desde la ronda 8).
##
## Lleva las casillas afectadas en vez de solo "cuál anillo": la vista no debería tener
## que reimplementar la geometría de anillos para saber qué pintar cayéndose.

var positions: Array[Vector2i]


func _init(p_positions: Array[Vector2i]) -> void:
	super(Type.BOARD_COLLAPSED)
	positions = p_positions


func _to_string() -> String:
	return "BoardCollapsed(%d casillas)" % positions.size()
