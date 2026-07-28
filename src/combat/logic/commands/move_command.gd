class_name MoveCommand
extends Command

## Mueve una unidad en línea recta hasta una casilla (A-02).
##
## Es el primitivo de movimiento: cubre tanto el paso básico de una casilla como un
## dash de varias, porque ambos son "avanzar en línea con el camino despejado". Si
## algún día hay un teleporte, será otro comando — precisamente porque *no* recorre
## el camino, y esa es toda la diferencia.
##
## No aplica `HAZARD`. El daño de terreno se resuelve una sola vez, en la fase 4 de
## la ronda (GDD §5), para que dé igual cómo acabaste ahí: andando, con un dash o
## empujado. Aplicarlo aquí lo cobraría dos veces cuando un empujón te mete en la lava.

var unit_id: int
var destination: Vector2i


func _init(p_unit_id: int, p_destination: Vector2i) -> void:
	unit_id = p_unit_id
	destination = p_destination


func validate(state: CombatState) -> bool:
	var unit := state.unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return false
	if not Grid.is_aligned(unit.position, destination):
		return false
	if not state.is_free(destination):
		return false

	# El camino tiene que estar despejado. `is_free()` deja pasar el vacío a
	# propósito: cruzar un abismo de un dash es legal, y termina exactamente como
	# uno esperaría. Ver `apply()`.
	for pos in Grid.line_between(unit.position, destination):
		if not state.is_free(pos):
			return false
	return true


## Recorre el camino casilla a casilla en vez de saltar al destino, porque el vacío
## puede interrumpirlo a mitad: si dashas cruzando un abismo, te caes en el abismo,
## no llegas al otro lado. `validate()` no lo impide —el movimiento es legal— y es
## `apply()` quien cuenta la verdad. La previsualización de targeting (1.26) muestra
## ese resultado real, así que el jugador nunca cae ahí por sorpresa.
func apply(state: CombatState) -> Array[Event]:
	var unit := state.unit_by_id(unit_id)
	var origin := unit.position
	var step := Grid.direction(origin, destination)

	var current := origin
	while current != destination:
		current += step
		if state.is_lethal(current):
			unit.position = current
			unit.kill()
			var fatal: Array[Event] = []
			fatal.append(UnitMoved.new(unit_id, origin, current))
			fatal.append(UnitDied.new(unit_id, UnitDied.Cause.FALL))
			return fatal

	unit.position = destination

	var events: Array[Event] = []
	events.append(UnitMoved.new(unit_id, origin, destination))
	return events
