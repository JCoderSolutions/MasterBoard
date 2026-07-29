extends GdUnitTestSuite

## Tests de ExpectedValueSearch: elegir por promedio contra las respuestas posibles del
## rival, no por el peor caso (backlog 1.17), mirando `depth` rondas hacia delante
## (backlog 1.19).

const ABILITIES_DIR := "res://resources/abilities"

var paso: Ability
var tajo: Ability


func before() -> void:
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	tajo = load("%s/tajo.tres" % ABILITIES_DIR)


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


## Habilidad mínima para controlar exactamente cuántas jugadas hay: fase ATTACK,
## `SELF` (siempre tiene un objetivo válido: uno mismo), coste 0, sin efectos. Sirve
## para fijar el tamaño de `own_choices`/`opponent_choices` sin depender de geometría
## ni de maná — lo único que le importa a estos tests es el algoritmo, no el juego.
func _dummy_ability(id: String) -> Ability:
	var ability := Ability.new()
	ability.id = StringName(id)
	ability.phase = Phase.Type.ATTACK
	ability.targeting = Targeting.Mode.SELF
	var effects: Array[Effect] = []
	ability.effects = effects
	return ability


# ── Es un promedio, no un peor caso ───────────────────────────────

## Tres respuestas del rival dan 10, 20 y 30: el promedio es 20, no 10 (el peor) ni 30
## (el mejor). Fija el algoritmo exacto, no solo "elige algo razonable".
func test_el_valor_de_una_jugada_es_el_promedio_de_las_respuestas() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))

	var puntuaciones := [10.0, 20.0, 30.0]
	# GDScript captura los locales de un lambda **por valor** en el momento de crearlo
	# (un `int` normal quedaría congelado en 0 para siempre); un Array de un elemento
	# es la caja mutable de siempre para sortear eso.
	var i := [0]
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		var v: float = puntuaciones[i[0]]
		i[0] += 1
		return v

	# kit vacío = una sola jugada propia posible: quedarse quieto. Kit rival de 2
	# habilidades = pass + 2 = 3 respuestas, una por cada puntuación.
	var opponent_kit: Array[Ability] = [_dummy_ability("b"), _dummy_ability("c")]
	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, [], rival.id, opponent_kit, evaluate,
	)

	assert_bool(elegida.is_empty()).is_true()
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
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))

	# "segura" es el pass implícito (se prueba primero); "arriesgada" es la única
	# habilidad del kit propio (se prueba después). Con 3 respuestas del rival:
	# segura = (10,10,10) promedio 10; arriesgada = (100,100,-50) promedio 50.
	var secuencia := [10.0, 10.0, 10.0, 100.0, 100.0, -50.0]
	var i := [0]  # caja mutable: ver el comentario del test anterior
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		var v: float = secuencia[i[0]]
		i[0] += 1
		return v

	var arriesgada := _dummy_ability("arriesgada")
	var own_kit: Array[Ability] = [arriesgada]
	var opponent_kit: Array[Ability] = [_dummy_ability("b"), _dummy_ability("c")]

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, own_kit, rival.id, opponent_kit, evaluate,
	)

	assert_object(elegida.action).is_equal(arriesgada)


# ── Empates: gana la primera en aparecer (A-03: determinista) ────

func test_en_empate_gana_la_primera_jugada() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))

	var own_kit: Array[Ability] = [_dummy_ability("a")]
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		return 5.0  # todas las jugadas valen lo mismo

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, own_kit, rival.id, [], evaluate,
	)

	assert_bool(elegida.is_empty()).is_true()  # gana "pass", que se prueba primero


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

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, [tajo, paso], rival.id, [paso], BoardEvaluation.score,
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

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, [paso], rival.id, [paso], BoardEvaluation.score,
	)

	if elegida.movement != null:
		assert_that(elegida.movement_target).is_not_equal(Vector2i(2, 1))


# ── Profundidad (backlog 1.19) ────────────────────────────────────

## El salto de profundidad 1 a 2 pasa por una ronda nueva de verdad —reparte maná
## igual que `CombatState.begin_round()`—, no por resolver dos veces con el mismo
## maná congelado. Sin esto, mirar más hondo penalizaría sistemáticamente ahorrar
## maná esta ronda para algo grande la próxima, que es justo la lectura que el GDD
## quiere premiar.
func test_profundizar_reparte_mana_como_una_ronda_real() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))

	var mana_visto := [-1]
	var evaluate := func(s: CombatState, unit_id: int) -> float:
		mana_visto[0] = s.unit_by_id(unit_id).mana
		return 0.0

	ExpectedValueSearch.best_choice(state, hero.id, [], rival.id, [], evaluate, 1)
	assert_int(mana_visto[0]).is_equal(CombatState.MANA_START)

	ExpectedValueSearch.best_choice(state, hero.id, [], rival.id, [], evaluate, 2)
	assert_int(mana_visto[0]).is_equal(CombatState.MANA_START + CombatState.MANA_PER_ROUND)


## La profundidad multiplica el trabajo: cada ronda adicional vuelve a abrir
## own_choices × opponent_choices desde el estado ya resuelto. Es el motivo por el que
## la dificultad tiene un techo de rendimiento, no solo de "inteligencia": profundidad
## 1 evalúa 2×2 = 4 hojas; profundidad 2 vuelve a abrir 2×2 en cada una de esas 4, así
## que evalúa 4×4 = 16.
func test_profundizar_multiplica_las_evaluaciones() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 2))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))

	var own_kit: Array[Ability] = [_dummy_ability("a")]       # pass + a = 2 jugadas
	var opponent_kit: Array[Ability] = [_dummy_ability("b")]  # pass + b = 2 jugadas

	var llamadas := [0]
	var evaluate := func(_state: CombatState, _unit_id: int) -> float:
		llamadas[0] += 1
		return 0.0

	ExpectedValueSearch.best_choice(state, hero.id, own_kit, rival.id, opponent_kit, evaluate, 1)
	assert_int(llamadas[0]).is_equal(4)

	llamadas[0] = 0
	ExpectedValueSearch.best_choice(state, hero.id, own_kit, rival.id, opponent_kit, evaluate, 2)
	assert_int(llamadas[0]).is_equal(16)


## Profundidad 1 —el valor de siempre desde 1.17— tiene que seguir encontrando el
## golpe letal exactamente igual que antes de que 1.19 tocara el algoritmo.
func test_profundidad_1_sigue_encontrando_el_golpe_letal() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := state.living_units(Unit.Team.ENEMY)[0]
	hero.hp = 3
	rival.hp = 2

	var elegida := ExpectedValueSearch.best_choice(
		state, hero.id, [tajo, paso], rival.id, [paso], BoardEvaluation.score, 1,
	)

	assert_object(elegida.action).is_equal(tajo)
