extends GdUnitTestSuite

## Tests de MatchResult: fin de partida (backlog 1.13, R-06).

const ABILITIES_DIR := "res://resources/abilities"


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


func test_con_los_dos_vivos_la_partida_sigue() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))

	assert_int(MatchResult.evaluate(state)).is_equal(MatchResult.Type.ONGOING)
	assert_bool(MatchResult.is_over(state)).is_false()


func test_el_jugador_gana_si_el_rival_llega_a_cero() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	state.living_units(Unit.Team.ENEMY)[0].kill()

	assert_int(MatchResult.evaluate(state)).is_equal(MatchResult.Type.PLAYER_WINS)
	assert_bool(MatchResult.is_over(state)).is_true()


func test_el_rival_gana_si_el_jugador_llega_a_cero() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	state.hero().kill()

	assert_int(MatchResult.evaluate(state)).is_equal(MatchResult.Type.ENEMY_WINS)


## La regla exacta del GDD §4: "si ambos caen la misma ronda, empate".
func test_empate_si_los_dos_caen_a_la_vez() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	state.hero().kill()
	state.living_units(Unit.Team.ENEMY)[0].kill()

	assert_int(MatchResult.evaluate(state)).is_equal(MatchResult.Type.DRAW)
	assert_bool(MatchResult.is_over(state)).is_true()


## La prueba de que 1.9 ya deja esto listo: dos ataques simultáneos que se matan entre
## sí producen un empate real, no un ganador por accidente de orden.
func test_el_doble_ataque_letal_de_round_produce_empate() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 2), 3)
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1), 3)
	var tajo: Ability = load("%s/tajo.tres" % ABILITIES_DIR)

	var choices: Array[RoundChoice] = [
		RoundChoice.new(hero.id).act(tajo, Vector2i(2, 1)),
		RoundChoice.new(rival.id).act(tajo, Vector2i(2, 2)),
	]
	Round.resolve(state, choices)

	assert_int(MatchResult.evaluate(state)).is_equal(MatchResult.Type.DRAW)
