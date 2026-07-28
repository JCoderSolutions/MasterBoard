class_name BarrierPlaced
extends Event

## Se levantó una barrera (GDD §6).
##
## Lleva la duración porque la vista tiene que **enseñarla**: una barrera que aguanta dos
## rondas y una que se desvanece al final de esta no pueden dibujarse igual. Con maná y
## stats públicos, cuánto dura un muro es información del rival tanto como la tuya, y
## esconderla convertiría en adivinar lo que el juego quiere que sea deducir.

var position: Vector2i
var duration: int


func _init(p_position: Vector2i, p_duration: int) -> void:
	super(Type.BARRIER_PLACED)
	position = p_position
	duration = p_duration


func _to_string() -> String:
	return "BarrierPlaced(%v, %d rondas)" % [position, duration]
