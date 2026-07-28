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
## En qué fase actúa (A-12). Determina además en qué ranura se elige: las de `MOVEMENT`
## ocupan la de movimiento, todas las demás la de habilidad.
@export var phase: Phase.Type = Phase.Type.ATTACK
@export var targeting: Targeting.Mode = Targeting.Mode.UNIT
@export var max_range: int = 1
## Solo para ataques que viajan. Un golpe cuerpo a cuerpo no lo necesita y una habilidad
## de área tampoco: esa apunta a una casilla y afecta a su entorno.
@export var requires_line_of_sight: bool = false
## Prohíbe las diagonales. Existe por el movimiento básico del GDD §4, que es de una
## casilla **ortogonal**: sin esto el paso gratis llegaría también en diagonal y dejaría
## sin sentido a las habilidades de desplazamiento que sí las permiten.
@export var orthogonal_only: bool = false

@export_group("Efectos")
## Se aplican **en orden**, y el orden importa: `[Daño, Empuje]` mata antes de mover,
## `[Empuje, Daño]` mueve y luego pega a una casilla vacía. Es el sitio donde el balance
## de una habilidad se decide de verdad.
@export var effects: Array[Effect] = []


func can_afford(caster: Unit) -> bool:
	return caster != null and caster.is_alive() and caster.can_afford(mana_cost)


func is_valid_target(state: CombatState, caster: Unit, target: Vector2i) -> bool:
	if not Targeting.is_valid(
		state, caster, targeting, target, max_range, requires_line_of_sight
	):
		return false
	if orthogonal_only and caster.position.x != target.x and caster.position.y != target.y:
		return false
	return true


## Las casillas que el jugador puede tocar. La usan la previsualización (1.26) y la
## enumeración de acciones de la IA (1.16), y tienen que dar exactamente lo mismo.
func valid_targets(state: CombatState, caster: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if caster == null:
		return result
	for pos in Targeting.valid_targets(
		state, caster, targeting, max_range, requires_line_of_sight
	):
		if is_valid_target(state, caster, pos):
			result.append(pos)
	return result


## Comprueba que la jugada es legal y la resuelve. Devuelve vacío si no lo era.
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

	return resolve(state, caster, target)


## Aplica los efectos **sin volver a validar nada**. Lo usa `Round`, que ya validó al
## cobrar el maná y no puede validar otra vez aquí: para cuando llega la fase de ataques,
## el objetivo puede haberse movido —y entonces el golpe da al aire, que es el juego— o
## quien lanza puede haber muerto en esta misma fase, y aun así su golpe sale. Sin eso no
## existiría el empate por doble muerte del GDD §4.
func resolve(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []
	if caster == null:
		return events

	for effect in effects:
		if effect != null:
			events.append_array(effect.apply(state, caster, target))
	return events
