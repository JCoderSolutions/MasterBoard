extends GdUnitTestSuite

## Tests de Round: selección simultánea y resolución por fases (backlog 1.9, A-12).

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


func _rival(state: CombatState) -> Unit:
	return state.living_units(Unit.Team.ENEMY)[0]


func _eleccion(unit: Unit) -> RoundChoice:
	return RoundChoice.new(unit.id)


func _resolver(state: CombatState, a: RoundChoice, b: RoundChoice) -> Array[Event]:
	var choices: Array[RoundChoice] = [a, b]
	return Round.resolve(state, choices)


# ── Orden de fases ──────────────────────────────────────────────

## Las cuatro fases se marcan siempre, aunque no pase nada en ellas: el indicador de la
## UI (1.27) pasa por todas y no debe adivinar cuáles se saltaron.
func test_siempre_se_marcan_las_cuatro_fases_en_orden() -> void:
	var state := _estado(Vector2i(0, 0), Vector2i(4, 4))
	var hero := state.hero()

	var events := _resolver(state, _eleccion(hero), _eleccion(_rival(state)))

	var fases := []
	for event in events:
		if event is PhaseStarted:
			fases.append((event as PhaseStarted).phase)
	assert_array(fases).contains_exactly([
		Phase.Type.BARRIER, Phase.Type.MOVEMENT, Phase.Type.ATTACK, Phase.Type.TERRAIN,
	])


## La regla que da nombre a la fase de ataques: se resuelven desde las posiciones ya
## actualizadas. Moverse **es** esquivar.
func test_moverse_esquiva_el_ataque() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)

	# El héroe pega a la casilla donde el rival está *ahora*; el rival se va de ahí.
	_resolver(
		state,
		_eleccion(hero).act(tajo, Vector2i(2, 1)),
		_eleccion(rival).move(paso, Vector2i(2, 0)),
	)

	assert_that(rival.position).is_equal(Vector2i(2, 0))
	assert_int(rival.hp).is_equal(10)


func test_quedarse_quieto_come_el_golpe() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(state, _eleccion(hero).act(tajo, Vector2i(2, 1)), _eleccion(rival))

	assert_int(rival.hp).is_equal(7)


# ── Conflictos de movimiento (GDD §5) ───────────────────────────

func test_mismo_destino_rebota_a_los_dos() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 0))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		_eleccion(hero).move(paso, Vector2i(2, 1)),
		_eleccion(rival).move(paso, Vector2i(2, 1)),
	)

	assert_that(hero.position).is_equal(Vector2i(2, 2))
	assert_that(rival.position).is_equal(Vector2i(2, 0))


func test_el_intercambio_de_posiciones_esta_bloqueado() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		_eleccion(hero).move(paso, Vector2i(2, 1)),
		_eleccion(rival).move(paso, Vector2i(2, 2)),
	)

	assert_that(hero.position).is_equal(Vector2i(2, 2))
	assert_that(rival.position).is_equal(Vector2i(2, 1))


## Perseguir sí vale: quien huye libera la casilla y el otro entra detrás. Es el mismo
## bucle que bloquea el intercambio — la diferencia es que aquí no hay ciclo.
func test_perseguir_esta_permitido() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)

	_resolver(
		state,
		_eleccion(hero).move(paso, Vector2i(2, 1)),
		_eleccion(rival).move(paso, Vector2i(2, 0)),
	)

	assert_that(hero.position).is_equal(Vector2i(2, 1))
	assert_that(rival.position).is_equal(Vector2i(2, 0))


func test_un_muro_cancela_el_movimiento() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	state.set_terrain(Vector2i(2, 1), Terrain.Type.WALL)

	_resolver(state, _eleccion(hero).move(paso, Vector2i(2, 1)), _eleccion(_rival(state)))

	assert_that(hero.position).is_equal(Vector2i(2, 2))


# ── Ataques simultáneos ─────────────────────────────────────────

## Morir en la fase de ataques **no** cancela tu golpe. Sin esto, el orden interno de la
## fase decidiría partidas y volvería la resolución asimétrica, que es justo lo que A-12
## quiso evitar. Es también lo que hace posible el empate del GDD §4.
func test_los_dos_pueden_matarse_en_la_misma_ronda() -> void:
	var state := CombatState.new()
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 2), 3)
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1), 3)

	_resolver(
		state,
		_eleccion(hero).act(tajo, Vector2i(2, 1)),
		_eleccion(rival).act(tajo, Vector2i(2, 2)),
	)

	assert_bool(hero.is_alive()).is_false()
	assert_bool(rival.is_alive()).is_false()


