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

## Escudo: absorbe daño y caduca (GDD §6). Público, como todo lo demás.
##
## Es la defensa que el MVP sí permite, frente a la curación que no: absorbe una
## cantidad fija y se acaba, así que no puede convertir la partida en un desgaste sin
## resolución. Dos jugadores que se escudan siguen avanzando hacia el final.
var shield: int = 0
var shield_rounds: int = 0


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


# ── Escudo ──────────────────────────────────────────────────────

func has_shield() -> bool:
	return shield > 0


## Un escudo nuevo **sustituye** al anterior, no se acumula.
##
## Una sola regla, legible de un vistazo en el HUD. Apilar convertiría escudarse en una
## estrategia de acumulación —justo el desgaste sin resolución que el GDD quiere evitar—
## y "se queda el mejor de los dos" obligaría a explicar dos números en pantalla.
## Rebajarte el escudo por error no es una trampa: el tuyo y el suyo están a la vista.
func grant_shield(amount: int, duration: int) -> void:
	if amount <= 0 or duration <= 0:
		return
	shield = amount
	shield_rounds = duration


## Consume escudo y devuelve cuánto absorbió. Al agotarse caduca, aunque le quedaran
## rondas: un escudo a cero no es un escudo.
func absorb(amount: int) -> int:
	var absorbed := mini(shield, maxi(amount, 0))
	shield -= absorbed
	if shield <= 0:
		shield_rounds = 0
	return absorbed


## Descuenta una ronda. Devuelve `true` si caducó justo ahora.
func tick_shield() -> bool:
	if shield_rounds <= 0:
		return false
	shield_rounds -= 1
	if shield_rounds > 0:
		return false
	shield = 0
	return true


func clone() -> Unit:
	var copy := Unit.new(id, team, position, max_hp, max_mana, mana)
	copy.hp = hp
	copy.shield = shield
	copy.shield_rounds = shield_rounds
	return copy
