class_name RoundChoice
extends RefCounted

## Lo que un bando eligió esta ronda: un movimiento y una habilidad (GDD §4).
##
## Las dos ranuras son opcionales. Quedarse quieto es una jugada —a veces la buena— y
## obligar a rellenar ambas convertiría la ronda en un trámite.
##
## Es el objeto que se elige **a ciegas**: ni la IA ni el jugador ven el del rival hasta
## que `Round` los resuelve juntos. Por eso existe como dato suelto y no como llamadas
## sueltas al resolver — dos elecciones que se apuestan a la vez tienen que poder
## construirse a la vez, y en el PvP futuro viajan por la red tal cual (A-02).

var unit_id: int = 0

## Habilidad de fase `MOVEMENT`. `null` = no se mueve.
var movement: Ability = null
var movement_target: Vector2i = Vector2i.ZERO

## Habilidad de cualquier otra fase. `null` = no actúa.
var action: Ability = null
var action_target: Vector2i = Vector2i.ZERO


func _init(p_unit_id: int = 0) -> void:
	unit_id = p_unit_id


## Encadenable, para que montar una elección quepa en una línea legible:
## `RoundChoice.new(id).move(paso, Vector2i(2, 1)).act(tajo, Vector2i(2, 0))`
func move(ability: Ability, target: Vector2i) -> RoundChoice:
	movement = ability
	movement_target = target
	return self


func act(ability: Ability, target: Vector2i) -> RoundChoice:
	action = ability
	action_target = target
	return self


func total_cost() -> int:
	var cost := 0
	if movement != null:
		cost += movement.mana_cost
	if action != null:
		cost += action.mana_cost
	return cost


func is_empty() -> bool:
	return movement == null and action == null


## `Round.resolve()` muta la elección que recibe —`_charge()` anula la ranura que no se
## pudo pagar—, así que quien reutilice la misma instancia contra varios estados
## distintos (la IA simulando, backlog 1.17) necesita una copia por resolución, o el
## efecto de una simulación se filtraría en la siguiente.
func clone() -> RoundChoice:
	var copy := RoundChoice.new(unit_id)
	copy.movement = movement
	copy.movement_target = movement_target
	copy.action = action
	copy.action_target = action_target
	return copy