## Pero morir **antes** de la fase de ataques sí te deja fuera: las fases están
## ordenadas, y caerse al vacío pasó en la anterior.
func test_caer_al_vacio_al_moverse_cancela_tu_ataque() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 0))
	var hero := state.hero()
	var rival := _rival(state)
	state.set_terrain(Vector2i(2, 3), Terrain.Type.VOID)

	_resolver(
		state,
		_eleccion(hero).move(paso, Vector2i(2, 3)).act(tajo, Vector2i(2, 0)),
		_eleccion(rival),
	)

	assert_bool(hero.is_alive()).is_false()
	assert_int(rival.hp).is_equal(10)


# ── Fase 4: terreno ─────────────────────────────────────────────

func test_acabar_sobre_un_peligro_hace_dano() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	state.set_terrain(Vector2i(2, 1), Terrain.Type.HAZARD)

	_resolver(state, _eleccion(hero).move(paso, Vector2i(2, 1)), _eleccion(_rival(state)))

	assert_int(hero.hp).is_equal(10 - Terrain.HAZARD_DAMAGE)


## El motivo de que el terreno sea la última fase: empujar a alguien a la lava funciona
## en la misma ronda, y el daño se cobra una sola vez aunque llegara empujado.
func test_empujar_a_la_lava_funciona_en_la_misma_ronda() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)
	state.set_terrain(Vector2i(2, 0), Terrain.Type.HAZARD)

	_resolver(state, _eleccion(hero).act(embestida, Vector2i(2, 1)), _eleccion(rival))

	assert_that(rival.position).is_equal(Vector2i(2, 0))
	# 1 del golpe + 1 de impacto contra el borde + 2 del peligro, cobrado una sola vez.
	assert_int(rival.hp).is_equal(10 - 1 - Displacement.IMPACT_DAMAGE - Terrain.HAZARD_DAMAGE)


# ── Maná ────────────────────────────────────────────────────────

## Se paga al comprometerse. Si el golpe falla porque el rival se movió, igual lo
## pagaste: es el castigo por leer mal, y es la mitad del juego.
func test_el_ataque_esquivado_se_paga_igual() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)
	var mana_antes := hero.mana

	_resolver(
		state,
		_eleccion(hero).act(tajo, Vector2i(2, 1)),
		_eleccion(rival).move(paso, Vector2i(2, 0)),
	)

	assert_int(hero.mana).is_equal(mana_antes - tajo.mana_cost)
	assert_int(rival.hp).is_equal(10)


func test_el_paso_basico_es_gratis() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var mana_antes := hero.mana

	_resolver(state, _eleccion(hero).move(paso, Vector2i(2, 1)), _eleccion(_rival(state)))

	assert_int(hero.mana).is_equal(mana_antes)
	assert_that(hero.position).is_equal(Vector2i(2, 1))


## Quedarse sin maná no debe dejarte además clavado en el sitio: el movimiento se cobra
## primero, así que lo que se cae es la habilidad.
func test_sin_mana_se_pierde_la_habilidad_no_el_movimiento() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)
	hero.burn_mana(hero.mana)  # a cero

	_resolver(
		state,
		_eleccion(hero).move(paso, Vector2i(2, 3)).act(tajo, Vector2i(2, 1)),
		_eleccion(rival),
	)

	assert_that(hero.position).is_equal(Vector2i(2, 3))
	assert_int(rival.hp).is_equal(10)


func test_una_habilidad_en_la_ranura_equivocada_se_descarta() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := _rival(state)
	var mana_antes := hero.mana

	# `impulso` es de fase MOVEMENT: en la ranura de habilidad no hace nada ni cobra.
	_resolver(state, _eleccion(hero).act(impulso, Vector2i(2, 4)), _eleccion(rival))

	assert_that(hero.position).is_equal(Vector2i(2, 2))
	assert_int(hero.mana).is_equal(mana_antes)


# ── Determinismo (A-03, R-02) ───────────────────────────────────

## El criterio de aceptación de la Fase 1A: mismas elecciones y misma semilla, mismo
## resultado. Sin esto no hay replays, ni IA que simule, ni PvP por comandos.
func test_mismas_elecciones_mismo_resultado() -> void:
	assert_str(_partida()).is_equal(_partida())


func _partida() -> String:
	var state := CombatState.new(48211)
	var hero := state.add_unit(Unit.Team.PLAYER, Vector2i(2, 3))
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(2, 1))
	state.set_terrain(Vector2i(0, 0), Terrain.Type.HAZARD)

	var firma := PackedStringArray()
	for i in 3:
		var events := _resolver(
			state,
			_eleccion(hero).move(paso, Vector2i(2, 2)).act(embestida, Vector2i(2, 1)),
			_eleccion(rival).move(impulso, Vector2i(2, 0)).act(tajo, Vector2i(2, 2)),
		)
		for event in events:
			firma.append(str(event))
		state.begin_round()

	firma.append("hp=%d/%d mana=%d/%d" % [hero.hp, rival.hp, hero.mana, rival.mana])
	return " | ".join(firma)
