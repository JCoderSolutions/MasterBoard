class_name Targeting
extends RefCounted

## Qué casillas puede elegir una habilidad (A-04). Funciones puras.
##
## Vive separado de `Ability` porque lo consumen tres sitios muy distintos: la propia
## habilidad al validar, la IA al enumerar su espacio de acciones legales (backlog 1.16)
## y la previsualización táctil al pintar las casillas válidas (1.26). Los tres tienen
## que coincidir exactamente o el jugador verá casillas que no puede tocar.

enum Mode {
	SELF,            ## Sin objetivo. Afecta a quien la lanza
	UNIT,            ## Casilla ocupada por una unidad viva
	FREE_TILE,       ## Casilla transitable y vacía (colocar un muro)
	ANY_TILE,        ## Cualquier casilla del tablero
	REACHABLE_TILE,  ## Casilla a la que se puede llegar de un tirón (dash)
}


## `max_range` y no `range` porque `range()` es función incorporada de GDScript y
## sombrearla silenciaría llamadas legítimas. Mismo motivo que `round_number` y
## `rng_seed` en `CombatState`.
##
## El alcance se mide en distancia Chebyshev: "a 2 de distancia" incluye las esquinas,
## que es como se lee un alcance mirando el tablero.
static func is_valid(
	state: CombatState,
	caster: Unit,
	mode: Mode,
	target: Vector2i,
	max_range: int,
	requires_line_of_sight: bool,
) -> bool:
	if caster == null or not caster.is_alive():
		return false

	if mode == Mode.SELF:
		return target == caster.position

	if not state.is_inside(target):
		return false
	if Grid.chebyshev_distance(caster.position, target) > max_range:
		return false

	# Pedir línea de visión implica exigir alineación: `has_line_of_sight()` la
	# comprueba. Es lo que separa un disparo en línea de un golpe de área.
	if requires_line_of_sight and not state.has_line_of_sight(caster.position, target):
		return false

	match mode:
		Mode.UNIT:
			return state.is_occupied(target)
		Mode.FREE_TILE:
			return state.is_free(target)
		Mode.ANY_TILE:
			return true
		Mode.REACHABLE_TILE:
			# Se pregunta al propio `MoveCommand` en vez de reimplementar "alineada,
			# libre y con el camino despejado". Copiar esas tres condiciones aquí
			# significaría que el día que el movimiento cambie, la previsualización
			# seguiría pintando las casillas viejas. Así no pueden desincronizarse.
			return MoveCommand.new(caster.id, target).validate(state)
	return false


## Todas las casillas elegibles. Recorre el tablero entero a lo bruto porque son 25
## casillas: cualquier estructura más lista costaría más de mantener que de ejecutar,
## incluso con la IA llamando a esto miles de veces por ronda.
static func valid_targets(
	state: CombatState,
	caster: Unit,
	mode: Mode,
	max_range: int,
	requires_line_of_sight: bool,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if caster == null or not caster.is_alive():
		return result

	if mode == Mode.SELF:
		result.append(caster.position)
		return result

	for y in CombatState.GRID_HEIGHT:
		for x in CombatState.GRID_WIDTH:
			var pos := Vector2i(x, y)
			if is_valid(state, caster, mode, pos, max_range, requires_line_of_sight):
				result.append(pos)
	return result
