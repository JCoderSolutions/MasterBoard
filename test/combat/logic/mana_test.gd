extends GdUnitTestSuite

## Tests de la familia Maná en su sitio de la ronda (backlog 1.12).
##
## `Unit.change_mana()` ya se prueba en `combat_state_test.gd`, y `ManaEffect` suelto
## en `effects/effects_test.gd`. Aquí solo lo que depende de `Round`: que quemar maná
## se comporte como cualquier otro ataque a distancia, con línea de tiro y esquive.

const ABILITIES_DIR := "res://resources/abilities"

var meditar: Ability
var disipar: Ability
var muro: Ability


func before() -> void:
	meditar = load("%s/meditar.tres" % ABILITIES_DIR)
	disipar = load("%s/disipar.tres" % ABILITIES_DIR)
	muro = load("%s/muro.tres" % ABILITIES_DIR)


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


# ── Las dos cargan como datos ────────────────────────────────────

func test_meditar_y_disipar_cargan() -> void:
	assert_object(meditar).is_not_null()
	assert_object(disipar).is_not_null()
	assert_array(meditar.effects).is_not_empty()
	assert_array(disipar.effects).is_not_empty()


# ── Restaurar ─────────────────────────────────────────────────────

func test_meditar_restaura_pagando_su_coste() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var mana_antes := hero.mana

	_resolver(
		state,
		RoundChoice.new(hero.id).act(meditar, hero.position),
		RoundChoice.new(_rival(state).id),
	)

	assert_int(hero.mana).is_equal(mana_antes - meditar.mana_cost + 3)


# ── Quemar, como un ataque a distancia más ───────────────────────

func test_disipar_quema_al_rival_en_linea() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(2, 0))
	var hero := state.hero()
	var rival := _rival(state)
	var mana_antes := rival.mana

	_resolver(
		state, RoundChoice.new(hero.id).act(disipar, rival.position), RoundChoice.new(rival.id),
	)

	assert_int(rival.mana).is_equal(mana_antes - 3)


## Igual que un disparo: si el rival se movió, la quema sale igual y da al aire. Se
## pagó el maná al comprometerse, así que leer mal cuesta.
func test_disipar_no_alcanza_si_el_rival_se_movio() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(2, 0))
	var hero := state.hero()
	var rival := _rival(state)
	var mana_antes := rival.mana
	var paso: Ability = load("%s/paso.tres" % ABILITIES_DIR)

	_resolver(
		state,
		RoundChoice.new(hero.id).act(disipar, Vector2i(2, 0)),
		RoundChoice.new(rival.id).move(paso, Vector2i(2, 1)),
	)

	assert_int(rival.mana).is_equal(mana_antes)


## Y si algo se interpone en la trayectoria —una barrera puesta esa misma ronda, aunque
## la ponga el propio objetivo para defenderse— la quema tampoco llega. Es la misma
## regla de `disparo`, no una nueva.
func test_una_barrera_tapa_el_disipar() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(2, 0))
	var hero := state.hero()
	var rival := _rival(state)
	var mana_antes := rival.mana

	_resolver(
		state,
		RoundChoice.new(rival.id).act(muro, Vector2i(1, 0)),
		RoundChoice.new(hero.id).act(disipar, rival.position),
	)

	# El único mana que se mueve es el que el propio rival paga por su muro; el
	# disipar del héroe no debe restar nada más.
	assert_int(rival.mana).is_equal(mana_antes - muro.mana_cost)
