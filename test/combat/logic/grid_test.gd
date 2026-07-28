extends GdUnitTestSuite

## Tests de Grid y de la línea de visión de CombatState (backlog 1.5).


# ── Distancias ──────────────────────────────────────────────────

func test_distancia_manhattan_cuenta_pasos_ortogonales() -> void:
	assert_int(Grid.manhattan_distance(Vector2i(0, 0), Vector2i(0, 0))).is_equal(0)
	assert_int(Grid.manhattan_distance(Vector2i(0, 0), Vector2i(3, 0))).is_equal(3)
	assert_int(Grid.manhattan_distance(Vector2i(0, 0), Vector2i(2, 2))).is_equal(4)
	assert_int(Grid.manhattan_distance(Vector2i(4, 4), Vector2i(1, 2))).is_equal(5)


## La diferencia entre las dos distancias es lo que separa "a cuántos pasos está"
## de "si está en mi alcance".
func test_distancia_chebyshev_permite_diagonal() -> void:
	assert_int(Grid.chebyshev_distance(Vector2i(0, 0), Vector2i(2, 2))).is_equal(2)
	assert_int(Grid.chebyshev_distance(Vector2i(0, 0), Vector2i(3, 1))).is_equal(3)


# ── Adyacencia ──────────────────────────────────────────────────

func test_adyacencia_ortogonal_excluye_diagonales() -> void:
	var centro := Vector2i(2, 2)

	assert_bool(Grid.is_orthogonally_adjacent(centro, Vector2i(2, 1))).is_true()
	assert_bool(Grid.is_orthogonally_adjacent(centro, Vector2i(3, 2))).is_true()
	assert_bool(Grid.is_orthogonally_adjacent(centro, Vector2i(3, 3))).is_false()
	assert_bool(Grid.is_orthogonally_adjacent(centro, Vector2i(2, 2))).is_false()


func test_adyacencia_general_incluye_diagonales() -> void:
	var centro := Vector2i(2, 2)

	assert_bool(Grid.is_adjacent(centro, Vector2i(3, 3))).is_true()
	assert_bool(Grid.is_adjacent(centro, Vector2i(1, 3))).is_true()
	assert_bool(Grid.is_adjacent(centro, Vector2i(4, 2))).is_false()


## Una casilla no es adyacente a sí misma, aunque su distancia sea 0.
func test_una_casilla_no_es_adyacente_a_si_misma() -> void:
	assert_bool(Grid.is_adjacent(Vector2i(2, 2), Vector2i(2, 2))).is_false()


func test_vecinos() -> void:
	assert_array(Grid.orthogonal_neighbors(Vector2i(2, 2))).has_size(4)
	assert_array(Grid.all_neighbors(Vector2i(2, 2))).has_size(8)
	assert_array(Grid.orthogonal_neighbors(Vector2i(2, 2))).contains_exactly_in_any_order([
		Vector2i(2, 1), Vector2i(3, 2), Vector2i(2, 3), Vector2i(1, 2),
	])


# ── Alineación y líneas ─────────────────────────────────────────

func test_alineacion_solo_en_las_ocho_direcciones() -> void:
	var origen := Vector2i(1, 1)

	assert_bool(Grid.is_aligned(origen, Vector2i(4, 1))).is_true()   # misma fila
	assert_bool(Grid.is_aligned(origen, Vector2i(1, 4))).is_true()   # misma columna
	assert_bool(Grid.is_aligned(origen, Vector2i(3, 3))).is_true()   # diagonal
	assert_bool(Grid.is_aligned(origen, Vector2i(3, 2))).is_false()  # salto de caballo
	assert_bool(Grid.is_aligned(origen, origen)).is_false()


func test_direccion_es_un_paso_unitario() -> void:
	assert_that(Grid.direction(Vector2i(1, 1), Vector2i(4, 1))).is_equal(Vector2i(1, 0))
	assert_that(Grid.direction(Vector2i(4, 4), Vector2i(4, 0))).is_equal(Vector2i(0, -1))
	assert_that(Grid.direction(Vector2i(0, 0), Vector2i(3, 3))).is_equal(Vector2i(1, 1))


## Sin alineación no hay dirección. Es lo que impide que un empuje "en diagonal rota"
## salga con una trayectoria que el jugador no podía prever.
func test_sin_alineacion_no_hay_direccion() -> void:
	assert_that(Grid.direction(Vector2i(0, 0), Vector2i(1, 2))).is_equal(Vector2i.ZERO)
	assert_that(Grid.direction(Vector2i(2, 2), Vector2i(2, 2))).is_equal(Vector2i.ZERO)


func test_linea_entre_excluye_los_extremos() -> void:
	assert_array(Grid.line_between(Vector2i(0, 0), Vector2i(4, 0))).contains_exactly([
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	])
	assert_array(Grid.line_between(Vector2i(0, 0), Vector2i(3, 3))).contains_exactly([
		Vector2i(1, 1), Vector2i(2, 2),
	])


func test_entre_dos_casillas_pegadas_no_hay_nada() -> void:
	assert_array(Grid.line_between(Vector2i(1, 1), Vector2i(1, 2))).is_empty()
	assert_array(Grid.line_between(Vector2i(0, 0), Vector2i(1, 2))).is_empty()


func test_ray_devuelve_casillas_sin_incluir_el_origen() -> void:
	assert_array(Grid.ray(Vector2i(0, 0), Vector2i(1, 0), 3)).contains_exactly([
		Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	])
	assert_array(Grid.ray(Vector2i(0, 0), Vector2i.ZERO, 3)).is_empty()
	assert_array(Grid.ray(Vector2i(0, 0), Vector2i(1, 0), 0)).is_empty()


## El ray se sale del tablero a propósito: Grid es geometría pura y no sabe dónde
## acaba el tablero. Recortar es trabajo de quien consulta, con CombatState.
func test_ray_no_conoce_los_limites_del_tablero() -> void:
	var casillas := Grid.ray(Vector2i(4, 0), Vector2i(1, 0), 2)

	assert_array(casillas).contains_exactly([Vector2i(5, 0), Vector2i(6, 0)])


# ── Línea de visión (CombatState) ───────────────────────────────

func test_linea_de_vision_despejada() -> void:
	var state := CombatState.new()

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0))).is_true()
	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(3, 3))).is_true()


## Sin esto una barrera no bloquearía disparos y dejaría de tener sentido (GDD §6).
func test_un_muro_bloquea_la_linea_de_vision() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(2, 0), Terrain.Type.WALL)

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0))).is_false()
	# El muro no bloquea lo que queda de su lado.
	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(1, 0))).is_true()


func test_las_unidades_no_bloquean_la_linea_de_vision() -> void:
	var state := CombatState.new()
	state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0))

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0))).is_true()


func test_el_vacio_y_los_peligros_no_bloquean() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(2, 0), Terrain.Type.VOID)
	state.set_terrain(Vector2i(3, 0), Terrain.Type.HAZARD)

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0))).is_true()


func test_sin_alineacion_no_hay_linea_de_vision() -> void:
	var state := CombatState.new()

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(1, 2))).is_false()
