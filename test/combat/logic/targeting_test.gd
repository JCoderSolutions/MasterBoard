extends GdUnitTestSuite

## Tests de Targeting: qué casillas puede elegir una habilidad (backlog 1.8).


func _estado_con_heroe(pos: Vector2i = Vector2i(2, 2)) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, pos)
	return state


func _es_valida(
	state: CombatState,
	mode: Targeting.Mode,
	target: Vector2i,
	max_range: int = 1,
	los: bool = false,
) -> bool:
	return Targeting.is_valid(state, state.hero(), mode, target, max_range, los)


# ── SELF ────────────────────────────────────────────────────────

func test_self_solo_acepta_la_casilla_propia() -> void:
	var state := _estado_con_heroe()

	assert_bool(_es_valida(state, Targeting.Mode.SELF, Vector2i(2, 2))).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.SELF, Vector2i(2, 1))).is_false()
	assert_array(
		Targeting.valid_targets(state, state.hero(), Targeting.Mode.SELF, 0, false)
	).contains_exactly([Vector2i(2, 2)])


# ── UNIT ────────────────────────────────────────────────────────

func test_unit_exige_que_haya_alguien() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1))

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(2, 1))).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(3, 2))).is_false()


## El alcance se mide en Chebyshev, así que un adyacente en diagonal entra en alcance 1.
func test_el_alcance_incluye_las_diagonales() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(3, 3))

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(3, 3))).is_true()


func test_fuera_de_alcance_no_es_valido() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(4, 2))

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(4, 2), 1)).is_false()
	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(4, 2), 2)).is_true()


func test_una_unidad_muerta_no_es_objetivo() -> void:
	var state := _estado_con_heroe()
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1))
	rival.kill()

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(2, 1))).is_false()


# ── Línea de visión ─────────────────────────────────────────────

func test_pedir_linea_de_vision_exige_alineacion() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	state.add_unit(Unit.Team.ENEMY, Vector2i(1, 2))

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(1, 2), 3, false)).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(1, 2), 3, true)).is_false()


func test_un_muro_corta_la_linea_de_vision() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	state.add_unit(Unit.Team.ENEMY, Vector2i(3, 0))
	state.set_terrain(Vector2i(1, 0), Terrain.Type.WALL)

	assert_bool(_es_valida(state, Targeting.Mode.UNIT, Vector2i(3, 0), 3, true)).is_false()


# ── Casillas ────────────────────────────────────────────────────

func test_free_tile_rechaza_ocupadas_y_muros() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1))
	state.set_terrain(Vector2i(3, 2), Terrain.Type.WALL)

	assert_bool(_es_valida(state, Targeting.Mode.FREE_TILE, Vector2i(2, 3))).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.FREE_TILE, Vector2i(2, 1))).is_false()
	assert_bool(_es_valida(state, Targeting.Mode.FREE_TILE, Vector2i(3, 2))).is_false()


func test_ninguna_casilla_fuera_del_tablero_es_valida() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))

	assert_bool(_es_valida(state, Targeting.Mode.ANY_TILE, Vector2i(-1, 0))).is_false()


func test_any_tile_acepta_ocupadas_y_vacias() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1))

	assert_bool(_es_valida(state, Targeting.Mode.ANY_TILE, Vector2i(2, 1))).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.ANY_TILE, Vector2i(2, 3))).is_true()


# ── REACHABLE_TILE (dash) ───────────────────────────────────────

## El motivo de que este modo exista: con FREE_TILE, la previsualización pintaría
## casillas como (1, 0) desde (2, 2) —distancia Chebyshev 2— que el movimiento luego
## rechaza por no estar alineadas. El jugador tocaría y no pasaría nada.
func test_reachable_rechaza_lo_que_el_movimiento_rechazaria() -> void:
	var state := _estado_con_heroe()

	assert_bool(_es_valida(state, Targeting.Mode.FREE_TILE, Vector2i(1, 0), 2)).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.REACHABLE_TILE, Vector2i(1, 0), 2)).is_false()


func test_reachable_acepta_lineas_despejadas() -> void:
	var state := _estado_con_heroe()

	assert_bool(_es_valida(state, Targeting.Mode.REACHABLE_TILE, Vector2i(4, 2), 2)).is_true()
	assert_bool(_es_valida(state, Targeting.Mode.REACHABLE_TILE, Vector2i(4, 4), 2)).is_true()


func test_reachable_no_atraviesa_unidades() -> void:
	var state := _estado_con_heroe()
	state.add_unit(Unit.Team.ENEMY, Vector2i(3, 2))

	assert_bool(_es_valida(state, Targeting.Mode.REACHABLE_TILE, Vector2i(4, 2), 2)).is_false()


# ── Enumeración ─────────────────────────────────────────────────

## La previsualización (1.26) y la IA (1.16) consumen esta lista, y tiene que coincidir
## casilla a casilla con `is_valid()` o el jugador verá objetivos que no puede tocar.
func test_valid_targets_coincide_con_is_valid() -> void:
	var state := _estado_con_heroe()
	state.set_terrain(Vector2i(3, 2), Terrain.Type.WALL)
	var hero := state.hero()

	var enumeradas := Targeting.valid_targets(
		state, hero, Targeting.Mode.REACHABLE_TILE, 2, false
	)

	for y in CombatState.GRID_HEIGHT:
		for x in CombatState.GRID_WIDTH:
			var pos := Vector2i(x, y)
			var esperada := Targeting.is_valid(
				state, hero, Targeting.Mode.REACHABLE_TILE, pos, 2, false
			)
			assert_that(enumeradas.has(pos)).is_equal(esperada)


func test_una_unidad_muerta_no_puede_apuntar_a_nada() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	hero.kill()

	assert_bool(_es_valida(state, Targeting.Mode.ANY_TILE, Vector2i(2, 1))).is_false()
	assert_array(
		Targeting.valid_targets(state, hero, Targeting.Mode.ANY_TILE, 2, false)
	).is_empty()
