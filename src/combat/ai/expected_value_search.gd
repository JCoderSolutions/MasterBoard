class_name ExpectedValueSearch
extends RefCounted

## Elige la jugada que maximiza el valor esperado, promediando sobre todas las
## respuestas legales del rival (backlog 1.17), mirando `depth` rondas hacia delante
## (backlog 1.19).
##
## No es hacer trampa mirar las jugadas *posibles* del rival — A-15 lo permite
## explícitamente ("la IA sí puede clonar el estado y simular las acciones posibles del
## jugador, eso es leer, no hacer trampa"). Lo que nunca llega aquí es la que *de
## verdad* eligió esta ronda: `ActionSpace` solo conoce reglas públicas (maná, kit,
## targeting), nunca una elección oculta.
##
## Es **promedio, no minimax**: para cada jugada propia, la nota es la media de cómo
## le fue contra cada respuesta posible del rival, no la peor de todas. Un rival que
## también decide a ciegas no puede jugar "y si hace lo peor para mí en concreto",
## porque tampoco sabe qué elegiste tú — la simetría que A-12 protege. Minimax
## asumiría un rival que ya conoce tu jugada, la ventaja injusta que A-15 prohíbe. Y
## esa misma regla se aplica en **cada** ronda de la profundidad, no solo en la
## primera: el rival sigue decidiendo a ciegas dos, tres rondas por delante, tanto
## como en la que se está jugando ahora.
##
## Necesita los kits (no listas de jugadas ya calculadas) porque a partir de la
## profundidad 2 las jugadas de la ronda siguiente no existen todavía — dependen de un
## estado que solo aparece después de resolver la ronda anterior. `Ai.decide()` sigue
## sin verse afectado: la firma que congeló 1.15 no cambia.


## Punto de entrada: la mejor jugada de `unit_id` en `state`, mirando `depth` rondas.
## `depth <= 1` (el valor de siempre desde 1.17) es exactamente el comportamiento
## anterior a 1.19; nadie que no toque `Unit.search_depth` nota el cambio.
static func best_choice(
	state: CombatState,
	unit_id: int,
	kit: Array[Ability],
	opponent_id: int,
	opponent_kit: Array[Ability],
	evaluate: Callable,
	depth: int = 1,
) -> RoundChoice:
	var unit := state.unit_by_id(unit_id)
	var own_choices := ActionSpace.legal_choices(state, unit, kit)

	var best: RoundChoice = own_choices[0]
	var best_value := -INF

	for own_choice in own_choices:
		var value := _expected_value(
			state, own_choice, unit_id, kit, opponent_id, opponent_kit, evaluate, depth
		)
		if value > best_value:
			best_value = value
			best = own_choice
	return best


## El promedio de una sola jugada propia contra todas las respuestas del rival **en
## esta ronda**. Si `depth` da para más, cada resultado no se evalúa directamente:
## se sigue mirando desde ahí con `_best_value`, que es este mismo cálculo pero para
## "cuál es el mejor valor alcanzable", sin necesitar saber qué jugada lo logra.
static func _expected_value(
	state: CombatState,
	own_choice: RoundChoice,
	unit_id: int,
	kit: Array[Ability],
	opponent_id: int,
	opponent_kit: Array[Ability],
	evaluate: Callable,
	depth: int,
) -> float:
	var opponent := state.unit_by_id(opponent_id)
	var opponent_choices := ActionSpace.legal_choices(state, opponent, opponent_kit)

	var total := 0.0
	for opponent_choice in opponent_choices:
		# Cada par se resuelve sobre **su propio clon**: `Round.resolve()` muta el
		# `CombatState` que recibe, así que compartirlo entre pares mezclaría los
		# resultados. También se clona cada `RoundChoice` (`RoundChoice.clone()`)
		# porque `_charge()` anula la ranura que no se pudo pagar, y la misma
		# instancia se reutiliza en cada vuelta de este bucle.
		var clone := state.clone()
		var choices: Array[RoundChoice] = [own_choice.clone(), opponent_choice.clone()]
		Round.resolve(clone, choices)

		if depth <= 1 or MatchResult.is_over(clone):
			total += evaluate.call(clone, unit_id)
		else:
			# Sigue mirando: la ronda ya se resolvió, así que toca lo que le tocaría
			# a cualquier ronda nueva antes de que nadie elija nada — repartir maná.
			# Sin esto, mirar más profundo penalizaría sistemáticamente ahorrar
			# maná esta ronda para algo grande la próxima, que es justo la lectura
			# que el GDD quiere premiar.
			clone.begin_round()
			total += _best_value(clone, unit_id, kit, opponent_id, opponent_kit, evaluate, depth - 1)
	return total / opponent_choices.size()


## El mejor valor alcanzable desde `state` mirando `depth` rondas — la misma cuenta
## que `best_choice`, pero solo el número, para usar dentro de la recursión sin tener
## que reconstruir qué jugada lo consigue.
static func _best_value(
	state: CombatState,
	unit_id: int,
	kit: Array[Ability],
	opponent_id: int,
	opponent_kit: Array[Ability],
	evaluate: Callable,
	depth: int,
) -> float:
	var unit := state.unit_by_id(unit_id)
	var own_choices := ActionSpace.legal_choices(state, unit, kit)

	var best_value := -INF
	for own_choice in own_choices:
		var value := _expected_value(
			state, own_choice, unit_id, kit, opponent_id, opponent_kit, evaluate, depth
		)
		if value > best_value:
			best_value = value
	return best_value
