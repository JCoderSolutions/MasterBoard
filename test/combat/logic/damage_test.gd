extends GdUnitTestSuite

## Tests de Damage, el único punto por el que pasa el daño (backlog 1.7).


func _unidad(hp: int = CombatState.DEFAULT_MAX_HP) -> Unit:
	return Unit.new(1, Unit.Team.PLAYER, Vector2i(2, 2), hp, CombatState.MANA_MAX, 0)


func test_dano_normal_emite_un_evento() -> void:
	var unit := _unidad()

	var events := Damage.apply(unit, 3)

	assert_int(unit.hp).is_equal(7)
	assert_array(events).has_size(1)
	var damaged: UnitDamaged = events[0]
	assert_int(damaged.unit_id).is_equal(unit.id)
	assert_int(damaged.amount).is_equal(3)
	assert_int(damaged.hp_after).is_equal(7)


func test_dano_letal_emite_impacto_y_muerte_en_ese_orden() -> void:
	var unit := _unidad(3)

	var events := Damage.apply(unit, 3)

	assert_bool(unit.is_alive()).is_false()
	assert_array(events).has_size(2)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)
	var died: UnitDied = events[1]
	assert_int(died.cause).is_equal(UnitDied.Cause.DAMAGE)


## La vista no debería mostrar un "-7" flotante sobre una barra que solo bajó 2.
func test_el_sobredano_se_reporta_recortado() -> void:
	var unit := _unidad(2)

	var events := Damage.apply(unit, 7)

	assert_int(unit.hp).is_equal(0)
	var damaged: UnitDamaged = events[0]
	assert_int(damaged.amount).is_equal(2)
	assert_int(damaged.hp_after).is_equal(0)


## Un evento de "no pasó nada" obligaría a la cola de animación a filtrarlo.
func test_dano_cero_o_negativo_no_emite_nada() -> void:
	var unit := _unidad()

	assert_array(Damage.apply(unit, 0)).is_empty()
	assert_array(Damage.apply(unit, -3)).is_empty()
	assert_int(unit.hp).is_equal(CombatState.DEFAULT_MAX_HP)


func test_una_unidad_ya_muerta_no_vuelve_a_morir() -> void:
	var unit := _unidad()
	unit.kill()

	assert_array(Damage.apply(unit, 3)).is_empty()


func test_una_unidad_nula_no_revienta() -> void:
	assert_array(Damage.apply(null, 3)).is_empty()
