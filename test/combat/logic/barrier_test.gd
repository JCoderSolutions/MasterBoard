extends GdUnitTestSuite

## Tests de barreras: colocación, duración por carta y caducidad (backlog 1.10).

const ABILITIES_DIR := "res://resources/abilities"

var muro: Ability
var bastion: Ability
var paso: Ability
var impulso: Ability
var disparo: Ability


func before() -> void:
	muro = load("%s/muro.tres" % ABILITIES_DIR)
	bastion = load("%s/bastion.tres" % ABILITIES_DIR)
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	impulso = load("%s/impulso.tres" % ABILITIES_DIR)
	disparo = load("%s/disparo.tres" % ABILITIES_DIR)


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


# ── Colocación ──────────────────────────────────────────────────

func test_una_barrera_se_comporta_como_un_muro() -> void:
	var state := CombatState.new()

	assert_bool(state.place_barrier(Vector2i(2, 2), 1)).is_true()

	assert_int(state.terrain_at(Vector2i(2, 2))).is_equal(Terrain.Type.WALL)
	assert_bool(state.is_walkable(Vector2i(2, 2))).is_false()
	assert_bool(state.has_barrier(Vector2i(2, 2))).is_true()


func test_una_barrera_corta_la_linea_de_tiro() -> void:
	var state := CombatState.new()
	state.place_barrier(Vector2i(2, 0), 1)

	assert_bool(state.has_line_of_sight(Vector2i(0, 0), Vector2i(4, 0))).is_false()


func test_no_se_puede_levantar_donde_no_toca() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	state.set_terrain(Vector2i(0, 0), Terrain.Type.WALL)
	state.set_terrain(Vector2i(4, 4), Terrain.Type.VOID)
	state.place_barrier(Vector2i(3, 3), 1)

	assert_bool(state.place_barrier(Vector2i(2, 2), 1)).is_false()   # ocupada
	assert_bool(state.place_barrier(Vector2i(0, 0), 1)).is_false()   # ya es muro
	assert_bool(state.place_barrier(Vector2i(3, 3), 1)).is_false()   # ya hay barrera
	assert_bool(state.place_barrier(Vector2i(9, 9), 1)).is_false()   # fuera
	assert_bool(state.place_barrier(Vector2i(1, 1), 0)).is_false()   # sin duración


## El vacío queda fuera a propósito: una barrera es un muro, no un puente. Taparlo
## dejaría que una carta de coste 1 anulara el peligro más letal de la arena.
func test_no_se_puede_tapar_el_vacio() -> void:
	var state := CombatState.new()
	state.set_terrain(Vector2i(4, 4), Terrain.Type.VOID)

	assert_bool(state.place_barrier(Vector2i(4, 4), 1)).is_false()
	assert_bool(state.is_lethal(Vector2i(4, 4))).is_true()


func test_el_clon_se_lleva_las_barreras() -> void:
	var state := CombatState.new()
	state.place_barrier(Vector2i(2, 2), 2)

	var copy := state.clone()
	copy.tick_barriers()

	assert_int(copy.barrier_duration(Vector2i(2, 2))).is_equal(1)
	assert_int(state.barrier_duration(Vector2i(2, 2))).is_equal(2)


# ── Duración por carta (GDD §6) ─────────────────────────────────

## La barata es apuesta pura de predicción: bloquea la ronda en que la pusiste y se va.
func test_el_muro_dura_solo_su_ronda() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	var hero := state.hero()

	var events := _resolver(
		state,
		RoundChoice.new(hero.id).act(muro, Vector2i(1, 1)),
		RoundChoice.new(_rival(state).id),
	)

	assert_bool(state.has_barrier(Vector2i(1, 1))).is_false()

	var tipos := []
	for event in events:
		if event is BarrierPlaced or event is BarrierExpired:
			tipos.append(event.type)
	assert_array(tipos).contains_exactly([
		Event.Type.BARRIER_PLACED, Event.Type.BARRIER_EXPIRED,
	])


## La cara aguanta hasta el final de la siguiente: ya no es predicción, es zona negada.
func test_el_bastion_sobrevive_a_la_ronda_siguiente() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		RoundChoice.new(hero.id).act(bastion, Vector2i(1, 1)),
		RoundChoice.new(rival.id),
	)
	assert_bool(state.has_barrier(Vector2i(1, 1))).is_true()

	state.begin_round()
	_resolver(state, RoundChoice.new(hero.id), RoundChoice.new(rival.id))

	assert_bool(state.has_barrier(Vector2i(1, 1))).is_false()


# ── Orden de fases: negar es apostar ────────────────────────────

## El motivo de que las barreras sean la fase 1. Si se resolvieran después del
## movimiento no bloquearían nunca a nadie.
func test_la_barrera_bloquea_el_movimiento_de_la_misma_ronda() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(2, 2))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		RoundChoice.new(hero.id).act(muro, Vector2i(2, 1)),
		RoundChoice.new(rival.id).move(paso, Vector2i(2, 1)),
	)

	assert_that(rival.position).is_equal(Vector2i(2, 2))


## El pendiente que 1.9 dejó anotado: GDD §5 dice que el movimiento **se detiene contra
## la barrera**, no que se cancele. Entre elegir y resolver el tablero cambia, y quedarse
## clavado castigaría al jugador por algo que no podía prever.
func test_una_barrera_a_media_trayectoria_detiene_el_dash() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(0, 2))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		RoundChoice.new(hero.id).act(muro, Vector2i(2, 2)),
		RoundChoice.new(rival.id).move(impulso, Vector2i(2, 2)),
	)

	assert_that(rival.position).is_equal(Vector2i(1, 2))


func test_la_barrera_tapa_el_disparo_de_la_misma_ronda() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(3, 0))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		RoundChoice.new(rival.id).act(muro, Vector2i(2, 0)),
		RoundChoice.new(hero.id).act(disparo, Vector2i(3, 0)),
	)

	assert_int(rival.hp).is_equal(10)


## Sale gratis de que una barrera sea `WALL`: `Displacement` ya sabe qué hacer contra un
## muro, así que estrellar a alguien contra una barrera hace su daño de impacto sin que
## nadie escribiera esa regla.
func test_empujar_contra_una_barrera_hace_dano_de_impacto() -> void:
	var state := _estado(Vector2i(2, 3), Vector2i(2, 2))
	var rival := _rival(state)
	state.place_barrier(Vector2i(2, 1), 1)

	Displacement.push(state, rival.id, Vector2i(0, -1), 2)

	assert_that(rival.position).is_equal(Vector2i(2, 2))
	assert_int(rival.hp).is_equal(10 - Displacement.IMPACT_DAMAGE)


func test_la_barrera_cuesta_su_mana() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	var hero := state.hero()
	var mana_antes := hero.mana

	_resolver(
		state,
		RoundChoice.new(hero.id).act(muro, Vector2i(1, 1)),
		RoundChoice.new(_rival(state).id),
	)

	assert_int(hero.mana).is_equal(mana_antes - muro.mana_cost)
