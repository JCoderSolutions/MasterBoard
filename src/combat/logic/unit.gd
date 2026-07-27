class_name Unit
extends RefCounted

## Una unidad en el tablero. Datos puros: no sabe dibujarse ni animarse (A-02).
##
## Extiende RefCounted y no Resource a propósito: las unidades se clonan miles de
## veces cuando la IA simula jugadas (A-02, punto 3), y Resource arrastra
## serialización y gestión de paths que ahí solo estorban.

enum Team { PLAYER, ENEMY }

var id: int = 0
var team: Team = Team.ENEMY
var position: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1


func _init(p_id: int = 0, p_team: Team = Team.ENEMY, p_position: Vector2i = Vector2i.ZERO, p_max_hp: int = 1) -> void:
	id = p_id
	team = p_team
	position = p_position
	max_hp = p_max_hp
	hp = p_max_hp


func is_alive() -> bool:
	return hp > 0


## No distingue entre morir por daño y morir por caída. Esa diferencia importa
## para la animación, y por eso vive en el Event que emite el resolver (backlog
## 1.2), no aquí: el estado solo registra que la unidad dejó de estar viva.
func kill() -> void:
	hp = 0


func take_damage(amount: int) -> void:
	hp = max(hp - amount, 0)


func clone() -> Unit:
	var copy := Unit.new(id, team, position, max_hp)
	copy.hp = hp
	return copy
