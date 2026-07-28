extends GdUnitTestSuite

## Tests de MoveCommand y las reglas de terreno al moverse (backlog 1.6).


func _estado_con_heroe(pos: Vector2i = Vector2i(2, 2)) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, pos)
	return state


# ── Movimiento válido ───────────────────────────────────────────

func test_paso_ortogonal_mueve_la_unidad() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	var resolver := Resolver.new()

	var events := resolver.execute(state, MoveCommand.new(hero.id, Vector2i(2, 1)))

	assert_that(hero.position).is_equal(Vector2i(2, 1))
	assert_array(events).has_size(1)
	var moved: UnitMoved = events[0]
	assert_that(moved.from).is_equal(Vector2i(2, 2))
	assert_that(moved.to).is_equal(Vector2i(2, 1))


func test_dash_recorre_varias_casillas() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()
	var resolver := Resolver.new()

	resolver.execute(state, MoveCommand.new(hero.id, Vector2i(3, 0)))

	assert_that(hero.position).is_equal(Vector2i(3, 0))


func test_movimiento_en_diagonal() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()
	var resolver := Resolver.new()

	resolver.execute(state, MoveCommand.new(hero.id, Vector2i(2, 2)))

	assert_that(hero.position).is_equal(Vector2i(2, 2))


# ── Movimientos ilegales ────────────────────────────────────────

## Solo hay líneas en las 8 direcciones (1.5). Un salto de caballo no es movimiento.
func test_destino_no_alineado_es_ilegal() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()

	assert_bool(MoveCommand.new(hero.id, Vector2i(1, 2)).validate(state)).is_false()


func test_no_se_puede_salir_del_tablero() -> void:
	var state := _estado_con_heroe(Vector2i(2, 0))
	var hero := state.hero()
	var resolver := Resolver.new()

	var events := resolver.execute(state, MoveCommand.new(hero.id, Vector2i(2, -1)))

	assert_array(events).is_empty()
	assert_that(hero.position).is_equal(Vector2i(2, 0))
	assert_array(resolver.history).is_empty()


func test_un_muro_bloquea_el_destino() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(2, 1), Terrain.Type.WALL)

	assert_bool(MoveCommand.new(hero.id, Vector2i(2, 1)).validate(state)).is_false()


func test_un_muro_en_el_camino_bloquea_el_dash() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()
	state.set_terrain(Vector2i(1, 0), Terrain.Type.WALL)

	assert_bool(MoveCommand.new(hero.id, Vector2i(3, 0)).validate(state)).is_false()


func test_una_unidad_en_el_camino_bloquea_el_dash() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()
	state.add_unit(Unit.Team.ENEMY, Vector2i(1, 0))

	assert_bool(MoveCommand.new(hero.id, Vector2i(3, 0)).validate(state)).is_false()


func test_una_unidad_muerta_no_se_mueve() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	hero.kill()

	assert_bool(MoveCommand.new(hero.id, Vector2i(2, 1)).validate(state)).is_false()


# ── Vacío (A-13) ────────────────────────────────────────────────

func test_entrar_en_el_vacio_mata_y_libera_la_casilla() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(2, 1), Terrain.Type.VOID)
	var resolver := Resolver.new()

	var events := resolver.execute(state, MoveCommand.new(hero.id, Vector2i(2, 1)))

	assert_bool(hero.is_alive()).is_false()
	assert_bool(state.is_free(Vector2i(2, 1))).is_true()
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_MOVED)
	var died: UnitDied = events[1]
	assert_int(died.cause).is_equal(UnitDied.Cause.FALL)


## Cruzar un abismo de un dash es legal y termina como uno esperaría: te caes en el
## abismo. La unidad se queda donde cayó, no en el destino que pidió.
func test_el_vacio_en_el_camino_interrumpe_el_dash() -> void:
	var state := _estado_con_heroe(Vector2i(0, 0))
	var hero := state.hero()
	state.set_terrain(Vector2i(1, 0), Terrain.Type.VOID)
	var resolver := Resolver.new()

	var command := MoveCommand.new(hero.id, Vector2i(3, 0))
	assert_bool(command.validate(state)).is_true()

	var events := resolver.execute(state, command)

	assert_bool(hero.is_alive()).is_false()
	assert_that(hero.position).is_equal(Vector2i(1, 0))
	var moved: UnitMoved = events[0]
	assert_that(moved.to).is_equal(Vector2i(1, 0))


# ── Peligros (GDD §5, fase 4) ───────────────────────────────────

## MoveCommand NO cobra el daño de peligro. Se resuelve una sola vez en la fase 4
## de la ronda, para que dé igual si llegaste andando o empujado; cobrarlo aquí lo
## duplicaría cuando un empujón te mete en la lava.
func test_moverse_a_un_peligro_no_hace_dano_todavia() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(2, 1), Terrain.Type.HAZARD)
	var resolver := Resolver.new()

	var events := resolver.execute(state, MoveCommand.new(hero.id, Vector2i(2, 1)))

	assert_that(hero.position).is_equal(Vector2i(2, 1))
	assert_int(hero.hp).is_equal(CombatState.DEFAULT_MAX_HP)
	assert_array(events).has_size(1)


# ── Determinismo (A-03) ─────────────────────────────────────────

func test_la_misma_secuencia_de_movimientos_da_el_mismo_estado() -> void:
	var destinos: Array[Vector2i] = [Vector2i(2, 1), Vector2i(2, 0), Vector2i(4, 0)]

	assert_that(_correr(destinos)).is_equal(_correr(destinos))


func _correr(destinos: Array[Vector2i]) -> Vector2i:
	var state := _estado_con_heroe()
	var hero := state.hero()
	var resolver := Resolver.new()
	for destino in destinos:
		resolver.execute(state, MoveCommand.new(hero.id, destino))
	return hero.position
