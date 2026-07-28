class_name Unit
extends RefCounted

## Una unidad en el tablero. Datos puros: no sabe dibujarse ni animarse (A-02).
##
## Extiende RefCounted y no Resource a propósito: las unidades se clonan miles de
## veces cuando la IA simula jugadas (A-02, punto 3), y Resource arrastra
## serialización y gestión de paths que ahí solo estorban.
##
## Vida y maná son **públicos para ambos bandos** (GDD §4). No es un descuido de
## encapsulación: ver el maná del rival es el motor de deducción del juego, porque
## saca habilidades de su espacio de posibilidades.

enum Team { PLAYER, ENEMY }

var id: int = 0
var team: Team = Team.ENEMY
var position: Vector2i = Vector2i.ZERO
var hp: int = 1
var max_hp: int = 1

## El tope es por unidad y no una constante global para que los personajes puedan
## diferenciarse por economía de maná, no solo por habilidades (A-14).
var mana: int = 0
var max_mana: int = 0


func _init(
	p_id: int = 0,
	p_team: Team = Team.ENEMY,
	p_position: Vector2i = Vector2i.ZERO,
	p_max_hp: int = 1,
	p_max_mana: int = 0,
	p_mana: int = 0,
) -> void:
	id = p_id
	team = p_team
	position = p_position
	max_hp = p_max_hp
	hp = p_max_hp
	max_mana = p_max_mana
	mana = mini(p_mana, p_max_mana)


func is_alive() -> bool:
	return hp > 0


## No distingue entre morir por daño y morir por caída. Esa diferencia importa
## para la animación, y por eso vive en el Event que emite el resolver (backlog
## 1.2), no aquí: el estado solo registra que la unidad dejó de estar viva.
func kill() -> void:
	hp = 0


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)


# ── Maná ────────────────────────────────────────────────────────

func can_afford(cost: int) -> bool:
	return mana >= cost


## Devuelve `false` y no gasta nada si no alcanza. Quien llame a esto sin mirar el
## resultado se queda con la habilidad aplicada y sin pagar.
func spend_mana(cost: int) -> bool:
	if not can_afford(cost):
		return false
	mana -= cost
	return true


func grant_mana(amount: int) -> void:
	mana = mini(mana + amount, max_mana)


## Quemar maná del rival es una habilidad de la familia `Mana` (GDD §6): no le quitas
## vida, le quitas opciones.
func burn_mana(amount: int) -> void:
	mana = maxi(mana - amount, 0)


func clone() -> Unit:
	var copy := Unit.new(id, team, position, max_hp, max_mana, mana)
	copy.hp = hp
	return copy
