class_name ShieldExpired
extends Event

## Un escudo dejó de existir, por agotarse o por cumplir sus rondas.
##
## La vista no distingue las dos causas: en ambos casos quita el indicador. Que un
## escudo a cero caduque aunque le quedaran rondas es regla de `Unit.absorb()` — un
## escudo a cero no es un escudo.

var unit_id: int


func _init(p_unit_id: int) -> void:
	super(Type.SHIELD_EXPIRED)
	unit_id = p_unit_id


func _to_string() -> String:
	return "ShieldExpired(unit=%d)" % unit_id
