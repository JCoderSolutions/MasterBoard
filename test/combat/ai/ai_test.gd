extends GdUnitTestSuite

## Tests de Ai.decide() de punta a punta: lee el kit de las dos unidades desde `Unit`
## y la profundidad desde `Unit.search_depth`, sin que ninguna de las dos cosas toque
## la firma congelada por A-15 (backlog 1.16-1.19).

const ABILITIES_DIR := "res://resources/abilities"

var paso: Ability
var tajo: Ability


func before() -> void:
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	tajo = load("%s/tajo.tres" % ABILITIES_DIR)


func _estado(heroe: Vector2i, rival: Vector2i) -> CombatState:
	var state := CombatState.new()
	state.add_unit(Unit.Team.PLAYER, heroe)
	state.add_unit(Unit.Team.ENEMY, rival)
	return state


## El kit vive en `Unit`, no en un parámetro: `decide()` lo lee de ahí sin que la
## firma `(state, unit_id)` cambie.
func test_decide_usa_el_kit_de_la_propia_unidad() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	var rival := state.living_units(Unit.Team.ENEMY)[0]
	hero.kit = [tajo, paso]
	hero.hp = 3
	rival.hp = 2

	var choice := Ai.decide(state, hero.id)

	assert_object(choice.action).is_equal(tajo)
	assert_that(choice.action_target).is_equal(rival.position)


## Sin kit no hay nada que elegir salvo quedarse quieto — no revienta, no inventa
## habilidades que no tiene.
func test_sin_kit_solo_queda_quieto() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()

	assert_bool(Ai.decide(state, hero.id).is_empty()).is_true()


## `search_depth` por defecto es 1: nadie que no lo toque nota el cambio de 1.19.
func test_la_profundidad_por_defecto_es_uno() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()

	assert_int(hero.search_depth).is_equal(1)


## Subir la profundidad no debe cambiar ni un stat de combate — es el único dial de
## dificultad permitido (A-15, GDD: "la dificultad viene de que la IA lea mejor, no de
## que pegue más fuerte").
func test_la_profundidad_no_toca_ningun_stat_de_combate() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(4, 4))
	var hero := state.hero()
	var hp_antes := hero.hp
	var mana_antes := hero.mana
	var max_hp_antes := hero.max_hp

	hero.search_depth = 3

	assert_int(hero.hp).is_equal(hp_antes)
	assert_int(hero.mana).is_equal(mana_antes)
	assert_int(hero.max_hp).is_equal(max_hp_antes)


## Con más profundidad, decide() sigue devolviendo una jugada legal para la unidad
## pedida — más lento no significa distinto contrato.
func test_con_mas_profundidad_sigue_devolviendo_una_eleccion_valida() -> void:
	var state := _estado(Vector2i(2, 2), Vector2i(2, 1))
	var hero := state.hero()
	hero.kit = [tajo, paso]
	hero.search_depth = 2

	var choice := Ai.decide(state, hero.id)

	assert_int(choice.unit_id).is_equal(hero.id)
