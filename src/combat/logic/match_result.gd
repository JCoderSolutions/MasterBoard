class_name MatchResult
extends RefCounted

## Si la partida terminó, y cómo (GDD §4, R-06). Consulta pura, no cambia nada.
##
## No vive dentro de `Round` a propósito. `Round.resolve()` ya documenta por qué: entre
## resolver una ronda y repartir el maná de la siguiente (`CombatState.begin_round()`)
## hace falta un hueco donde comprobar si alguien murió, y ese hueco es quien orquesta
## las rondas —el bucle de partida de una fase posterior—, no el resolver en sí. Aquí
## solo vive la pregunta "¿ya se acabó?", igual que `Grid` o `Terrain` solo responden
## preguntas sobre geometría y suelo.

enum Type {
	ONGOING,      ## Los dos bandos tienen alguien vivo. Se juega otra ronda
	PLAYER_WINS,
	ENEMY_WINS,
	DRAW,         ## Los dos llegaron a 0 la misma ronda (GDD §4)
}


static func evaluate(state: CombatState) -> Type:
	var player_alive := not state.living_units(Unit.Team.PLAYER).is_empty()
	var enemy_alive := not state.living_units(Unit.Team.ENEMY).is_empty()

	if player_alive and enemy_alive:
		return Type.ONGOING
	if not player_alive and not enemy_alive:
		return Type.DRAW
	return Type.PLAYER_WINS if player_alive else Type.ENEMY_WINS


static func is_over(state: CombatState) -> bool:
	return evaluate(state) != Type.ONGOING
