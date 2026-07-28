class_name Round
extends RefCounted

## Resuelve una ronda: dos elecciones tomadas a ciegas, un orden de fases fijo (A-12).
##
## Es la unidad de ejecución del combate. Un comando suelto ya no significa nada: lo que
## significa algo es "ambos apostaron y esto es lo que pasó".
##
## **Por qué fases y no equipos alternos.** Alternar da ventaja estructural a quien
## resuelve primero: sus unidades se mueven y matan antes de que el otro actúe, así que
## las acciones del segundo apuntan a posiciones que ya cambiaron. Y alternar quién
## empieza no lo arregla, convierte la paridad del número de ronda en un factor de
## victoria. Lo valioso de apostar a ciegas es que **ambos apostaron en las mismas
## condiciones**; si uno resuelve primero, el otro apostó contra alguien que ya sabía que
## actuaría antes. La simetría es el producto.
##
## La legibilidad que se pierde la recupera la presentación: esto devuelve un
## `Array[Event]` ordenado y con marcas de fase, y la cola de animación lo reproduce en
## secuencia (R-08).


## Resuelve la ronda entera y narra lo que pasó.
##
## **No avanza la ronda ni reparte maná**: eso es `CombatState.begin_round()`, y lo llama
## el bucle de partida. Entre una cosa y la otra hay que comprobar si alguien murió
## (backlog 1.13), así que mezclarlas dejaría el fin de partida sin sitio donde mirar.
static func resolve(state: CombatState, choices: Array[RoundChoice]) -> Array[Event]:
	var events: Array[Event] = []

	# Orden estable por id: dos unidades pueden actuar en la misma fase, y sin un
	# criterio fijo el resultado dependería de cómo llegó el array (A-03).
	var ordered := choices.duplicate()
	ordered.sort_custom(func(a: RoundChoice, b: RoundChoice) -> bool:
		return a.unit_id < b.unit_id
	)

	_charge(state, ordered)

	events.append_array(_barrier_phase(state, ordered))
	events.append_array(_movement_phase(state, ordered))
	events.append_array(_attack_phase(state, ordered))
	events.append_array(_terrain_phase(state))
	events.append_array(_expire_barriers(state))
	events.append_array(_expire_shields(state))
	return events


# ── Pago ────────────────────────────────────────────────────────

## Cobra el maná **al comprometerse**, antes de resolver nada.
##
## Es una regla de diseño, no fontanería: si una habilidad falla porque el rival se
## movió, igual la pagaste. Cobrar al resolver devolvería el maná de los golpes
## esquivados y borraría el castigo por leer mal, que es justo lo que el juego premia.
##
## Lo que no se puede pagar se descarta en silencio. El movimiento se cobra primero para
## que quedarse sin maná nunca te deje además clavado en el sitio.
static func _charge(state: CombatState, choices: Array[RoundChoice]) -> void:
	for choice in choices:
		var unit := state.unit_by_id(choice.unit_id)
		if unit == null or not unit.is_alive():
			choice.movement = null
			choice.action = null
			continue

		if choice.movement != null:
			if choice.movement.phase != Phase.Type.MOVEMENT:
				choice.movement = null
			elif not unit.spend_mana(choice.movement.mana_cost):
				choice.movement = null

		if choice.action != null:
			if not Phase.is_selectable(choice.action.phase):
				choice.action = null
			elif choice.action.phase == Phase.Type.MOVEMENT:
				choice.action = null
			elif not unit.spend_mana(choice.action.mana_cost):
				choice.action = null


# ── Fase 1: barreras ────────────────────────────────────────────

static func _barrier_phase(state: CombatState, choices: Array[RoundChoice]) -> Array[Event]:
	var events: Array[Event] = []
	events.append(PhaseStarted.new(Phase.Type.BARRIER))

	for choice in choices:
		if choice.action == null or choice.action.phase != Phase.Type.BARRIER:
			continue
		var unit := state.unit_by_id(choice.unit_id)
		if unit == null or not unit.is_alive():
			continue
		events.append_array(choice.action.resolve(state, unit, choice.action_target))
	return events


# ── Fase 2: movimiento ──────────────────────────────────────────

## Resuelve los movimientos de ambos bandos a la vez, con los conflictos de GDD §5.
##
## El algoritmo es una sola idea: **un movimiento se ejecuta en cuanto es posible, y lo
## que nunca llega a ser posible se cancela.** De ahí salen las tres reglas de la tabla
## sin escribirlas por separado:
##
## - *Mismo destino* → se detecta antes y se cancelan ambos (rebote).
## - *Intercambio* → es un ciclo: ninguno de los dos puede ejecutarse nunca porque cada
##   uno espera a que el otro libere su casilla. Se quedan fuera del bucle y se cancelan.
## - *Persecución* → no es un ciclo: quien huye se ejecuta, libera la casilla, y en la
##   siguiente vuelta el perseguidor ya puede entrar.
##
## Que el rebote sea simétrico en vez de desempatar por una stat es deliberado: un
## desempate por velocidad convierte la decisión en una consulta de tabla y le regala la
## casilla disputada al personaje rápido en cada partida.
static func _movement_phase(state: CombatState, choices: Array[RoundChoice]) -> Array[Event]:
	var events: Array[Event] = []
	events.append(PhaseStarted.new(Phase.Type.MOVEMENT))

	var pending: Array[RoundChoice] = []
	for choice in choices:
		if choice.movement == null:
			continue
		var unit := state.unit_by_id(choice.unit_id)
		if unit != null and unit.is_alive():
			pending.append(choice)

	_cancel_shared_destinations(pending)

	var progressed := true
	while progressed and not pending.is_empty():
		progressed = false
		for choice in pending.duplicate():
			var unit := state.unit_by_id(choice.unit_id)
			if not MoveCommand.new(unit.id, choice.movement_target).validate(state):
				continue
			events.append_array(
				choice.movement.resolve(state, unit, choice.movement_target)
			)
			pending.erase(choice)
			progressed = true

	# Lo que queda no puede completarse. Se resuelve igual, y el movimiento avanza lo
	# que pueda (GDD §5): si una barrera te tapó el destino después de que lo eligieras,
	# te detienes contra ella en vez de quedarte clavado.
	#
	# Los ciclos siguen bloqueados sin regla aparte: en un intercambio, cada uno tiene
	# al otro en la casilla de al lado, así que "lo que pueda" son cero casillas.
	for choice in pending:
		var unit := state.unit_by_id(choice.unit_id)
		events.append_array(choice.movement.resolve(state, unit, choice.movement_target))

	return events


