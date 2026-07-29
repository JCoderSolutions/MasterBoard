extends GdUnitTestSuite

## Tests de BoardCoordinates: conversión entre grilla lógica y píxeles (backlog 1.20).


func test_to_pixel_es_la_esquina_de_la_casilla() -> void:
	assert_that(BoardCoordinates.to_pixel(Vector2i(0, 0))).is_equal(Vector2.ZERO)
	assert_that(BoardCoordinates.to_pixel(Vector2i(2, 3))).is_equal(
		Vector2(2 * BoardCoordinates.CELL_SIZE, 3 * BoardCoordinates.CELL_SIZE)
	)


func test_to_pixel_center_esta_a_medio_tile_de_la_esquina() -> void:
	var mitad := BoardCoordinates.CELL_SIZE / 2.0

	assert_that(BoardCoordinates.to_pixel_center(Vector2i(0, 0))).is_equal(Vector2(mitad, mitad))
	assert_that(BoardCoordinates.to_pixel_center(Vector2i(1, 0))).is_equal(
		Vector2(BoardCoordinates.CELL_SIZE + mitad, mitad)
	)


## El sentido contrario: cualquier punto dentro de la casilla —esquina, centro o
## borde antes del siguiente tile— tiene que caer en la misma casilla.
func test_to_grid_es_el_inverso_de_to_pixel() -> void:
	var pos := Vector2i(3, 2)
	var esquina := BoardCoordinates.to_pixel(pos)
	var centro := BoardCoordinates.to_pixel_center(pos)
	var casi_el_borde := esquina + Vector2(BoardCoordinates.CELL_SIZE - 1, BoardCoordinates.CELL_SIZE - 1)

	assert_that(BoardCoordinates.to_grid(esquina)).is_equal(pos)
	assert_that(BoardCoordinates.to_grid(centro)).is_equal(pos)
	assert_that(BoardCoordinates.to_grid(casi_el_borde)).is_equal(pos)


## El primer píxel del siguiente tile ya no pertenece a este.
func test_to_grid_no_se_pasa_al_siguiente_tile() -> void:
	var siguiente := BoardCoordinates.to_pixel(Vector2i(1, 0))

	assert_that(BoardCoordinates.to_grid(siguiente)).is_equal(Vector2i(1, 0))
	assert_that(BoardCoordinates.to_grid(siguiente - Vector2(1, 0))).is_equal(Vector2i(0, 0))


## Coordenadas negativas (fuera del tablero por arriba/izquierda) truncan hacia
## abajo, no hacia cero: es la diferencia entre floor y una división entera ingenua.
func test_to_grid_trunca_hacia_abajo_con_coordenadas_negativas() -> void:
	assert_that(BoardCoordinates.to_grid(Vector2(-1, -1))).is_equal(Vector2i(-1, -1))
	assert_that(BoardCoordinates.to_grid(Vector2(-0.5, -0.5))).is_equal(Vector2i(-1, -1))
