class_name CombatState
extends RefCounted

## Snapshot completo de un combate: grilla, unidades, mazo, energía, turno (A-02).
##
## GDScript puro. Cero nodos, cero await, cero señales de escena. Si algún día
## necesitas importar algo de `scene` aquí, la separación está rota y el problema
## está mal planteado.
##
## **Convención de coordenadas:** `Vector2i(x, y)` donde `x` es la **columna** e
## `y` la **fila**. ARCHITECTURE.md A-10 habla de `(fila, columna)`, pero se usa el
## orden de Godot porque es el que espera `TileMap` cuando llegue la capa visual
## (backlog 1.14); invertirlo sería una fuente permanente de bugs de traducción.

const GRID_WIDTH: int = 5
const GRID_HEIGHT: int = 5
const ENERGY_PER_TURN: int = 3

var units: Array[Unit] = []
var energy: int = ENERGY_PER_TURN
var turn: int = 1

## Mazo, mano y descarte forman parte del snapshot (A-02), pero su mecánica
## —robar, descartar, remezclar— es la tarea 1.7. Aquí solo existen como estado.
var deck: Array[String] = []
var hand: Array[String] = []
var discard: Array[String] = []

## Toda la aleatoriedad del combate sale de aquí (A-03). Nada de `randi()`,
## `randf()` ni `shuffle()` globales: sin esto no hay reproducción de bugs por
## semilla ni multijugador por comandos.
var rng: RandomNumberGenerator = null
var rng_seed: int = 0

var _next_unit_id: int = 1


func _init(p_seed: int = 0) -> void:
	rng_seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = p_seed


# ── Grilla ──────────────────────────────────────────────────────

func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT


func unit_at(pos: Vector2i) -> Unit:
	for unit in units:
		if unit.is_alive() and unit.position == pos:
			return unit
	return null


func is_occupied(pos: Vector2i) -> bool:
	return unit_at(pos) != null


## Una casilla es transitable si está dentro de la grilla y libre. Salir de la
## grilla no es "intransitable" sino letal (GDD, muerte por caída), así que esa
## regla la aplica el comando de movimiento, no esta consulta.
func is_free(pos: Vector2i) -> bool:
	return is_inside(pos) and not is_occupied(pos)


# ── Unidades ────────────────────────────────────────────────────

func add_unit(team: Unit.Team, pos: Vector2i, max_hp: int) -> Unit:
	var unit := Unit.new(_next_unit_id, team, pos, max_hp)
	_next_unit_id += 1
	units.append(unit)
	return unit


func unit_by_id(id: int) -> Unit:
	for unit in units:
		if unit.id == id:
			return unit
	return null


func living_units(team: Unit.Team) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if unit.is_alive() and unit.team == team:
			result.append(unit)
	return result


func hero() -> Unit:
	var players := living_units(Unit.Team.PLAYER)
	return players[0] if not players.is_empty() else null


# ── Clonado ─────────────────────────────────────────────────────

## Copia profunda para que la IA pueda probar jugadas sin tocar el estado real
## (A-02, punto 3). Se copia también `rng.state` y no solo la semilla: dos clones
## de un mismo estado deben seguir produciendo la misma secuencia, y la semilla
## sola rebobinaría el generador al principio.
func clone() -> CombatState:
	var copy := CombatState.new(rng_seed)
	copy.rng.state = rng.state
	copy.energy = energy
	copy.turn = turn
	copy.deck = deck.duplicate()
	copy.hand = hand.duplicate()
	copy.discard = discard.duplicate()
	copy._next_unit_id = _next_unit_id
	for unit in units:
		copy.units.append(unit.clone())
	return copy
