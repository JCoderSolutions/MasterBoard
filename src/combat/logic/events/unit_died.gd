class_name UnitDied
extends Event

## Una unidad dejó de estar viva.
##
## `cause` vive aquí y no en `Unit` a propósito: al estado solo le importa que la
## unidad murió, pero a la vista le importa mucho la diferencia — morir por daño es
## una animación de muerte en el sitio, caerse del tablero es salir de pantalla.
## `Unit.kill()` documenta esta misma división desde el otro lado.

enum Cause { DAMAGE, FALL }

var unit_id: int
var cause: Cause


func _init(p_unit_id: int, p_cause: Cause) -> void:
	super(Type.UNIT_DIED)
	unit_id = p_unit_id
	cause = p_cause


func _to_string() -> String:
	return "UnitDied(unit=%d, %s)" % [unit_id, "FALL" if cause == Cause.FALL else "DAMAGE"]
