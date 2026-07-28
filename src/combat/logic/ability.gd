class_name Ability
extends Resource

## Una habilidad: coste, targeting y una lista de efectos componibles (A-04).
##
## Es **dato**, no código. Añadir una habilidad nueva es crear un `.tres`, y eso es el
## criterio de aceptación de este sistema (goal #6 del GDD): el balance son cientos de
## iteraciones pequeñas, y si cada ajuste toca un `.gd` no vas a iterar lo suficiente.
##
## **No cobra el maná.** Lo cobra la ronda al confirmar la elección, no al resolverla
## (backlog 1.9), y la diferencia es de diseño, no de fontanería: se paga al
## comprometerse. Si una habilidad falla porque el rival se movió, **igual la pagaste**.
## Cobrar aquí devolvería el maná de los golpes esquivados y borraría el castigo por
## leer mal, que es justo lo que el juego quiere premiar.

@export_group("Identidad")
## Id estable. Los replays y el PvP futuro referencian habilidades por este string,
## así que renombrarlo rompe partidas guardadas — el nombre visible se cambia sin miedo.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Coste y targeting")
@export var mana_cost: int = 0
@export var targeting: Targeting.Mode = Targeting.Mode.UNIT
@export var max_range: int = 1
## Solo para ataques que viajan. Un golpe cuerpo a cuerpo no lo necesita y una habilidad
## de área tampoco: esa apunta a una casilla y afecta a su entorno.
@export var requires_line_of_sight: bool = false

@export_group("Efectos")
## Se aplican **en orden**, y el orden importa: `[Daño, Empuje]` mata antes de mover,
## `[Empuje, Daño]` mueve y luego pega a una casilla vacía. Es el sitio donde el balance
## de una habilidad se decide de verdad.
@export var effects: Array[Effect] = []


func can_afford(caster: Unit) -> bool:
	return caster != null and caster.is_alive() and caster.can_afford(mana_cost)


func is_valid_target(state: CombatState, caster: Unit, target: Vector2i) -> bool:
	return Targeting.is_valid(
		state, caster, targeting, target, max_range, requires_line_of_sight
	)


## Las casillas que el jugador puede tocar. La usan la previsualización (1.26) y la
## enumeración de acciones de la IA (1.16), y tienen que dar exactamente lo mismo.
func valid_targets(state: CombatState, caster: Unit) -> Array[Vector2i]:
	return Targeting.valid_targets(
		state, caster, targeting, max_range, requires_line_of_sight
	)


## Resuelve la habilidad y narra lo que pasó. Devuelve vacío si no era ejecutable.
##
## Comprueba el maná además del objetivo aunque no lo cobre: una habilidad impagable no
## debe resolverse aunque alguien la cuele por error.
func apply(state: CombatState, caster_id: int, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []

	var caster := state.unit_by_id(caster_id)
	if not can_afford(caster):
		return events
	if not is_valid_target(state, caster, target):
		return events

	for effect in effects:
		if effect != null:
			events.append_array(effect.apply(state, caster, target))
	return events
