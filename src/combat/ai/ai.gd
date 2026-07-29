class_name Ai
extends RefCounted

## Decide la jugada del rival (A-15).
##
## La firma es la garantía de honestidad, y por eso se escribe **antes** que la
## decisión real (backlog 1.15): recibe el estado del combate y a quién le toca
## decidir, y nada más. Ningún parámetro puede llevar la elección del jugador porque
## ninguno existe para eso.
##
## Como ambos bandos eligen a la vez, sería trivial —y tentador, por rendimiento—
## pasarle a esto la elección que el jugador ya tomó "ya que la tenemos ahí". El juego
## seguiría funcionando y se volvería injusto en silencio: no crashea, solo hace que
## perder se sienta mal sin que nadie sepa por qué. `test/combat/ai/ai_honesty_test.gd`
## congela esta firma con reflexión para que ese cambio no pueda colarse callado.
##
## El cuerpo de aquí ya piensa de verdad (1.16-1.17): enumera el espacio de jugadas
## legales de las dos unidades con `ActionSpace` —el suyo para actuar, el del rival
## para simular sus respuestas posibles, público por GDD §3/R-04 y explícitamente
## permitido por A-15— y elige con `ExpectedValueSearch` la que mejor promedio da con
## `BoardEvaluation` de por medio. `BoardEvaluation` sigue siendo un placeholder
## (1.18 le falta maná, peligro y casillas seguras) y la profundidad de 1.19 todavía no
## existe, pero ninguna de las dos cosas toca esta firma cuando lleguen.
##
## Si no hay rival vivo al que responder, no hay nada que optimizar: se queda quieto.
## En el MVP 1v1 solo puede haber uno; el día que exista 2v2, sumar sus jugadas es
## trabajo de quien reabra esta función, no una suposición que deba colarse aquí.
static func decide(state: CombatState, unit_id: int) -> RoundChoice:
	var unit := state.unit_by_id(unit_id)
	if unit == null or not unit.is_alive():
		return RoundChoice.new(unit_id)

	var opponents := state.living_units(Unit.opposing_team(unit.team))
	if opponents.is_empty():
		return RoundChoice.new(unit_id)
	var opponent := opponents[0]

	var own_choices := ActionSpace.legal_choices(state, unit, unit.kit)
	var opponent_choices := ActionSpace.legal_choices(state, opponent, opponent.kit)

	return ExpectedValueSearch.best_choice(
		state, unit_id, own_choices, opponent.id, opponent_choices, BoardEvaluation.score
	)
