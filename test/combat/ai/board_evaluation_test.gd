extends GdUnitTestSuite

## Tests de BoardEvaluation: cuánto de bueno es un estado para una unidad (backlog 1.17).
##
## Es un placeholder deliberado — solo diferencia de vida en rondas no decisivas— y
## estos tests fijan ese contrato exacto para que 1.18 sepa qué está reemplazando y qué
## no debe romper (la parte de ganar/perder/empatar, que ya es definitiva).


func _estado(heroe_hp: int, rival_hp: int) -> Dictionary:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0), heroe_hp)
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4), rival_hp)
	return {"state": state, "hero": hero, "rival": rival}


func test_ganar_vale_mucho_mas_que_cualquier_diferencia_de_vida() -> void:
	var setup := _estado(10, 10)
	var hero: Unit = setup.hero
	setup.rival.kill()

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_greater(100.0)


func test_perder_vale_lo_mismo_en_negativo() -> void:
	var setup := _estado(10, 10)
	var hero: Unit = setup.hero
	hero.kill()

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_less(-100.0)


func test_el_empate_vale_cero() -> void:
	var setup := _estado(10, 10)
	var hero: Unit = setup.hero
	hero.kill()
	setup.rival.kill()

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_equal(0.0)


## La única señal en una ronda no decisiva: vida propia menos vida ajena. Es lo que
## 1.18 va a enriquecer con maná, peligro y casillas seguras, sin tocar esto.
func test_sin_decision_la_nota_es_la_diferencia_de_vida() -> void:
	var setup := _estado(7, 4)
	var hero: Unit = setup.hero

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_equal(3.0)


func test_la_nota_es_simetrica_segun_para_quien_se_mire() -> void:
	var setup := _estado(7, 4)
	var hero: Unit = setup.hero
	var rival: Unit = setup.rival

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_equal(3.0)
	assert_float(BoardEvaluation.score(setup.state, rival.id)).is_equal(-3.0)


func test_una_unidad_inexistente_puntua_muy_mal() -> void:
	var state := CombatState.new()

	assert_float(BoardEvaluation.score(state, 999)).is_less(-100.0)
