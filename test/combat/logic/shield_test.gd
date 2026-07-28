extends GdUnitTestSuite

## Tests de escudos: la unidad, el efecto y su sitio en la ronda (backlog 1.11).
##
## `Damage.apply()` ya prueba la absorción en sí (`damage_test.gd`); aquí se prueba todo
## lo que hay alrededor: otorgar, sustituir, clonar y la duración por ronda.

const ABILITIES_DIR := "res://resources/abilities"

var coraza: Ability


func before() -> void:
	coraza = load("%s/coraza.tres" % ABILITIES_DIR)


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


func _rival(state: CombatState) -> Unit:
	return state.living_units(Unit.Team.ENEMY)[0]


func _resolver(state: CombatState, a: RoundChoice, b: RoundChoice) -> Array[Event]:
	var choices: Array[RoundChoice] = [a, b]
	return Round.resolve(state, choices)


# ── Unit ────────────────────────────────────────────────────────

func test_otorgar_escudo() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)

	unit.grant_shield(4, 2)

	assert_bool(unit.has_shield()).is_true()
	assert_int(unit.shield).is_equal(4)
	assert_int(unit.shield_rounds).is_equal(2)


## Un escudo nuevo sustituye al anterior, no se acumula: una sola regla legible.
func test_un_escudo_nuevo_sustituye_al_anterior() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)
	unit.grant_shield(5, 3)

	unit.grant_shield(2, 1)

	assert_int(unit.shield).is_equal(2)
	assert_int(unit.shield_rounds).is_equal(1)


func test_otorgar_escudo_de_cero_no_hace_nada() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)

	unit.grant_shield(0, 3)
	unit.grant_shield(5, 0)

	assert_bool(unit.has_shield()).is_false()


func test_tick_shield_descuenta_una_ronda() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)
	unit.grant_shield(4, 2)

	assert_bool(unit.tick_shield()).is_false()
	assert_int(unit.shield_rounds).is_equal(1)
	assert_bool(unit.tick_shield()).is_true()
	assert_bool(unit.has_shield()).is_false()


func test_tick_shield_sin_escudo_no_hace_nada() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)

	assert_bool(unit.tick_shield()).is_false()


func test_clone_se_lleva_el_escudo() -> void:
	var unit := Unit.new(1, Unit.Team.PLAYER, Vector2i.ZERO, 10, 8, 0)
	unit.grant_shield(4, 2)

	var copy := unit.clone()

	assert_int(copy.shield).is_equal(4)
	assert_int(copy.shield_rounds).is_equal(2)


# ── ShieldEffect ────────────────────────────────────────────────

func test_shield_effect_se_autolanza() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var effect := ShieldEffect.new()
	effect.amount = 3
	effect.duration = 2

	var events := effect.apply(state, hero, hero.position)

	assert_int(hero.shield).is_equal(3)
	assert_array(events).has_size(1)
	assert_int(events[0].type).is_equal(Event.Type.UNIT_SHIELDED)


func test_shield_effect_a_una_casilla_vacia_no_hace_nada() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var effect := ShieldEffect.new()
	effect.amount = 3
	effect.duration = 1

	assert_array(effect.apply(state, hero, Vector2i(0, 0))).is_empty()


# ── Sitio en la ronda ───────────────────────────────────────────

## El escudo puesto en la fase 1 protege ya contra los ataques de esta misma ronda.
func test_la_coraza_protege_en_la_misma_ronda_en_que_se_pone() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)
	var tajo: Ability = load("%s/tajo.tres" % ABILITIES_DIR)

	_resolver(
		state,
		RoundChoice.new(hero.id).act(coraza, hero.position),
		RoundChoice.new(rival.id).act(tajo, hero.position),
	)

	assert_int(hero.hp).is_equal(10)
	assert_int(hero.shield).is_equal(coraza.effects[0].amount - tajo.effects[0].amount)


## "2 rondas" cuenta la ronda en que se pone más una: sobrevive al cierre de esa ronda
## (queda 1) y caduca al cierre de la siguiente. Mismo reloj que `bastion` en 1.10.
func test_la_coraza_dura_sus_rondas_y_luego_caduca() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state, RoundChoice.new(hero.id).act(coraza, hero.position), RoundChoice.new(rival.id),
	)
	assert_bool(hero.has_shield()).is_true()

	state.begin_round()
	_resolver(state, RoundChoice.new(hero.id), RoundChoice.new(rival.id))
	assert_bool(hero.has_shield()).is_false()


func test_la_coraza_cuesta_su_mana() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var mana_antes := hero.mana

	_resolver(
		state,
		RoundChoice.new(hero.id).act(coraza, hero.position),
		RoundChoice.new(_rival(state).id),
	)

	assert_int(hero.mana).is_equal(mana_antes - coraza.mana_cost)
