extends GdUnitTestSuite

## Tests de ActionSpace: el espacio de jugadas legales de una unidad (backlog 1.16).

const ABILITIES_DIR := "res://resources/abilities"

var paso: Ability
var impulso: Ability
var tajo: Ability
var embestida: Ability


func before() -> void:
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	impulso = load("%s/impulso.tres" % ABILITIES_DIR)
	tajo = load("%s/tajo.tres" % ABILITIES_DIR)
	embestida = load("%s/embestida.tres" % ABILITIES_DIR)


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


func _kit(abilities: Array[Ability]) -> Array[Ability]:
	return abilities


func _rival(state: CombatState) -> Unit:
	return state.living_units(Unit.Team.ENEMY)[0]


# ── Siempre hay algo que elegir ──────────────────────────────────

## Ni una unidad viva sin kit se queda sin jugadas: quedarse quieto siempre existe.
func test_una_unidad_sin_kit_solo_puede_quedarse_quieta() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()

	var choices := ActionSpace.legal_choices(state, hero, _kit([]))

	assert_array(choices).has_size(1)
	assert_bool(choices[0].is_empty()).is_true()


func test_una_unidad_muerta_no_tiene_jugadas() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	hero.kill()

	assert_array(ActionSpace.legal_choices(state, hero, _kit([paso]))).is_empty()


# ── Ranuras separadas por fase ────────────────────────────────────

## Paso es de fase MOVEMENT: nunca debe aparecer en la ranura de acción, aunque esté
## en el kit y sea pagable.
func test_una_habilidad_de_movimiento_solo_aparece_en_la_ranura_de_movimiento() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()

	var choices := ActionSpace.legal_choices(state, hero, _kit([paso]))

	for choice in choices:
		assert_object(choice.action).is_null()


func test_una_habilidad_de_ataque_solo_aparece_en_la_ranura_de_accion() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()

	var choices := ActionSpace.legal_choices(state, hero, _kit([tajo]))

	for choice in choices:
		assert_object(choice.movement).is_null()


## Una habilidad de fase TERRAIN —si alguna vez existiera una así— no la elige nadie:
## no es una carta, es lo que hace el tablero solo (Phase.is_selectable).
func test_una_habilidad_de_fase_terrain_no_es_elegible_en_ninguna_ranura() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var fantasma := Ability.new()
	fantasma.phase = Phase.Type.TERRAIN
	fantasma.targeting = Targeting.Mode.SELF

	var choices := ActionSpace.legal_choices(state, hero, _kit([fantasma]))

	assert_array(choices).has_size(1)  # solo quedarse quieto
	for choice in choices:
		assert_object(choice.movement).is_null()
		assert_object(choice.action).is_null()


# ── Objetivos válidos ─────────────────────────────────────────────

## `Ability.valid_targets()` no excluye la propia casilla —`tajo` no distingue amigo de
## enemigo, y pegarte a ti mismo es una jugada legal aunque nadie la quiera— así que con
## un rival adyacente hay dos objetivos válidos: el rival y uno mismo. Lo que importa
## comprobar es que el objetivo del rival está entre ellos con la casilla correcta.
func test_solo_enumera_objetivos_donde_hay_alguien() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()

	var choices := ActionSpace.legal_choices(state, hero, _kit([tajo]))

	var al_rival := choices.filter(func(c: RoundChoice) -> bool:
		return c.action == tajo and c.action_target == Vector2i(2, 1)
	)
	assert_array(al_rival).has_size(1)


## Con el rival fuera de alcance, ningún objetivo de `tajo` puede ser la casilla del
## rival. `UNIT` no distingue amigo de enemigo, así que uno mismo sigue siendo un
## objetivo válido —pegarte a ti mismo es legal, aunque nadie la quiera— y por eso no se
## comprueba que la única jugada sea "quedarse quieto", sino que el rival, en concreto,
## nunca es alcanzable.
func test_un_rival_fuera_de_alcance_nunca_es_objetivo() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var rival := _rival(state)

	var choices := ActionSpace.legal_choices(state, hero, _kit([tajo]))

	for choice in choices:
		if choice.action == tajo:
			assert_that(choice.action_target).is_not_equal(rival.position)


# ── Maná: el pozo es uno solo para las dos ranuras ────────────────

## El caso que justifica no enumerar cada ranura por separado: impulso (1) y embestida
## (2) caben cada uno solo con 2 de maná, pero juntos suman 3 y no caben. La combinación
## no debe aparecer aunque las dos mitades sí quepan sueltas.
func test_una_combinacion_que_junta_no_cabe_no_se_enumera() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	hero.burn_mana(hero.mana)
	hero.grant_mana(2)

	var choices := ActionSpace.legal_choices(state, hero, _kit([impulso, embestida]))

	for choice in choices:
		var coste := (choice.movement.mana_cost if choice.movement != null else 0) \
			+ (choice.action.mana_cost if choice.action != null else 0)
		assert_int(coste).is_less_equal(2)

	var con_las_dos := choices.filter(func(c: RoundChoice) -> bool:
		return c.movement == impulso and c.action == embestida
	)
	assert_array(con_las_dos).is_empty()


func test_con_mana_de_sobra_la_combinacion_si_aparece() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	hero.grant_mana(CombatState.MANA_MAX)

	var choices := ActionSpace.legal_choices(state, hero, _kit([impulso, embestida]))

	var con_las_dos := choices.filter(func(c: RoundChoice) -> bool:
		return c.movement == impulso and c.action == embestida
	)
	assert_array(con_las_dos).is_not_empty()


func test_sin_mana_solo_queda_lo_gratis() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	hero.burn_mana(hero.mana)

	var choices := ActionSpace.legal_choices(state, hero, _kit([paso, tajo]))

	# `paso` cuesta 0: sigue disponible. `tajo` cuesta 1: desaparece del todo.
	var con_tajo := choices.filter(func(c: RoundChoice) -> bool: return c.action == tajo)
	assert_array(con_tajo).is_empty()
	var con_paso := choices.filter(func(c: RoundChoice) -> bool: return c.movement == paso)
	assert_array(con_paso).is_not_empty()


# ── Determinismo ────────────────────────────────────────────────

## Enumerar no muta nada ni depende de RNG: dos llamadas seguidas dan el mismo
## conjunto de jugadas, y la unidad queda exactamente donde estaba.
func test_enumerar_no_cambia_el_estado_y_es_repetible() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var pos_antes := hero.position
	var mana_antes := hero.mana

	var primera := ActionSpace.legal_choices(state, hero, _kit([paso, tajo, embestida]))
	var segunda := ActionSpace.legal_choices(state, hero, _kit([paso, tajo, embestida]))

	assert_that(hero.position).is_equal(pos_antes)
	assert_int(hero.mana).is_equal(mana_antes)
	assert_int(primera.size()).is_equal(segunda.size())
