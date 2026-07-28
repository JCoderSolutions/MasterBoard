class_name ActionSpace
extends RefCounted

## Enumera las jugadas legales de una unidad esta ronda, dado su maná y su kit
## (backlog 1.16). Es lo que 1.17 va a recorrer para simular: clonar el estado, probar
## cada jugada de aquí, quedarse con la de mejor valor esperado.
##
## Vive en `ai/` y no en `logic/` a propósito (A-06: "Decisión del rival. Consume
## logic/, nunca view/"). No es una utilidad general de combate — el jugador humano no
## necesita el producto cartesiano de sus opciones, elige ability y target directamente
## en la UI (1.26) apoyándose en `Ability.valid_targets()`, que ya existe desde 1.8.
## Esto es infraestructura de decisión, y solo la IA la recorre.

## Un candidato para una ranura: una habilidad y dónde apuntarla. `ability == null`
## representa **no elegir nada en esa ranura**, que siempre es una jugada legal —
## quedarse quieto puede ser la mejor, y por eso `RoundChoice` ya lo permite.
class Option:
	var ability: Ability
	var target: Vector2i

	func _init(p_ability: Ability = null, p_target: Vector2i = Vector2i.ZERO) -> void:
		ability = p_ability
		target = p_target


	func cost() -> int:
		return ability.mana_cost if ability != null else 0


## Todas las jugadas legales de `unit` con `kit` en `state`. Incluye siempre el
## "quedarse quieto en las dos ranuras", así que nunca devuelve un array vacío para una
## unidad viva — la IA siempre tiene algo que elegir, aunque sea nada.
##
## No es solo el producto cartesiano de "toda habilidad pagable por separado": el
## maná se cobra de un único pozo para las dos ranuras a la vez (`Round._charge()`), así
## que la condición real es `coste_movimiento + coste_acción <= maná`, no cada coste
## por separado. Una combinación que por sí sola sería impagable —aunque cada mitad
## quepa sola— no se enumera nunca; enumerarla y dejar que el resolver la recorte en
## silencio le mentiría a quien la esté evaluando.
static func legal_choices(state: CombatState, unit: Unit, kit: Array[Ability]) -> Array[RoundChoice]:
	var result: Array[RoundChoice] = []
	if unit == null or not unit.is_alive():
		return result

	var movements := _movement_options(state, unit, kit)
	var actions := _action_options(state, unit, kit)

	for movement in movements:
		for action in actions:
			if movement.cost() + action.cost() > unit.mana:
				continue
			var choice := RoundChoice.new(unit.id)
			if movement.ability != null:
				choice.move(movement.ability, movement.target)
			if action.ability != null:
				choice.act(action.ability, action.target)
			result.append(choice)
	return result


static func _movement_options(state: CombatState, unit: Unit, kit: Array[Ability]) -> Array[Option]:
	return _options(state, unit, kit, func(ability: Ability) -> bool:
		return ability.phase == Phase.Type.MOVEMENT
	)


## Acepta cualquier fase seleccionable que no sea `MOVEMENT`: GDD §5 pone barreras y
## ataques en la misma ranura, la de "habilidad".
static func _action_options(state: CombatState, unit: Unit, kit: Array[Ability]) -> Array[Option]:
	return _options(state, unit, kit, func(ability: Ability) -> bool:
		return Phase.is_selectable(ability.phase) and ability.phase != Phase.Type.MOVEMENT
	)


## Candidatos de una ranura: siempre empieza por "nada", y añade cada (habilidad,
## casilla) que encaja en la ranura (`fits_slot`), es pagable en solitario y tiene
## objetivo válido.
static func _options(
	state: CombatState,
	unit: Unit,
	kit: Array[Ability],
	fits_slot: Callable,
) -> Array[Option]:
	var options: Array[Option] = [Option.new()]

	for ability in kit:
		if ability == null or not fits_slot.call(ability):
			continue
		if not ability.can_afford(unit):
			continue
		for target in ability.valid_targets(state, unit):
			options.append(Option.new(ability, target))
	return options
