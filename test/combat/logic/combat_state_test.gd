extends GdUnitTestSuite

## Tests de CombatState (backlog 1.1). Espeja src/combat/logic/ según A-08.

func test_dentro_de_la_grilla() -> void:
	var state := CombatState.new()
	assert_bool(state.is_inside(Vector2i(0, 0))).is_true()
	assert_bool(state.is_inside(Vector2i(4, 4))).is_true()
	assert_bool(state.is_inside(Vector2i(5, 0))).is_false()
	assert_bool(state.is_inside(Vector2i(0, 5))).is_false()
	assert_bool(state.is_inside(Vector2i(-1, 2))).is_false()


func test_unidades_ocupan_casilla() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4), 10)

	assert_that(state.unit_at(Vector2i(2, 4))).is_equal(hero)
	assert_bool(state.is_occupied(Vector2i(2, 4))).is_true()
	assert_bool(state.is_free(Vector2i(2, 4))).is_false()
	assert_bool(state.is_free(Vector2i(1, 1))).is_true()


func test_casilla_fuera_de_grilla_nunca_es_libre() -> void:
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


func test_dano_no_baja_de_cero() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10)

	unit.take_damage(3)
	assert_int(unit.hp).is_equal(7)

	unit.take_damage(99)
	assert_int(unit.hp).is_equal(0)
	assert_bool(unit.is_alive()).is_false()


func test_living_units_filtra_por_equipo() -> void:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, Vector2i(2, 4), 10)
	state.add_unit(Unit.Team.ENEMY, Vector2i(0, 0), 5)
	state.add_unit(Unit.Team.ENEMY, Vector2i(4, 0), 5)

	assert_array(state.living_units(Unit.Team.PLAYER)).has_size(1)
	assert_array(state.living_units(Unit.Team.ENEMY)).has_size(2)


func test_clone_es_copia_profunda() -> void:
	var original := CombatState.new(1234)
	original.add_unit(Unit.Team.PLAYER, Vector2i(0, 0), 10)
	original.deck.append("strike")

	var copy := original.clone()
	copy.units[0].position = Vector2i(3, 3)
	copy.units[0].take_damage(5)
	copy.energy = 0
	copy.deck.append("shove")

	assert_that(original.units[0].position).is_equal(Vector2i(0, 0))
	assert_int(original.units[0].hp).is_equal(10)
	assert_int(original.energy).is_equal(CombatState.ENERGY_PER_TURN)
	assert_array(original.deck).contains_exactly(["strike"])


## A-03: sin esto, la IA que simula y el multijugador por comandos no funcionan.
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
