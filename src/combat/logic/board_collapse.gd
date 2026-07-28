class_name BoardCollapse
extends RefCounted

## Presión temporal: desde la ronda 8, el anillo exterior del tablero se derrumba por
## capas (GDD §4).
##
## No vive dentro de `Round` ni de `CombatState.begin_round()`: es una reacción al
## **número de ronda**, no a las elecciones de los bandos ni al reparto de maná, y
## mezclar las tres cosas obligaría a leer las otras dos para entender esta. Quien
## orqueste las rondas (el bucle de partida, fase posterior) la llama junto a
## `begin_round()`, igual que `MatchResult` — mismo patrón, mismo motivo.
##
## **Por qué existe:** sin presión, dos jugadores que se leen bien pueden orbitar sin
## comprometerse indefinidamente. El derrumbe fuerza la resolución y hace que el
## posicionamiento tardío sea tenso en vez de cómodo.

const START_ROUND: int = 8


## Distancia al borde más cercano: 0 en el borde, sube hacia el centro. Es la misma idea
## que un anillo de cebolla, y por eso "capas" en el GDD se traduce en un número.
static func ring_of(pos: Vector2i) -> int:
	return mini(
		mini(pos.x, pos.y),
		mini(CombatState.GRID_WIDTH - 1 - pos.x, CombatState.GRID_HEIGHT - 1 - pos.y),
	)


## El anillo más interior **nunca** se derrumba. Un tablero es al menos esa casilla, o
## deja de ser un tablero de ajedrez y pasa a ser un cronómetro que mata a los dos.
static func max_ring() -> int:
	return mini(CombatState.GRID_WIDTH, CombatState.GRID_HEIGHT) / 2


## Qué anillo toca esta ronda, o -1 si a esta ronda no le toca ninguno. Un anillo por
## ronda desde `START_ROUND`: el de fuera primero, y de ahí hacia dentro.
static func ring_for_round(round_number: int) -> int:
	if round_number < START_ROUND:
		return -1
	var ring := round_number - START_ROUND
	return ring if ring < max_ring() else -1


## Derrumba el anillo que le toca a `state.round_number`, si le toca alguno, y mata a
## quien quede atrapado dentro.
##
## Idempotente: una casilla ya `VOID` no vuelve a contarse, así que llamar esto más de
## una vez en la misma ronda no repite el evento ni mata dos veces a nadie.
static func resolve(state: CombatState) -> Array[Event]:
	var events: Array[Event] = []

	var ring := ring_for_round(state.round_number)
	if ring < 0:
		return events

	var collapsed: Array[Vector2i] = []
	for y in CombatState.GRID_HEIGHT:
		for x in CombatState.GRID_WIDTH:
			var pos := Vector2i(x, y)
			if ring_of(pos) != ring:
				continue
			if state.terrain_at(pos) == Terrain.Type.VOID:
				continue
			state.set_terrain(pos, Terrain.Type.VOID)
			collapsed.append(pos)

	if collapsed.is_empty():
		return events

	events.append(BoardCollapsed.new(collapsed))
	for unit in state.units:
		if unit.is_alive() and collapsed.has(unit.position):
			unit.kill()
			events.append(UnitDied.new(unit.id, UnitDied.Cause.FALL))
	return events
