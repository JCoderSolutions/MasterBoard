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
## El cuerpo de aquí ya piensa de verdad (1.16-1.19): usa `ExpectedValueSearch` con
## `BoardEvaluation` para elegir la jugada de mejor promedio contra las respuestas
## posibles del rival —público por GDD §3/R-04 y explícitamente permitido por A-15—,
## mirando `unit.search_depth` rondas hacia delante. La dificultad vive ahí y solo
## ahí: cambiar cuánto lee la IA no toca ni un campo de combate de `Unit` (A-15,
## `Unit.search_depth`).
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

	return ExpectedValueSearch.best_choice(
		state, unit_id, unit.kit, opponent.id, opponent.kit, BoardEvaluation.score,
		unit.search_depth,
	)
