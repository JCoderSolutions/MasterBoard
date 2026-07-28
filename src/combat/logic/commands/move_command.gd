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


## Recorre el camino casilla a casilla en vez de saltar al destino, y avanza **lo que
## pueda**: se detiene contra el primer obstáculo y se cae si el camino cruza un abismo.
##
## Esa división es deliberada. `validate()` responde "¿puedo elegir esto?" y la usan el
## targeting y la previsualización (1.26). `apply()` responde "¿qué pasa de verdad?", y
## tiene que poder contar algo distinto porque **entre elegir y resolver el tablero
## cambia**: las barreras se levantan en la fase 1 y el movimiento es la 2, así que tu
## destino puede quedar tapado después de haberlo confirmado. Ahí el GDD §5 no te deja
## clavado, te deja detenido contra el muro.
##
## A diferencia de `Displacement`, chocar aquí **no hace daño**: caminar contra una pared
## por decisión propia no es lo mismo que que te estrellen contra ella.
func apply(state: CombatState) -> Array[Event]:
	var events: Array[Event] = []

	var unit := state.unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return events

	var origin := unit.position
	var step := Grid.direction(origin, destination)
	if step == Vector2i.ZERO:
		return events

	var current := origin
	while current != destination:
		var next := current + step
		if not state.is_free(next):
			break

		current = next
		if state.is_lethal(current):
			unit.position = current
			unit.kill()
			events.append(UnitMoved.new(unit_id, origin, current))
			events.append(UnitDied.new(unit_id, UnitDied.Cause.FALL))
			return events

	if current == origin:
		return events

	unit.position = current
	events.append(UnitMoved.new(unit_id, origin, current))
	return events
