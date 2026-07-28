extends GdUnitTestSuite

## Tests de CombatState, Unit y Terrain (backlog 1.1, 1.3, 1.4).
## Espeja src/combat/logic/ según A-08.


# ── Tablero ─────────────────────────────────────────────────────

func test_dentro_de_la_grilla() -> void:
	var state := CombatState.new()
	assert_bool(state.is_inside(Vector2i(0, 0))).is_true()
	assert_bool(state.is_inside(Vector2i(4, 4))).is_true()
	assert_bool(state.is_inside(Vector2i(5, 0))).is_false()
	assert_bool(state.is_inside(Vector2i(0, 5))).is_false()
	assert_bool(state.is_inside(Vector2i(-1, 2))).is_false()


func test_unidades_ocupan_casilla() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	assert_that(state.unit_at(Vector2i(2, 4))).is_equal(hero)
	assert_bool(state.is_occupied(Vector2i(2, 4))).is_true()
	assert_bool(state.is_free(Vector2i(2, 4))).is_false()
	assert_bool(state.is_free(Vector2i(1, 1))).is_true()


func test_casilla_fuera_del_tablero_nunca_es_libre() -> void:
	var state := CombatState.new()
	assert_bool(state.is_free(Vector2i(9, 9))).is_false()


func test_unidad_muerta_libera_su_casilla() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 0), 5)

	orc.kill()

	assert_bool(orc.is_alive()).is_false()
	assert_array(state.living_units(Unit.Team.ENEMY)).is_empty()
	assert_bool(state.is_free(Vector2i(2, 0))).is_true()
	# Sigue en la lista: la vista necesita poder animar su muerte antes de que
	# desaparezca, así que el estado no la borra.
	assert_that(state.unit_by_id(orc.id)).is_equal(orc)


func test_living_units_filtra_por_equipo() -> void:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))
	state.add_unit(Unit.Team.ENEMY, Vector2i(0, 0))
	state.add_unit(Unit.Team.ENEMY, Vector2i(4, 0))

	assert_array(state.living_units(Unit.Team.PLAYER)).has_size(1)
	assert_array(state.living_units(Unit.Team.ENEMY)).has_size(2)


# ── Terreno (A-13) ──────────────────────────────────────────────

func test_terreno_por_defecto_es_suelo() -> void:
	var state := CombatState.new()
	assert_int(state.terrain_at(Vector2i(2, 2))).is_equal(Terrain.Type.FLOOR)
	assert_bool(state.is_walkable(Vector2i(2, 2))).is_true()
	assert_bool(state.is_lethal(Vector2i(2, 2))).is_false()


## El tablero es cerrado (GDD §4): el borde se comporta como muro sin que ninguna
## consulta necesite un caso especial para "me salí".
func test_fuera_del_tablero_es_muro() -> void:
	var state := CombatState.new()

	assert_int(state.terrain_at(Vector2i(-1, 0))).is_equal(Terrain.Type.WALL)
	assert_int(state.terrain_at(Vector2i(5, 5))).is_equal(Terrain.Type.WALL)
	assert_bool(state.is_walkable(Vector2i(-1, 0))).is_false()
	assert_bool(state.is_lethal(Vector2i(-1, 0))).is_false()


func test_muro_no_es_transitable() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(1, 1), Terrain.Type.WALL)

	assert_bool(state.is_walkable(Vector2i(1, 1))).is_false()
	assert_bool(state.is_free(Vector2i(1, 1))).is_false()


## La distinción que sostiene el empuje al vacío: entrar en VOID es legal, y mata.
## Si fuera intransitable, un empujón nunca podría tirar a nadie.
func test_vacio_es_transitable_pero_letal() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(0, 0), Terrain.Type.VOID)

	assert_bool(state.is_walkable(Vector2i(0, 0))).is_true()
	assert_bool(state.is_free(Vector2i(0, 0))).is_true()
	assert_bool(state.is_lethal(Vector2i(0, 0))).is_true()


func test_set_terrain_fuera_del_tablero_no_rompe() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(99, 99), Terrain.Type.VOID)

	assert_int(state.terrain_at(Vector2i(99, 99))).is_equal(Terrain.Type.WALL)


# ── Vida y maná (GDD §4) ────────────────────────────────────────

func test_dano_no_baja_de_cero() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10)

	unit.take_damage(3)
	assert_int(unit.hp).is_equal(7)

	unit.take_damage(99)
	assert_int(unit.hp).is_equal(0)
	assert_bool(unit.is_alive()).is_false()


