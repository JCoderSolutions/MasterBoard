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
## El cuerpo de aquí es un **placeholder deliberado**: no hacer nada. La evaluación
## real —enumerar el espacio de acciones legales (1.16), simular por valor esperado
## (1.17), la función de tablero (1.18) y la profundidad como dificultad (1.19)— se
## construye encima de esta misma firma, sin tocarla.
static func decide(state: CombatState, unit_id: int) -> RoundChoice:
	return RoundChoice.new(unit_id)
