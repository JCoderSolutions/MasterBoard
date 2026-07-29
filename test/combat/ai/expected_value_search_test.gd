extends GdUnitTestSuite

## Tests de ExpectedValueSearch: elegir por promedio contra las respuestas posibles del
## rival, no por el peor caso (backlog 1.17).

const ABILITIES_DIR := "res://resources/abilities"

var paso: Ability
var tajo: Ability
var muro: Ability


func before() -> void:
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	tajo = load("%s/tajo.tres" % ABILITIES_DIR)
	muro = load("%s/muro.tres" % ABILITIES_DIR)


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


# ── Es un promedio, no un peor caso ───────────────────────────────

## Tres respuestas del rival dan 10, 20 y 30: el promedio es 20, no 10 (el peor) ni 30
## (el mejor). Fija el algoritmo exacto, no solo "elige algo razonable".
func test_el_valor_de_una_jugada_es_el_promedio_de_las_respuestas() -> void:
	var choice_a := RoundChoice.new(1)
	var opponent_choices: Array[RoundChoice] = [
		RoundChoice.new(2), RoundChoice.new(2), RoundChoice.new(2),
	]

	var puntuaciones := [10.0, 20.0, 30.0]
	# GDScript captura los locales de un lambda **por valor** en el momento de crearlo
	# (un `int` normal quedaría congelado en 0 para siempre); un Array de un elemento
	# es la caja mutable de siempre para sortear eso.
	var i := [0]
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		var v: float = puntuaciones[i[0]]
		i[0] += 1
		return v

	var own_choices: Array[RoundChoice] = [choice_a]
	var elegida := ExpectedValueSearch.best_choice(
		CombatState.new(), 1, own_choices, 2, opponent_choices, evaluate,
	)

	assert_object(elegida).is_equal(choice_a)
	assert_int(i[0]).is_equal(3)  # se evaluó una vez por cada respuesta del rival


## Con dos jugadas propias donde la "arriesgada" es genial casi siempre pero un
## desastre contra una respuesta concreta, y la "segura" es decente contra todo, el
## promedio puede preferir la arriesgada. Es la prueba de que esto no es minimax: un
## minimax elegiría la segura por temor al peor caso.
##
## No hay forma limpia de que el evaluador sepa "qué own_choice se está probando" —por
## diseño solo ve el estado resultante—, así que se aprovecha que `best_choice` agota
## todas las respuestas del rival para una jugada propia antes de pasar a la siguiente
## (ver `ExpectedValueSearch._expected_value`): una secuencia fija de puntuaciones basta.
func test_prefiere_el_mejor_promedio_aunque_no_sea_el_mas_seguro() -> void:
	var arriesgada := RoundChoice.new(1)
	var segura := RoundChoice.new(1)
	var own_choices: Array[RoundChoice] = [segura, arriesgada]
	var opponent_choices: Array[RoundChoice] = [
		RoundChoice.new(2), RoundChoice.new(2), RoundChoice.new(2),
	]

	# best_choice recorre own_choices en orden y, para cada una, agota TODAS las
	# respuestas del rival antes de pasar a la siguiente (ver ExpectedValueSearch).
	# Una secuencia fija de puntuaciones basta para simular "segura" (10,10,10,
	# promedio 10) seguida de "arriesgada" (100,100,-50, promedio 50).
	var secuencia := [10.0, 10.0, 10.0, 100.0, 100.0, -50.0]
	var i := [0]  # caja mutable: ver el comentario del test anterior
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		var v: float = secuencia[i[0]]
		i[0] += 1
		return v

	var elegida := ExpectedValueSearch.best_choice(
		CombatState.new(), 1, own_choices, 2, opponent_choices, evaluate,
	)

	assert_object(elegida).is_equal(arriesgada)


# ── Empates: gana la primera en aparecer (A-03: determinista) ────

func test_en_empate_gana_la_primera_jugada() -> void:
	var primera := RoundChoice.new(1)
	var segunda := RoundChoice.new(1)
	var own_choices: Array[RoundChoice] = [primera, segunda]
	var opponent_choices: Array[RoundChoice] = [RoundChoice.new(2)]

	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		return 5.0

	var elegida := ExpectedValueSearch.best_choice(
		CombatState.new(), 1, own_choices, 2, opponent_choices, evaluate,
	)

	assert_object(elegida).is_equal(primera)


# ── Integración real: gana la partida sobre BoardEvaluation ─────

## Sin mocks: kit real, Round.resolve() real, BoardEvaluation real. Con un golpe letal
## disponible y ninguna forma de que el rival esquive matándose primero, la búsqueda
## tiene que encontrarlo.
func test_encuentra_el_golpe_letal_con_evaluacion_real() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := state.living_units(Unit.Team.ENEMY)[0]
	hero.hp = 3
	rival.hp = 2  # tajo (3 de daño) lo mata de un golpe

	var own_choices := ActionSpace.legal_choices(state, hero, [tajo, paso])
	var opponent_choices := ActionSpace.legal_choices(state, rival, [paso])

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, own_choices, rival.id, opponent_choices, BoardEvaluation.score,
	)

	assert_object(elegida.action).is_equal(tajo)
	assert_that(elegida.action_target).is_equal(rival.position)


## Sin evaluación (0.0 constante) sería indiferente entre morir y no morir. Con
## BoardEvaluation real, caminar al vacío pierde la partida y "quedarse quieto" no.
##
## Todos los movimientos de `paso` comparten la misma `Ability` —solo cambia el
## destino—, así que lo que hay que comprobar no es qué habilidad se eligió, sino a
## qué casilla: nunca debe ser la del vacío.
func test_evita_caminar_al_vacio_con_evaluacion_real() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 0))
	var hero := state.hero()
	var rival := state.living_units(Unit.Team.ENEMY)[0]
	state.set_terrain(Vector2i(2, 1), Terrain.Type.VOID)

	var own_choices := ActionSpace.legal_choices(state, hero, [paso])
	var opponent_choices := ActionSpace.legal_choices(state, rival, [paso])

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, own_choices, rival.id, opponent_choices, BoardEvaluation.score,
	)

	if elegida.movement != null:
		assert_that(elegida.movement_target).is_not_equal(Vector2i(2, 1))
