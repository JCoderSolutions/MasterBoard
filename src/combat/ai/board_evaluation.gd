class_name BoardEvaluation
extends RefCounted

## Cuánto de bueno es un `CombatState` para una unidad (insumo de
## `ExpectedValueSearch`). Positivo es bueno para `unit_id`, negativo es malo.
##
## Ganar, perder y empatar son definitivos —se apoyan en `MatchResult`, la autoridad
## sobre eso desde 1.13— y esa rama no cambia. Lo que sigue vivo en cada ronda no
## decisiva son las cuatro señales del backlog 1.18: **vida, maná, proximidad a
## peligro y casillas seguras disponibles.** Los pesos relativos entre ellas son una
## asunción de diseño, no un número que el GDD fije — quedan pendientes de playtest,
## igual que los números de maná y vida (D-04, D-05).

## La vida es la moneda real de la partida: el resto de señales solo importan porque
## acaban convirtiéndose en vida más adelante. Por eso pesa 1 y las demás pesan menos.
const MANA_WEIGHT: float = 0.5

## Más que la vida en el margen —cornerear a alguien cerca de un peligro suele valer
## más que un golpe suelto— pero sin dominar por completo la lectura.
const HAZARD_WEIGHT: float = 1.5

const SAFE_TILES_WEIGHT: float = 0.25


static func score(state: CombatState, unit_id: int) -> float:
	var unit := state.unit_by_id(unit_id)
	if unit == null:
		return -1000.0

	match MatchResult.evaluate(state):
		MatchResult.Type.DRAW:
			return 0.0
		MatchResult.Type.PLAYER_WINS:
			return 1000.0 if unit.team == Unit.Team.PLAYER else -1000.0
		MatchResult.Type.ENEMY_WINS:
			return 1000.0 if unit.team == Unit.Team.ENEMY else -1000.0
		_:
			pass  # ONGOING: la partida sigue, hace falta una señal más fina.

	var opponents := state.living_units(Unit.opposing_team(unit.team))

	# Se agrega el total del bando rival y se compara **una sola vez** contra el
	# propio, no una vez por rival — sumar por rival duplicaría el valor de `unit` en
	# cuanto haya más de uno enfrente (post-MVP, 2v2). En 1v1 da igual: hay como mucho
	# un rival y las dos formas coinciden.
	var opponent_hp := 0
	var opponent_mana := 0
	var opponent_hazard := 0.0
	var opponent_safe_tiles := 0
	for opponent in opponents:
		opponent_hp += opponent.hp
		opponent_mana += opponent.mana
		opponent_hazard += _hazard_exposure(state, opponent.position)
		opponent_safe_tiles += _safe_neighbors(state, opponent.position)

	var value := float(unit.hp - opponent_hp)
	value += MANA_WEIGHT * float(unit.mana - opponent_mana)
	value += HAZARD_WEIGHT * (opponent_hazard - _hazard_exposure(state, unit.position))
	value += SAFE_TILES_WEIGHT * float(_safe_neighbors(state, unit.position) - opponent_safe_tiles)
	return value


## Cuán expuesta está una casilla al peligro del tablero: 1 por estar **sobre**
## `HAZARD` —volverá a doler la próxima ronda si nadie se mueve—, y una fracción por
## cada vecino `VOID` u `HAZARD` —el rival podría empujar hacia ahí—. Una unidad viva
## nunca está parada sobre `VOID`: entrar ahí mata en el acto (`MoveCommand`,
## `Displacement`), así que ese caso no hace falta comprobarlo aparte.
static func _hazard_exposure(state: CombatState, pos: Vector2i) -> float:
	var exposure := 0.0
	if state.terrain_at(pos) == Terrain.Type.HAZARD:
		exposure += 1.0

	for neighbor in Grid.all_neighbors(pos):
		if state.is_inside(neighbor) and state.is_lethal(neighbor):
			exposure += 0.25
	return exposure


## Cuántas de las 8 casillas alrededor sirven de vía de escape: transitables, sin
## nadie encima y sin peligro. Pocas casillas seguras es estar acorralado, aunque
## nadie te haya tocado todavía.
static func _safe_neighbors(state: CombatState, pos: Vector2i) -> int:
	var count := 0
	for neighbor in Grid.all_neighbors(pos):
		if not state.is_inside(neighbor):
			continue
		if not state.is_free(neighbor):
			continue
		if state.is_lethal(neighbor) or state.terrain_at(neighbor) == Terrain.Type.HAZARD:
			continue
		count += 1
	return count
