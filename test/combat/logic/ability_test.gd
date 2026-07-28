extends GdUnitTestSuite

## Tests de Ability: composición de efectos y habilidades como datos (backlog 1.8).

const ABILITIES_DIR := "res://resources/abilities"


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


func _habilidad(mana_cost: int, effects: Array[Effect]) -> Ability:
	var ability := Ability.new()
	ability.id = &"prueba"
	ability.mana_cost = mana_cost
	ability.targeting = Targeting.Mode.UNIT
	ability.max_range = 1
	ability.effects = effects
	return ability


func _dano(amount: int) -> DamageEffect:
	var effect := DamageEffect.new()
	effect.amount = amount
	return effect


func _empuje(distance: int) -> PushEffect:
	var effect := PushEffect.new()
	effect.distance = distance
	return effect


# ── Composición ─────────────────────────────────────────────────

func test_los_efectos_se_aplican_en_orden() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var efectos: Array[Effect] = [_dano(2), _empuje(1)]

	var events := _habilidad(0, efectos).apply(state, state.hero().id, Vector2i(2, 1))

	assert_int(rival.hp).is_equal(8)
	assert_that(rival.position).is_equal(Vector2i(2, 0))
	assert_int(events[0].type).is_equal(Event.Type.UNIT_DAMAGED)
	assert_int(events[1].type).is_equal(Event.Type.UNIT_MOVED)


## El orden no es cosmético: pegar y luego empujar contra un muro suma el impacto,
## empujar y luego pegar deja el golpe en una casilla vacía.
func test_invertir_el_orden_cambia_el_resultado() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var efectos: Array[Effect] = [_empuje(1), _dano(2)]

	_habilidad(0, efectos).apply(state, state.hero().id, Vector2i(2, 1))

	assert_that(rival.position).is_equal(Vector2i(2, 0))
	assert_int(rival.hp).is_equal(10)  # el daño cayó en la casilla que dejó vacía


func test_una_habilidad_sin_efectos_no_revienta() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var vacios: Array[Effect] = []

	assert_array(_habilidad(0, vacios).apply(state, state.hero().id, Vector2i(2, 1))).is_empty()


# ── Maná ────────────────────────────────────────────────────────

## `apply()` comprueba el maná pero **no lo cobra**: se paga al comprometer la elección,
## no al resolverla (backlog 1.9). Si no, esquivar devolvería el maná del golpe fallado.
func test_apply_no_cobra_el_mana() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var mana_antes := hero.mana
	var efectos: Array[Effect] = [_dano(2)]

	_habilidad(1, efectos).apply(state, hero.id, Vector2i(2, 1))

	assert_int(hero.mana).is_equal(mana_antes)


func test_una_habilidad_impagable_no_se_resuelve() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := state.unit_at(Vector2i(2, 1))
	var efectos: Array[Effect] = [_dano(2)]

	var events := _habilidad(hero.mana + 1, efectos).apply(state, hero.id, Vector2i(2, 1))

	assert_array(events).is_empty()
	assert_int(rival.hp).is_equal(10)


func test_can_afford_mira_el_mana_actual() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var vacios: Array[Effect] = []
	var ability := _habilidad(hero.mana, vacios)

	assert_bool(ability.can_afford(hero)).is_true()
	hero.burn_mana(1)
	assert_bool(ability.can_afford(hero)).is_false()


# ── Targeting ───────────────────────────────────────────────────

func test_un_objetivo_invalido_no_resuelve_nada() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var rival := state.unit_at(Vector2i(4, 4))
	var efectos: Array[Effect] = [_dano(2)]

	var events := _habilidad(0, efectos).apply(state, state.hero().id, Vector2i(4, 4))

	assert_array(events).is_empty()
	assert_int(rival.hp).is_equal(10)


# ── Las habilidades son datos (goal #6 del GDD) ─────────────────

## El criterio de aceptación de 1.8: las habilidades del juego se cargan de `.tres` y
## se comportan sin que ningún `.gd` sepa que existen.
func test_las_habilidades_del_repo_cargan() -> void:
	for id in ["tajo", "embestida", "disparo", "garfio", "impulso"]:
		var ability: Ability = load("%s/%s.tres" % [ABILITIES_DIR, id])

		assert_object(ability).is_not_null()
		assert_str(String(ability.id)).is_equal(id)
		assert_array(ability.effects).is_not_empty()


func test_tajo_hace_su_dano() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var tajo: Ability = load("%s/tajo.tres" % ABILITIES_DIR)

	tajo.apply(state, state.hero().id, Vector2i(2, 1))

	assert_int(rival.hp).is_equal(7)


## Dos efectos en un `.tres`, sin una línea de código propia.
func test_embestida_pega_y_empuja() -> void:
	var state := _estado(Vector2i(2, 3), Vector2i(2, 2))
	var rival := state.unit_at(Vector2i(2, 2))
	var embestida: Ability = load("%s/embestida.tres" % ABILITIES_DIR)

	embestida.apply(state, state.hero().id, Vector2i(2, 2))

	assert_int(rival.hp).is_equal(9)
	assert_that(rival.position).is_equal(Vector2i(2, 0))


## La sinergia que justifica que la embestida cueste 2: contra el borde, el daño del
## golpe y el del impacto se suman. Acorralar al rival hace que la misma carta pegue el
## doble, y eso no está programado en ningún sitio — sale de componer daño con empuje.
func test_la_embestida_pega_mas_contra_el_borde() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var embestida: Ability = load("%s/embestida.tres" % ABILITIES_DIR)

	embestida.apply(state, state.hero().id, Vector2i(2, 1))

	assert_int(rival.hp).is_equal(8)
	assert_that(rival.position).is_equal(Vector2i(2, 0))


func test_el_disparo_necesita_linea_de_vision() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(3, 0))
	var rival := state.unit_at(Vector2i(3, 0))
	var disparo: Ability = load("%s/disparo.tres" % ABILITIES_DIR)
	var hero := state.hero()

	assert_bool(disparo.is_valid_target(state, hero, Vector2i(3, 0))).is_true()

	state.set_terrain(Vector2i(1, 0), Terrain.Type.WALL)
	assert_bool(disparo.is_valid_target(state, hero, Vector2i(3, 0))).is_false()
	assert_array(disparo.apply(state, hero.id, Vector2i(3, 0))).is_empty()
	assert_int(rival.hp).is_equal(10)


func test_el_garfio_atrae() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(3, 0))
	var rival := state.unit_at(Vector2i(3, 0))
	var garfio: Ability = load("%s/garfio.tres" % ABILITIES_DIR)

	garfio.apply(state, state.hero().id, Vector2i(3, 0))

	assert_that(rival.position).is_equal(Vector2i(1, 0))


func test_el_impulso_solo_ofrece_casillas_alcanzables() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var impulso: Ability = load("%s/impulso.tres" % ABILITIES_DIR)
	var hero := state.hero()

	var casillas := impulso.valid_targets(state, hero)

	assert_array(casillas).contains([Vector2i(4, 2), Vector2i(0, 0)])
	# No alineada: el movimiento la rechazaría, así que no se ofrece.
	assert_bool(casillas.has(Vector2i(1, 0))).is_false()
	# Ocupada por el rival.
	assert_bool(casillas.has(Vector2i(4, 4))).is_false()
