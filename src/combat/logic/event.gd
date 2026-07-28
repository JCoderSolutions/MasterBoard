@abstract class_name Event
extends RefCounted

## Algo que **ya ocurrió**. Un evento nunca pregunta ni decide: solo narra (A-02).
##
## Es la única cosa que la capa visual llega a ver del combate. Por eso cada evento
## carga todo lo que hace falta para animarlo sin volver a consultar el `CombatState`:
## cuando la animación se reproduce, el estado ya avanzó y preguntarle daría la
## respuesta de otro instante.
##
## El `type` existe además de las subclases para que la vista despache con un `match`
## en vez de una cadena de `if event is ...`, y para que un log de replay pueda
## serializarse a un entero estable.

enum Type {
	UNIT_MOVED,
	UNIT_DAMAGED,
	UNIT_DIED,
	PHASE_STARTED,
	BARRIER_PLACED,
	BARRIER_EXPIRED,
}

var type: Type


func _init(p_type: Type) -> void:
	type = p_type
