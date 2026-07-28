extends GdUnitTestSuite

## El test de honestidad de la IA (A-15, backlog 1.15).
##
## Se escribe **antes** que la decisión real: congela la firma de `Ai.decide()` con
## reflexión para que ningún cambio futuro pueda colarle la elección del jugador "ya
## que la tenemos ahí". Un cambio así no debe compilar en silencio, tiene que hacer
## fallar un test con nombre explícito que diga por qué.

const ROUND_CHOICE_CLASS := "RoundChoice"

## Godot no expone `METHOD_FLAG_STATIC` como constante en GDScript; es el bit 32 del
## `MethodFlags` de `Object` (`NORMAL=1, EDITOR=2, CONST=4, VIRTUAL=8, VARARG=16,
## STATIC=32`), estable desde Godot 3. Documentado aquí para que el número no quede
## mágico.
const METHOD_FLAG_STATIC := 32


func _decide_method() -> Dictionary:
	for m in Ai.new().get_method_list():
		if m.name == "decide":
			return m
	return {}


func test_decide_existe_y_es_estatico() -> void:
	var method := _decide_method()

	assert_bool(method.is_empty()).is_false()
	assert_bool(bool(method.flags & METHOD_FLAG_STATIC)).is_true()


## La garantía en sí: ni un parámetro de `decide()` puede ser el `RoundChoice` que el
## jugador acaba de elegir. Si algún día alguien añade ese parámetro "por comodidad",
## este assert lo detecta antes de que se juegue una sola partida con él.
func test_decide_no_recibe_ningun_round_choice() -> void:
	var method := _decide_method()

	for arg in method.args:
		assert_str(String(arg.class_name)).is_not_equal(ROUND_CHOICE_CLASS)


## No es solo que no lleve un `RoundChoice`: no lleva nada más que el estado y a quién
## le toca. Cualquier parámetro adicional es, por definición, una vía para colar algo
## que no debería estar ahí.
func test_decide_solo_recibe_el_estado_y_a_quien_le_toca() -> void:
	var method := _decide_method()

	assert_int(method.args.size()).is_equal(2)


## Segunda capa de la misma garantía, por la puerta de atrás: si `CombatState` guardara
## la elección de alguien en un campo propio "para no tener que pasarla por
## parámetro", `decide()` la vería igual sin que su firma cambiara nunca.
func test_combat_state_no_guarda_ningun_round_choice() -> void:
	for prop in CombatState.new().get_property_list():
		assert_str(String(prop.get("class_name", ""))).is_not_equal(ROUND_CHOICE_CLASS)


# ── Que además funcione ─────────────────────────────────────────

func test_decide_devuelve_una_eleccion_para_la_unidad_pedida() -> void:
	var state := CombatState.new()
	var rival := state.add_unit(Unit.Team.ENEMY, Vector2i(4, 4))
	state.add_unit(Unit.Team.PLAYER, Vector2i(0, 0))

	var choice := Ai.decide(state, rival.id)

	assert_object(choice).is_not_null()
	assert_int(choice.unit_id).is_equal(rival.id)


func test_decide_no_revienta_con_una_unidad_inexistente() -> void:
	var state := CombatState.new()

	assert_object(Ai.decide(state, 999)).is_not_null()
