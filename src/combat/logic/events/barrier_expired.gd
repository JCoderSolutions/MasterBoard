class_name BarrierExpired
extends Event

## Una barrera se desvaneció al acabar la ronda.
##
## Existe como evento propio en vez de dejar que la vista cuente rondas por su cuenta:
## contar es decidir, y la capa visual no decide reglas. Lo único que hace es quitar el
## muro cuando esto llega.

var position: Vector2i


func _init(p_position: Vector2i) -> void:
	super(Type.BARRIER_EXPIRED)
	position = p_position


func _to_string() -> String:
	return "BarrierExpired(%v)" % position