## Si dos unidades apuntan a la misma casilla, ninguna entra.
static func _cancel_shared_destinations(pending: Array[RoundChoice]) -> void:
	var disputed: Array[Vector2i] = []
	for i in pending.size():
		for j in range(i + 1, pending.size()):
			if pending[i].movement_target == pending[j].movement_target:
				if not disputed.has(pending[i].movement_target):
					disputed.append(pending[i].movement_target)

	for choice in pending.duplicate():
		if disputed.has(choice.movement_target):
			pending.erase(choice)


# ── Fase 3: ataques ─────────────────────────────────────────────

## Los ataques son **simultáneos**: quien muere aquí igual asesta su golpe.
##
## Sin esto no existiría el empate por doble muerte que promete el GDD §4, y el orden
## interno de la fase decidiría partidas — que es exactamente lo que A-12 quiso evitar.
## Quien murió **antes** de esta fase (una caída al vacío al moverse) sí queda fuera: las
## fases están ordenadas, y esa muerte ocurrió en la anterior.
static func _attack_phase(state: CombatState, choices: Array[RoundChoice]) -> Array[Event]:
	var events: Array[Event] = []
	events.append(PhaseStarted.new(Phase.Type.ATTACK))

	var attackers: Array[RoundChoice] = []
	for choice in choices:
		if choice.action == null or choice.action.phase != Phase.Type.ATTACK:
			continue
		var unit := state.unit_by_id(choice.unit_id)
		if unit != null and unit.is_alive():
			attackers.append(choice)

	for choice in attackers:
		var unit := state.unit_by_id(choice.unit_id)
		if not _reaches(state, unit, choice.action, choice.action_target):
			continue
		events.append_array(choice.action.resolve(state, unit, choice.action_target))
	return events


## Lo único que se comprueba de nuevo al resolver un ataque: que **llegue**.
##
## Hay que distinguir dos cosas que parecen la misma. Si el rival se movió, el golpe sale
## igual y da en el aire: eso es esquivar, y no se comprueba nada. Pero si algo se
## interpuso en la trayectoria —una barrera de la fase 1— el disparo no llega, y
## bloquearlo es precisamente lo que se pagó al levantar el muro (GDD §6).
##
## Se mide desde la posición **actual** de quien dispara, no desde la que tenía al
## elegir. Moverse y disparar hay que planearlos juntos: si tu propio movimiento te deja
## sin línea, te quedas sin tiro. Es información que el jugador tiene entera antes de
## confirmar, así que es una decisión, no una trampa.
static func _reaches(
	state: CombatState,
	caster: Unit,
	ability: Ability,
	target: Vector2i,
) -> bool:
	if not ability.requires_line_of_sight:
		return true
	return state.has_line_of_sight(caster.position, target)


# ── Fase 4: terreno ─────────────────────────────────────────────

## El peligro se cobra aquí y solo aquí, dé igual si llegaste andando, de un dash o
## empujado. Es lo que permite que tirar a alguien a la lava funcione en la misma ronda
## sin cobrarle el daño dos veces.
static func _terrain_phase(state: CombatState) -> Array[Event]:
	var events: Array[Event] = []
	events.append(PhaseStarted.new(Phase.Type.TERRAIN))

	for unit in state.units:
		if not unit.is_alive():
			continue
		if state.terrain_at(unit.position) == Terrain.Type.HAZARD:
			events.append_array(Damage.apply(unit, Terrain.HAZARD_DAMAGE))
	return events


# ── Cierre de ronda ─────────────────────────────────────────────

## Las barreras caducan al final, no en una fase.
##
## No es una fase porque nadie lo elige y nada puede reaccionar a ello: es el reloj de la
## ronda corriendo. Ponerlo antes del terreno dejaría caer un muro justo a tiempo de que
## alguien se comiera la lava que tapaba, y eso no lo decidió ninguno de los dos.
static func _expire_barriers(state: CombatState) -> Array[Event]:
	var events: Array[Event] = []
	for pos in state.tick_barriers():
		events.append(BarrierExpired.new(pos))
	return events


## Los escudos caducan al final por el mismo reloj que las barreras. Se descuenta
## después de la fase de terreno, así que un escudo de 1 ronda absorbe el golpe **y** la
## lava de la ronda en que se puso, y se va justo al cerrarla — no antes.
static func _expire_shields(state: CombatState) -> Array[Event]:
	var events: Array[Event] = []
	for unit in state.units:
		if unit.tick_shield():
			events.append(ShieldExpired.new(unit.id))
	return events
