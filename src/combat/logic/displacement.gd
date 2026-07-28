class_name Displacement
extends RefCounted

## Movimiento **forzado**: empujar y tirar de una unidad (GDD §5, §6). Reglas puras.
##
## No es un `Command` a propósito. Un empuje nunca lo elige el jugador directamente —es
## la consecuencia de una habilidad— y `validate()` no tendría nada que validar: un
## empuje bloqueado no es un movimiento ilegal, es un empuje que hace daño. Los efectos
## `.tres` de la familia Desplazamiento (backlog 1.8) llaman a esto.
##
## `MoveCommand` no se reescribe encima de esto aunque se parezcan: allí `validate()`
## garantiza el camino despejado, así que su `apply()` nunca se detiene salvo por vacío
## y nunca cobra impacto. Unificarlos con un flag "párate-y-haz-daño" sería más
## enrevesado que las diez líneas que comparten.

## Daño por chocar (GDD §5). Es lo que hace que empujar valga el maná en una arena sin
## vacío: sin impacto, el empuje es reposicionamiento puro y en un 5×5 cerrado eso rara
## vez paga.
const IMPACT_DAMAGE: int = 1


## Empuja una unidad `distance` casillas en `direction`, y narra lo que ocurrió.
##
## Toma una dirección y no una casilla destino, y eso da el **tirón gratis**: tirar es
## `push(state, id, -dir, dist)`. La dirección se obtiene con `Grid.direction()`.
##
## Al chocar, la unidad avanza lo que pueda y recibe `IMPACT_DAMAGE`. Que avance cero
## casillas —ya estaba pegada al muro— también cuenta como choque: acorralar a alguien
## contra un borde tiene que ser una posición perdedora, no un empuje desperdiciado.
##
## Si el obstáculo es otra unidad, **las dos** reciben el impacto. La que bloquea no se
## desplaza: encadenar empujes haría que una habilidad barata moviera media arena, y
## sobre todo lo volvería imposible de previsualizar antes de confirmar (R-07).
static func push(
	state: CombatState,
	unit_id: int,
	direction: Vector2i,
	distance: int,
) -> Array[Event]:
	var events: Array[Event] = []

	var unit := state.unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return events
	if direction == Vector2i.ZERO or distance <= 0:
		return events

	# Solo existen las 8 direcciones (ver `Grid.is_aligned`). Normalizar aquí evita que
	# un `Vector2i(3, 0)` mal construido empuje tres veces más lejos de lo que se pidió.
	var step := Vector2i(signi(direction.x), signi(direction.y))

	var origin := unit.position
	var current := origin
	var blocker: Unit = null
	var blocked := false

	for _i in distance:
		var next := current + step

		# Fuera del tablero `terrain_at()` devuelve WALL, así que el borde frena el
		# empuje igual que un muro sin necesitar un caso especial (A-13).
		if not state.is_walkable(next):
			blocked = true
			break

		var occupant := state.unit_at(next)
		if occupant != null:
			blocked = true
			blocker = occupant
			break

		current = next

		# El vacío interrumpe el empujón a mitad, igual que interrumpe un dash. No hay
		# daño de impacto: no chocó contra nada, se cayó.
		if state.is_lethal(current):
			unit.position = current
			unit.kill()
			events.append(UnitMoved.new(unit_id, origin, current))
			events.append(UnitDied.new(unit_id, UnitDied.Cause.FALL))
			return events

	if current != origin:
		unit.position = current
		events.append(UnitMoved.new(unit_id, origin, current))

	if blocked:
		events.append_array(Damage.apply(unit, IMPACT_DAMAGE))
		# El bloqueador cobra aunque el empujón lo mate: la casilla se libera después de
		# resolver, no a mitad, así que el empujado tampoco sigue avanzando.
		if blocker != null:
			events.append_array(Damage.apply(blocker, IMPACT_DAMAGE))

	return events
