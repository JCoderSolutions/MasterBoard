class_name BoardEvaluation
extends RefCounted

## Cuánto de bueno es un `CombatState` para una unidad (backlog 1.17, insumo de
## `ExpectedValueSearch`). Positivo es bueno para `unit_id`, negativo es malo.
##
## **Esto es un placeholder deliberado**, igual que lo fue el cuerpo de `Ai.decide()`
## en 1.15. Ganar, perder y empatar ya se evalúan bien —se apoyan en `MatchResult`,
## que ya es la autoridad sobre eso (1.13)—, pero en una ronda no decisiva la única
## señal que se usa es la diferencia de vida. La función completa que pide 1.18 — maná,
## proximidad a peligro, casillas seguras disponibles — se añade **dentro de la rama
## "sigue la partida"** de aquí, sin tocar el resto ni la firma.


static func score(state: CombatState, unit_id: int) -> float:
	var unit := state.unit_by_id(unit_id)
	if unit == null:
		return -1000.0

	match MatchResult.evaluate(state):
		MatchResult.Type.DRAW:
			return 0.0
		MatchResult.Type.PLAYER_WINS:
			return 1000.0 if unit.team == Unit.Team.PLAYER else -1000.0
		MatchResult.Type.ENEMY_WINS:
			return 1000.0 if unit.team == Unit.Team.ENEMY else -1000.0
		_:
			pass  # ONGOING: la partida sigue, hace falta una señal más fina.

	var opponents := state.living_units(Unit.opposing_team(unit.team))
	var opponent_hp := 0
	for opponent in opponents:
		opponent_hp += opponent.hp
	return float(unit.hp - opponent_hp)
