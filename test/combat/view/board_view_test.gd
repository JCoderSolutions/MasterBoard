extends GdUnitTestSuite

## Tests de BoardView: refleja el terreno de CombatState en el TileMapLayer (backlog
## 1.20). No hace falta montar la escena en el árbol: `set_cell()`/`get_cell_*()`
## escriben y leen datos del nodo directamente, sin depender de estar dentro del
## SceneTree.


func test_carga_el_tileset_de_cuatro_tiles_al_construirse() -> void:
	var view := BoardView.new()

	assert_object(view.tile_set).is_not_null()
	assert_that(view.tile_set.tile_size).is_equal(Vector2i(BoardCoordinates.CELL_SIZE, BoardCoordinates.CELL_SIZE))

	view.free()


## El orden de los tiles del atlas coincide con Terrain.Type a propósito: pintar un
## FLOOR es literalmente usar el valor del enum como columna del atlas.
func test_sync_from_state_pinta_los_cuatro_tipos_de_terreno() -> void:
	var view := BoardView.new()
	var state := CombatState.new()
	state.set_terrain(Vector2i(1, 1), Terrain.Type.WALL)
	state.set_terrain(Vector2i(2, 2), Terrain.Type.VOID)
	state.set_terrain(Vector2i(3, 3), Terrain.Type.HAZARD)

	view.sync_from_state(state)

	assert_int(view.get_cell_atlas_coords(Vector2i(0, 0)).x).is_equal(Terrain.Type.FLOOR)
	assert_int(view.get_cell_atlas_coords(Vector2i(1, 1)).x).is_equal(Terrain.Type.WALL)
	assert_int(view.get_cell_atlas_coords(Vector2i(2, 2)).x).is_equal(Terrain.Type.VOID)
	assert_int(view.get_cell_atlas_coords(Vector2i(3, 3)).x).is_equal(Terrain.Type.HAZARD)

	view.free()


## Las 25 casillas del tablero se pintan, ninguna se queda vacía por defecto.
func test_sync_from_state_cubre_las_25_casillas() -> void:
	var view := BoardView.new()
	var state := CombatState.new()

	view.sync_from_state(state)

	for y in CombatState.GRID_HEIGHT:
		for x in CombatState.GRID_WIDTH:
			assert_int(view.get_cell_source_id(Vector2i(x, y))).is_not_equal(-1)

	view.free()


## Volver a sincronizar refleja cambios de terreno, no los acumula: una barrera que
## caduca (BarrierExpired) tiene que poder redibujarse a FLOOR sin dejar rastro.
func test_resincronizar_refleja_cambios() -> void:
	var view := BoardView.new()
	var state := CombatState.new()
	state.set_terrain(Vector2i(0, 0), Terrain.Type.WALL)
	view.sync_from_state(state)
	assert_int(view.get_cell_atlas_coords(Vector2i(0, 0)).x).is_equal(Terrain.Type.WALL)

	state.set_terrain(Vector2i(0, 0), Terrain.Type.FLOOR)
	view.sync_from_state(state)
	assert_int(view.get_cell_atlas_coords(Vector2i(0, 0)).x).is_equal(Terrain.Type.FLOOR)

	view.free()
