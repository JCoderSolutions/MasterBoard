extends GdUnitTestSuite

## Tests de empuje, colisión y daño de impacto (backlog 1.7).

const DERECHA := Vector2i(1, 0)


func _estado_con_heroe(pos: Vector2i = Vector2i(2, 2), max_hp: int = 10) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, pos, max_hp)
	return state


# ── Empuje limpio ───────────────────────────────────────────────

func test_empuje_sin_obstaculos_no_hace_dano() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()

	var events := Displacement.push(state, hero.id, DERECHA, 2)

	assert_that(hero.position).is_equal(Vector2i(4, 2))
	assert_int(hero.hp).is_equal(10)
	assert_array(events).has_size(1)
	var moved: UnitMoved = events[0]
	assert_that(moved.from).is_equal(Vector2i(2, 2))
	assert_that(moved.to).is_equal(Vector2i(4, 2))


## Tirar es empujar con la dirección invertida. Es toda la implementación del efecto
## `Pull` de la familia Desplazamiento (backlog 1.8).
func test_el_tiron_es_el_mismo_empuje_al_reves() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()

	Displacement.push(state, hero.id, -DERECHA, 2)

	assert_that(hero.position).is_equal(Vector2i(0, 2))


func test_una_direccion_no_unitaria_se_normaliza() -> void:
	var state := _estado_con_heroe(Vector2i(0, 2))
	var hero := state.hero()

	Displacement.push(state, hero.id, Vector2i(3, 0), 1)

	assert_that(hero.position).is_equal(Vector2i(1, 2))


# ── Choque contra terreno ───────────────────────────────────────

func test_un_muro_detiene_el_empuje_y_hace_dano() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(4, 2), Terrain.Type.WALL)

	var events := Displacement.push(state, hero.id, DERECHA, 3)

	assert_that(hero.position).is_equal(Vector2i(3, 2))
	assert_int(hero.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_MOVED)
	assert_int(events[1].type).is_equal(Event.Type.UNIT_DAMAGED)


## El borde del tablero devuelve `WALL`, así que frena el empuje sin caso especial (A-13).
func test_el_borde_del_tablero_detiene_el_empuje() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()

	Displacement.push(state, hero.id, DERECHA, 5)

	assert_that(hero.position).is_equal(Vector2i(4, 2))
	assert_int(hero.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)


## Acorralar a alguien contra un muro tiene que ser una posición perdedora: el empuje
## que no desplaza nada sigue haciendo daño.
func test_empujar_a_quien_ya_esta_pegado_al_muro_duele_igual() -> void:
	var state := _estado_con_heroe(Vector2i(4, 2))
	var hero := state.hero()

	var events := Displacement.push(state, hero.id, DERECHA, 2)

	assert_that(hero.position).is_equal(Vector2i(4, 2))
	assert_int(hero.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)
	assert_array(events).has_size(1)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)


# ── Choque contra otra unidad ───────────────────────────────────

func test_chocar_contra_otra_unidad_dana_a_las_dos() -> void:
	var state := _estado_con_heroe(Vector2i(1, 2))
	var hero := state.hero()
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(3, 2))

	var events := Displacement.push(state, hero.id, DERECHA, 3)

	assert_that(hero.position).is_equal(Vector2i(2, 2))
	assert_int(hero.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)
	assert_int(rival.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)

	# El orden es contrato: la vista reproduce los eventos en secuencia (R-08).
	assert_array(events).has_size(3)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_MOVED)
	assert_int((events[1] as UnitDamaged).unit_id).is_equal(hero.id)
	assert_int((events[2] as UnitDamaged).unit_id).is_equal(rival.id)


## Los empujes no se encadenan: sería imposible de previsualizar antes de confirmar (R-07).
func test_la_unidad_que_bloquea_no_se_desplaza() -> void:
	var state := _estado_con_heroe(Vector2i(1, 2))
	var hero := state.hero()
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 2))

	var events := Displacement.push(state, hero.id, DERECHA, 2)

	assert_that(hero.position).is_equal(Vector2i(1, 2))
	assert_that(rival.position).is_equal(Vector2i(2, 2))
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)


## La casilla se libera al terminar de resolver, no a mitad del empujón.
func test_si_el_bloqueador_muere_el_empujado_no_sigue_avanzando() -> void:
	var state := _estado_con_heroe(Vector2i(1, 2))
	var hero := state.hero()
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 2), Displacement.IMPACT_DAMAGE)

	Displacement.push(state, hero.id, DERECHA, 3)

	assert_bool(rival.is_alive()).is_false()
	assert_that(hero.position).is_equal(Vector2i(1, 2))


# ── Terreno (A-13) ──────────────────────────────────────────────

## Sin daño de impacto: no chocó contra nada, se cayó.
func test_empujar_al_vacio_mata_por_caida() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(3, 2), Terrain.Type.VOID)

	var events := Displacement.push(state, hero.id, DERECHA, 2)

	assert_bool(hero.is_alive()).is_false()
	assert_that(hero.position).is_equal(Vector2i(3, 2))
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_MOVED)
	var died: UnitDied = events[1]
	assert_int(died.cause).is_equal(UnitDied.Cause.FALL)


## El daño de peligro se cobra una sola vez en la fase 4 de la ronda (backlog 1.9), dé
## igual si llegaste andando o empujado.
func test_empujar_a_un_peligro_no_hace_dano_todavia() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	state.set_terrain(Vector2i(3, 2), Terrain.Type.HAZARD)

	var events := Displacement.push(state, hero.id, DERECHA, 1)

	assert_that(hero.position).is_equal(Vector2i(3, 2))
	assert_int(hero.hp).is_equal(10)
	assert_array(events).has_size(1)


# ── Impacto letal ───────────────────────────────────────────────

func test_el_impacto_puede_matar() -> void:
	var state := _estado_con_heroe(Vector2i(4, 2), Displacement.IMPACT_DAMAGE)
	var hero := state.hero()

	var events := Displacement.push(state, hero.id, DERECHA, 1)

	assert_bool(hero.is_alive()).is_false()
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)
	var died: UnitDied = events[1]
	assert_int(died.cause).is_equal(UnitDied.Cause.DAMAGE)


# ── Empujes que no ocurren ──────────────────────────────────────

func test_sin_direccion_o_sin_distancia_no_pasa_nada() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()

	assert_array(Displacement.push(state, hero.id, Vector2i.ZERO, 2)).is_empty()
	assert_array(Displacement.push(state, hero.id, DERECHA, 0)).is_empty()
	assert_array(Displacement.push(state, hero.id, DERECHA, -1)).is_empty()
	assert_that(hero.position).is_equal(Vector2i(2, 2))


func test_una_unidad_muerta_o_inexistente_no_se_empuja() -> void:
	var state := _estado_con_heroe()
	var hero := state.hero()
	hero.kill()

	assert_array(Displacement.push(state, hero.id, DERECHA, 1)).is_empty()
	assert_array(Displacement.push(state, 999, DERECHA, 1)).is_empty()


# ── Determinismo (A-03) ─────────────────────────────────────────

func test_el_mismo_empuje_produce_los_mismos_eventos() -> void:
	assert_str(_empujar_contra_un_rival()).is_equal(_empujar_contra_un_rival())


func _empujar_contra_un_rival() -> String:
	var state := _estado_con_heroe(Vector2i(1, 2))
	state.add_unit(Unit.Team.ENEMY, Vector2i(3, 2))

	var events := Displacement.push(state, state.hero().id, DERECHA, 3)

	var firma := PackedStringArray()
	for event in events:
		firma.append(str(event))
	return " | ".join(firma)
