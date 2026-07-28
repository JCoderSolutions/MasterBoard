extends GdUnitTestSuite

## Tests de BoardCollapse: presión desde la ronda 8 (backlog 1.14, GDD §4).


func _en_ronda(state: CombatState, round_number: int) -> void:
	state.round_number = round_number


# ── Geometría de anillos ────────────────────────────────────────

func test_ring_of_en_las_esquinas_y_bordes() -> void:
	assert_int(BoardCollapse.ring_of(Vector2i(0, 0))).is_equal(0)
	assert_int(BoardCollapse.ring_of(Vector2i(4, 4))).is_equal(0)
	assert_int(BoardCollapse.ring_of(Vector2i(2, 0))).is_equal(0)


func test_ring_of_en_el_anillo_intermedio() -> void:
	assert_int(BoardCollapse.ring_of(Vector2i(1, 1))).is_equal(1)
	assert_int(BoardCollapse.ring_of(Vector2i(3, 1))).is_equal(1)


## El anillo interior nunca se cuenta como parte de una capa exterior: un tablero es al
## menos esa casilla o deja de ser un tablero.
func test_ring_of_en_el_centro() -> void:
	assert_int(BoardCollapse.ring_of(Vector2i(2, 2))).is_equal(2)
	assert_int(BoardCollapse.max_ring()).is_equal(2)


# ── Cuándo toca ─────────────────────────────────────────────────

func test_antes_de_la_ronda_8_no_toca_ningun_anillo() -> void:
	assert_int(BoardCollapse.ring_for_round(1)).is_equal(-1)
	assert_int(BoardCollapse.ring_for_round(7)).is_equal(-1)


func test_el_anillo_exterior_le_toca_a_la_ronda_8() -> void:
	assert_int(BoardCollapse.ring_for_round(8)).is_equal(0)


func test_el_siguiente_anillo_le_toca_a_la_ronda_9() -> void:
	assert_int(BoardCollapse.ring_for_round(9)).is_equal(1)


## El centro nunca le toca a ninguna ronda, ni aunque la partida se alargue muchísimo.
func test_el_centro_nunca_le_toca_a_ninguna_ronda() -> void:
	for round_number in [10, 20, 100]:
		assert_int(BoardCollapse.ring_for_round(round_number)).is_equal(-1)


# ── Derrumbe ────────────────────────────────────────────────────

func test_antes_de_la_ronda_8_no_pasa_nada() -> void:
	var state := CombatState.new()
	_en_ronda(state, 7)

	assert_array(BoardCollapse.resolve(state)).is_empty()
	assert_int(state.terrain_at(Vector2i(0, 0))).is_equal(Terrain.Type.FLOOR)


func test_la_ronda_8_derrumba_las_16_casillas_del_borde() -> void:
	var state := CombatState.new()
	_en_ronda(state, 8)

	var events := BoardCollapse.resolve(state)

	assert_int(state.terrain_at(Vector2i(0, 0))).is_equal(Terrain.Type.VOID)
	assert_int(state.terrain_at(Vector2i(2, 0))).is_equal(Terrain.Type.VOID)
	assert_int(state.terrain_at(Vector2i(1, 1))).is_equal(Terrain.Type.FLOOR)  # anillo 1, se queda
	assert_int(state.terrain_at(Vector2i(2, 2))).is_equal(Terrain.Type.FLOOR)  # centro
	assert_array(events).has_size(1)
	assert_int((events[0] as BoardCollapsed).positions.size()).is_equal(16)


func test_la_ronda_9_derrumba_el_siguiente_anillo() -> void:
	var state := CombatState.new()
	_en_ronda(state, 9)

	var events := BoardCollapse.resolve(state)

	assert_int(state.terrain_at(Vector2i(1, 1))).is_equal(Terrain.Type.VOID)
	assert_int(state.terrain_at(Vector2i(2, 2))).is_equal(Terrain.Type.FLOOR)
	assert_int((events[0] as BoardCollapsed).positions.size()).is_equal(8)


## El criterio de aceptación de 1.14, literal: una unidad atrapada por el derrumbe muere.
func test_una_unidad_atrapada_por_el_derrumbe_muere() -> void:
	var state := CombatState.new()
	var unit := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 2))
	_en_ronda(state, 8)

	var events := BoardCollapse.resolve(state)

	assert_bool(unit.is_alive()).is_false()
	assert_int(events.size()).is_equal(2)
	assert_int(events[0].type).is_equal(Event.Type.BOARD_COLLAPSED)
	var died: UnitDied = events[1]
	assert_int(died.cause).is_equal(UnitDied.Cause.FALL)


func test_una_unidad_fuera_del_anillo_no_se_ve_afectada() -> void:
	var state := CombatState.new()
	var unit := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 2))
	_en_ronda(state, 8)

	BoardCollapse.resolve(state)

	assert_bool(unit.is_alive()).is_true()


## Sin esto, una unidad ya caída volvería a emitir su muerte cada vez que se llamara.
func test_una_unidad_ya_muerta_no_emite_una_segunda_muerte() -> void:
	var state := CombatState.new()
	var unit := state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	unit.kill()
	_en_ronda(state, 8)

	var events := BoardCollapse.resolve(state)

	assert_int(events.size()).is_equal(1)  # solo BoardCollapsed


## Llamarlo dos veces en la misma ronda no repite el derrumbe: las casillas ya son
## VOID y quien murió ya no puede volver a morir.
func test_llamarlo_dos_veces_en_la_misma_ronda_no_duplica_nada() -> void:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))
	_en_ronda(state, 8)

	BoardCollapse.resolve(state)
	var events := BoardCollapse.resolve(state)

	assert_array(events).is_empty()
