class_name ExpectedValueSearch
extends RefCounted

## Elige la jugada que maximiza el valor esperado, promediando sobre todas las
## respuestas legales del rival (backlog 1.17).
##
## No es hacer trampa mirar las jugadas *posibles* del rival — A-15 lo permite
## explícitamente ("la IA sí puede clonar el estado y simular las acciones posibles del
## jugador, eso es leer, no hacer trampa"). Lo que nunca llega aquí es la que *de
## verdad* eligió esta ronda: `ActionSpace` solo conoce reglas públicas (maná, kit,
## targeting), nunca una elección oculta.
##
## Es **promedio**, no minimax: para cada jugada propia, la nota final es la media de
## cómo le fue contra cada respuesta posible del rival, no la peor de todas. Un rival
## que también decide a ciegas no puede jugar "y si hace lo peor para mí en concreto",
## porque el rival tampoco sabe qué elegiste tú — precisamente la simetría que A-12
## protege. Minimax asumiría un rival que ya sabe tu jugada, que es el tipo de ventaja
## injusta que A-15 existe para prohibir.


## Recorre `own_choices × opponent_choices`, resuelve cada par sobre un clon y
## promedia `evaluate(estado_resultante, unit_id)` por jugada propia. Se queda con la
## de mejor promedio; en empate, gana la primera en aparecer — determinista, sin azar
## (A-03), así que la misma entrada siempre da la misma salida.
static func best_choice(
	state: CombatState,
	unit_id: int,
	own_choices: Array[RoundChoice],
	opponent_id: int,
	opponent_choices: Array[RoundChoice],
	evaluate: Callable,
) -> RoundChoice:
	var best: RoundChoice = own_choices[0]
	var best_value := -INF

	for own_choice in own_choices:
		var value := _expected_value(state, own_choice, unit_id, opponent_choices, evaluate)
		if value > best_value:
			best_value = value
			best = own_choice
	return best


## El promedio de una sola jugada propia contra todas las respuestas del rival.
##
## Cada par se resuelve sobre **su propio clon**: `Round.resolve()` muta el
## `CombatState` que recibe, así que compartirlo entre pares mezclaría los resultados.
## También se clona cada `RoundChoice` (ver `RoundChoice.clone()`) porque `_charge()`
## anula la ranura que no se pudo pagar, y la misma instancia se reutiliza en cada
## vuelta del bucle.
static func _expected_value(
	state: CombatState,
	own_choice: RoundChoice,
	unit_id: int,
	opponent_choices: Array[RoundChoice],
	evaluate: Callable,
) -> float:
	var total := 0.0
	for opponent_choice in opponent_choices:
		var clone := state.clone()
		var choices: Array[RoundChoice] = [own_choice.clone(), opponent_choice.clone()]
		Round.resolve(clone, choices)
		total += evaluate.call(clone, unit_id)
	return total / opponent_choices.size()
