extends GdUnitTestSuite

## Tests de BoardEvaluation: cuánto de bueno es un estado para una unidad (backlog
## 1.17-1.18). Ganar/perder/empatar son definitivos (`MatchResult`, 1.13) y no cambian;
## en rondas no decisivas la nota combina vida, maná, proximidad a peligro y casillas
## seguras disponibles — las cuatro señales que pedía 1.18.


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


## Dos esquinas opuestas del tablero por defecto son simétricas en maná, peligro y
## casillas seguras (3 vecinas libres cada una): lo único que queda es la vida.
func test_en_un_tablero_simetrico_la_nota_es_la_diferencia_de_vida() -> void:
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


# ── Maná (backlog 1.18) ───────────────────────────────────────────

## Tener más maná que el rival pesa menos que la vida —el maná es tempo y opciones, no
## la moneda con la que se gana la partida— pero sí suma.
func test_mas_mana_que_el_rival_suma_puntos() -> void:
	var setup := _estado(5, 5)
	var hero: Unit = setup.hero
	var rival: Unit = setup.rival
	hero.mana = 6
	rival.mana = 2

	var esperado := BoardEvaluation.MANA_WEIGHT * float(hero.mana - rival.mana)
	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_equal(esperado)


# ── Proximidad a peligro (backlog 1.18) ──────────────────────────

## Estar parado sobre `HAZARD` no hace daño ahora mismo —eso ya lo cobró la fase de
## terreno de la ronda que se acaba de resolver— pero volverá a doler la próxima si
## nadie se mueve, y por eso la evaluación lo penaliza ya.
func test_estar_sobre_un_peligro_resta_puntos() -> void:
	var setup := _estado(5, 5)
	var hero: Unit = setup.hero
	setup.state.set_terrain(hero.position, Terrain.Type.HAZARD)

	assert_float(BoardEvaluation.score(setup.state, hero.id)).is_equal(-BoardEvaluation.HAZARD_WEIGHT)


## Que el rival esté sobre un peligro pesa exactamente igual pero en sentido
## contrario: su exposición es tu ventaja, no solo la ausencia de la tuya.
func test_que_el_rival_este_sobre_un_peligro_suma_puntos() -> void:
	var setup := _estado(5, 5)
	var rival: Unit = setup.rival
	setup.state.set_terrain(rival.position, Terrain.Type.HAZARD)

	assert_float(BoardEvaluation.score(setup.state, setup.hero.id)) \
		.is_equal(BoardEvaluation.HAZARD_WEIGHT)


## Un vecino en `VOID` penaliza por dos señales a la vez: es un sitio al que te
## pueden empujar (peligro) y además deja de contar como vía de escape (casillas
## seguras). Son señales independientes que aquí coinciden sobre el mismo tablero.
func test_un_vecino_en_el_vacio_penaliza_por_dos_senales() -> void:
	var setup := _estado(5, 5)
	var hero: Unit = setup.hero
	setup.state.set_terrain(Vector2i(1, 0), Terrain.Type.VOID)  # vecino de (0, 0)

	var penalizacion_peligro := BoardEvaluation.HAZARD_WEIGHT * 0.25
	var penalizacion_escape := BoardEvaluation.SAFE_TILES_WEIGHT
	assert_float(BoardEvaluation.score(setup.state, hero.id)) \
		.is_equal(-penalizacion_peligro - penalizacion_escape)


# ── Casillas seguras disponibles (backlog 1.18) ──────────────────

## Un muro no es peligro —`is_lethal` solo mira `VOID`— pero sí quita una vía de
## escape: la señal de casillas seguras es independiente de la de peligro.
func test_un_muro_vecino_resta_una_via_de_escape_sin_ser_peligro() -> void:
	var setup := _estado(5, 5)
	var hero: Unit = setup.hero
	setup.state.set_terrain(Vector2i(1, 0), Terrain.Type.WALL)

	assert_float(BoardEvaluation.score(setup.state, hero.id)) \
		.is_equal(-BoardEvaluation.SAFE_TILES_WEIGHT)


# ── Varios rivales: no se duplica la propia señal ────────────────

## Fuera del alcance del MVP 1v1, pero la fórmula tiene que aguantarlo sin doblar el
## propio valor por cada rival: cada señal del bando contrario se **suma una vez** y
## se compara contra la propia una sola vez, no una vez por cada rival por separado.
## Si se sumara por rival, el maná daría (3-3)+(3-3)=0 en vez de 3-(3+3)=-3 — la
## diferencia entre las dos fórmulas es exactamente lo que este test fija.
func test_con_varios_rivales_no_se_duplica_la_propia_senal() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 2), 10)
	state.add_unit(Unit.Team.ENEMY, Vector2i(0, 0), 3)
	state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4), 3)

	# Vida: 10 - (3+3) = 4. Maná: 3 (el de hero, MANA_START) - (3+3) = -3. Peligro: sin
	# terreno especial, cero en todos. Escape: hero en el centro tiene 8 vecinos
	# libres; los rivales en sus esquinas suman 3+3=6.
	var esperado := 4.0 \
		+ BoardEvaluation.MANA_WEIGHT * -3.0 \
		+ BoardEvaluation.SAFE_TILES_WEIGHT * float(8 - (3 + 3))
	assert_float(BoardEvaluation.score(state, hero.id)).is_equal(esperado)
