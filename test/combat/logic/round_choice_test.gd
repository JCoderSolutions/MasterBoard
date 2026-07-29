extends GdUnitTestSuite

## Tests de RoundChoice: construcción encadenable, coste y clonado (backlog 1.17).

const ABILITIES_DIR := "res://resources/abilities"

var paso: Ability
var tajo: Ability


func before() -> void:
	paso = load("%s/paso.tres" % ABILITIES_DIR)
	tajo = load("%s/tajo.tres" % ABILITIES_DIR)


func test_una_eleccion_nueva_esta_vacia() -> void:
	var choice := RoundChoice.new(1)

	assert_bool(choice.is_empty()).is_true()
	assert_int(choice.total_cost()).is_equal(0)


func test_move_y_act_se_encadenan() -> void:
	var choice := RoundChoice.new(1).move(paso, Vector2i(2, 1)).act(tajo, Vector2i(2, 0))

	assert_bool(choice.is_empty()).is_false()
	assert_object(choice.movement).is_equal(paso)
	assert_that(choice.movement_target).is_equal(Vector2i(2, 1))
	assert_object(choice.action).is_equal(tajo)
	assert_int(choice.total_cost()).is_equal(paso.mana_cost + tajo.mana_cost)


## Es la garantía que necesita la IA al simular (1.17): `Round.resolve()` anula la
## ranura que no se pudo pagar, así que reutilizar la misma instancia contra distintos
## clones filtraría el resultado de una simulación en la siguiente. `clone()` corta esa
## dependencia.
func test_clonar_produce_una_copia_independiente() -> void:
	var original := RoundChoice.new(1).move(paso, Vector2i(2, 1)).act(tajo, Vector2i(2, 0))

	var copy := original.clone()
	copy.movement = null
	copy.action_target = Vector2i(4, 4)

	assert_object(original.movement).is_equal(paso)
	assert_that(original.action_target).is_equal(Vector2i(2, 0))
	assert_object(copy.movement).is_null()
	assert_that(copy.action_target).is_equal(Vector2i(4, 4))
	assert_int(copy.unit_id).is_equal(original.unit_id)
