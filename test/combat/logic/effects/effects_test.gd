extends GdUnitTestSuite

## Tests de los efectos componibles (backlog 1.8).
##
## Cada efecto se prueba suelto. Que se combinen bien es cosa de `ability_test.gd`.


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


# ── DamageEffect ────────────────────────────────────────────────

func test_damage_pega_a_quien_esta_en_la_casilla() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var effect := DamageEffect.new()
	effect.amount = 4

	var events := effect.apply(state, state.hero(), Vector2i(2, 1))

	assert_int(rival.hp).is_equal(6)
	assert_array(events).has_size(1)


func test_damage_a_una_casilla_vacia_no_hace_nada() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var effect := DamageEffect.new()

	assert_array(effect.apply(state, state.hero(), Vector2i(4, 4))).is_empty()


# ── PushEffect ──────────────────────────────────────────────────

## La dirección sale de las dos posiciones, no del `.tres`: empujar aleja, siempre.
func test_push_aleja_al_objetivo_de_quien_lanza() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var effect := PushEffect.new()
	effect.distance = 1

	effect.apply(state, state.hero(), Vector2i(2, 1))

	assert_that(rival.position).is_equal(Vector2i(2, 0))


func test_push_hereda_el_dano_de_impacto() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 0))
	var rival := state.unit_at(Vector2i(2, 0))
	var effect := PushEffect.new()
	effect.distance = 2

	effect.apply(state, state.hero(), Vector2i(2, 0))

	assert_that(rival.position).is_equal(Vector2i(2, 0))
	assert_int(rival.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)


func test_push_sin_alineacion_no_hace_nada() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(1, 2))
	var rival := state.unit_at(Vector2i(1, 2))
	var effect := PushEffect.new()

	assert_array(effect.apply(state, state.hero(), Vector2i(1, 2))).is_empty()
	assert_that(rival.position).is_equal(Vector2i(1, 2))


# ── PullEffect ──────────────────────────────────────────────────

func test_pull_acerca_al_objetivo() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 0))
	var rival := state.unit_at(Vector2i(2, 0))
	var effect := PullEffect.new()
	effect.distance = 1

	effect.apply(state, state.hero(), Vector2i(2, 0))

	assert_that(rival.position).is_equal(Vector2i(2, 1))


## Tirar de alguien pegado a ti lo estrella contra ti: no puede ocupar tu casilla, así
## que choca y os hace daño a los dos. Sale de `Displacement`, no hay regla nueva.
func test_tirar_de_un_adyacente_choca_contra_quien_lanza() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := state.unit_at(Vector2i(2, 1))
	var effect := PullEffect.new()
	effect.distance = 2

	effect.apply(state, hero, Vector2i(2, 1))

	assert_that(rival.position).is_equal(Vector2i(2, 1))
	assert_int(rival.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)
	assert_int(hero.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)


# ── MoveSelfEffect ──────────────────────────────────────────────

func test_move_self_desplaza_a_quien_lanza() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(0, 0))
	var hero := state.hero()

	var events := MoveSelfEffect.new().apply(state, hero, Vector2i(4, 2))

	assert_that(hero.position).is_equal(Vector2i(4, 2))
	assert_array(events).has_size(1)


## Delega en MoveCommand, así que hereda sus reglas sin repetirlas.
func test_move_self_respeta_las_reglas_de_movimiento() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(0, 0))
	var hero := state.hero()

	assert_array(MoveSelfEffect.new().apply(state, hero, Vector2i(3, 0))).is_empty()
	assert_that(hero.position).is_equal(Vector2i(2, 2))


# ── ManaEffect ──────────────────────────────────────────────────

## Un signo, dos usos: positivo restaura, y como no distingue amigo de enemigo, apuntar
## a tu propia casilla te restaura a ti.
func test_mana_positivo_se_autolanza_por_targeting() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	hero.burn_mana(hero.mana)
	var effect := ManaEffect.new()
	effect.amount = 3

	var events := effect.apply(state, hero, hero.position)

	assert_int(hero.mana).is_equal(3)
	assert_array(events).has_size(1)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_MANA_CHANGED)


func test_mana_negativo_quema_al_objetivo() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	var effect := ManaEffect.new()
	effect.amount = -2

	effect.apply(state, state.hero(), Vector2i(2, 1))

	assert_int(rival.mana).is_equal(CombatState.MANA_START - 2)


## Si el rival ya está seco, quemarle más no cambia nada, y no debe emitir un evento
## de "-2" que la vista tendría que desmentir.
func test_quemar_a_quien_ya_esta_seco_no_emite_nada() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var rival := state.unit_at(Vector2i(2, 1))
	rival.burn_mana(rival.mana)
	var effect := ManaEffect.new()
	effect.amount = -2

	assert_array(effect.apply(state, state.hero(), Vector2i(2, 1))).is_empty()


func test_mana_a_una_casilla_vacia_no_hace_nada() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var effect := ManaEffect.new()
	effect.amount = 2

	assert_array(effect.apply(state, state.hero(), Vector2i(4, 4))).is_empty()