## El maná se acumula en vez de rellenarse: es lo que permite leer "lleva rondas
## ahorrando, tiene algo grande listo".
func test_mana_se_acumula_entre_rondas() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	assert_int(hero.mana).is_equal(CombatState.MANA_START)
	assert_int(state.round_number).is_equal(1)

	state.begin_round()

	assert_int(state.round_number).is_equal(2)
	assert_int(hero.mana).is_equal(CombatState.MANA_START + CombatState.MANA_PER_ROUND)


func test_mana_respeta_el_tope() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	for i in 20:
		state.begin_round()

	assert_int(hero.mana).is_equal(CombatState.MANA_MAX)


func test_no_se_puede_gastar_mana_que_no_hay() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	assert_bool(hero.can_afford(99)).is_false()
	assert_bool(hero.spend_mana(99)).is_false()
	# Lo importante no es que devuelva false, es que no haya cobrado nada.
	assert_int(hero.mana).is_equal(CombatState.MANA_START)

	assert_bool(hero.spend_mana(2)).is_true()
	assert_int(hero.mana).is_equal(CombatState.MANA_START - 2)


func test_quemar_mana_no_baja_de_cero() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	hero.burn_mana(99)

	assert_int(hero.mana).is_equal(0)


# ── change_mana (backlog 1.12: familia Maná) ─────────────────────
##
## Lo que necesita ManaEffect: un delta con signo que devuelve lo que de verdad cambió,
## ya recortado por el tope o por el suelo.

func test_change_mana_positivo_restaura() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))
	hero.burn_mana(hero.mana)

	var applied := hero.change_mana(3)

	assert_int(applied).is_equal(3)
	assert_int(hero.mana).is_equal(3)


func test_change_mana_negativo_quema() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	var applied := hero.change_mana(-2)

	assert_int(applied).is_equal(-2)
	assert_int(hero.mana).is_equal(CombatState.MANA_START - 2)


func test_change_mana_se_recorta_por_el_tope_y_el_suelo() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))

	assert_int(hero.change_mana(99)).is_equal(CombatState.MANA_MAX - CombatState.MANA_START)
	assert_int(hero.change_mana(-99)).is_equal(-CombatState.MANA_MAX)


func test_change_mana_de_cero_no_hace_nada() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4))
	var mana_antes := hero.mana

	assert_int(hero.change_mana(0)).is_equal(0)
	assert_int(hero.mana).is_equal(mana_antes)


func test_los_muertos_no_reciben_mana() -> void:
	var state := CombatState.new()
	var orc := state.add_unit(Unit.Team.ENEMY, Vector2i(0, 0))
	orc.kill()

	state.begin_round()

	assert_int(orc.mana).is_equal(CombatState.MANA_START)


# ── Clonado (A-02 punto 3, A-03) ────────────────────────────────

func test_clone_es_copia_profunda() -> void:
	var original := CombatState.new(1234)
	original.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))

	var copy := original.clone()
	copy.units[0].position = Vector2i(3, 3)
	copy.units[0].take_damage(5)
	copy.units[0].burn_mana(3)
	copy.begin_round()

	assert_that(original.units[0].position).is_equal(Vector2i(0, 0))
	assert_int(original.units[0].hp).is_equal(CombatState.DEFAULT_MAX_HP)
	assert_int(original.units[0].mana).is_equal(CombatState.MANA_START)
	assert_int(original.round_number).is_equal(1)


func test_clone_copia_el_terreno_de_forma_independiente() -> void:
	var original := CombatState.new()
	original.set_terrain(Vector2i(1, 1), Terrain.Type.HAZARD)

	var copy := original.clone()
	copy.set_terrain(Vector2i(2, 2), Terrain.Type.VOID)

	assert_int(copy.terrain_at(Vector2i(1, 1))).is_equal(Terrain.Type.HAZARD)
	assert_int(original.terrain_at(Vector2i(2, 2))).is_equal(Terrain.Type.FLOOR)


## A-03: sin esto, la IA que simula y el PvP por comandos no funcionan.
func test_clone_continua_la_misma_secuencia_de_rng() -> void:
	var original := CombatState.new(777)
	original.rng.randi()
	original.rng.randi()

	var copy := original.clone()

	for i in 5:
		assert_int(copy.rng.randi()).is_equal(original.rng.randi())


func test_misma_semilla_produce_misma_secuencia() -> void:
	var a := CombatState.new(999)
	var b := CombatState.new(999)

	for i in 5:
		assert_int(a.rng.randi()).is_equal(b.rng.randi())
