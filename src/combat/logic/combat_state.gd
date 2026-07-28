class_name CombatState
extends RefCounted

## Snapshot completo de una partida: tablero, terreno, unidades, maná, ronda (A-02).
##
## GDScript puro. Cero nodos, cero await, cero acceso a escena. Si algún día
## necesitas importar algo de `scene` aquí, la separación está rota y el problema
## está mal planteado.
##
## **Convención de coordenadas:** `Vector2i(x, y)` donde `x` es la **columna** e
## `y` la **fila**. ARCHITECTURE.md A-10 habla de `(fila, columna)`, pero se usa el
## orden de Godot porque es el que espera `TileMap` cuando llegue la capa visual;
## invertirlo sería una fuente permanente de bugs de traducción.

const GRID_WIDTH: int = 5
const GRID_HEIGHT: int = 5

## Números de GDD §4, pendientes de playtest (D-05). Están aquí y no dispersos por
## las habilidades porque son la economía base: cambiarlos es un ajuste, no un parche.
const MANA_START: int = 3
const MANA_PER_ROUND: int = 2
const MANA_MAX: int = 8
const DEFAULT_MAX_HP: int = 10

var units: Array[Unit] = []

## Se llama `round_number` y no `round` porque `round()` es una función incorporada
## de GDScript y la sombra silenciaría llamadas legítimas. Mismo motivo que `rng_seed`.
var round_number: int = 1

## Toda la aleatoriedad del combate sale de aquí (A-03). Nada de `randi()`,
## `randf()` ni `shuffle()` globales: sin esto no hay reproducción de bugs por
## semilla ni PvP por comandos.
var rng: RandomNumberGenerator = null
var rng_seed: int = 0

## Terreno aplanado (A-13), indexado `y * GRID_WIDTH + x`. Se guarda como
## PackedInt32Array y no como Array[Terrain.Type] porque el clonado ocurre miles de
## veces cuando la IA simula, y duplicar un packed array es memcpy.
var _terrain: PackedInt32Array = PackedInt32Array()

var _next_unit_id: int = 1


func _init(p_seed: int = 0) -> void:
	rng_seed = p_seed
	rng = RandomNumberGenerator.new()
	rng.seed = p_seed

	_terrain.resize(GRID_WIDTH * GRID_HEIGHT)
	_terrain.fill(Terrain.Type.FLOOR)


# ── Tablero y terreno ───────────────────────────────────────────

func is_inside(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT


## Fuera del tablero devuelve `WALL`, y eso no es un valor de relleno: es la regla.
## El tablero es cerrado (GDD §4), así que el borde se comporta exactamente como un
## muro y ninguna consulta necesita un caso especial para "me salí". Las arenas que
## quieran bordes letales ponen `VOID` explícitamente en sus casillas.
func terrain_at(pos: Vector2i) -> Terrain.Type:
	if not is_inside(pos):
		return Terrain.Type.WALL
	return _terrain[pos.y * GRID_WIDTH + pos.x] as Terrain.Type


func set_terrain(pos: Vector2i, type: Terrain.Type) -> void:
	if not is_inside(pos):
		return
	_terrain[pos.y * GRID_WIDTH + pos.x] = type


## Se puede intentar entrar. `VOID` cuenta como transitable: moverse ahí es una
## jugada legal que termina en muerte, no un movimiento ilegal. Sin esa distinción
## un empuje no podría meter a nadie en el vacío.
func is_walkable(pos: Vector2i) -> bool:
	return Terrain.is_walkable(terrain_at(pos))


func is_lethal(pos: Vector2i) -> bool:
	return Terrain.is_lethal(terrain_at(pos))


## Bloqueada por `WALL`, y solo por `WALL`.
##
## Las unidades **no** bloquean. En un duelo hay dos unidades en el tablero: que se
## tapen mutuamente convertiría cada disparo en una consulta de oclusión sin añadir
## ninguna decisión interesante. `VOID` y `HAZARD` tampoco bloquean — se dispara por
## encima de un abismo.
##
## Exige que las casillas estén alineadas (`Grid.is_aligned`), porque solo existen
## líneas en las 8 direcciones. Las habilidades de área no preguntan por esto: eligen
## una casilla objetivo —esa sí con línea de visión— y afectan a su entorno.
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if not Grid.is_aligned(from, to):
		return false
	for pos in Grid.line_between(from, to):
		if terrain_at(pos) == Terrain.Type.WALL:
			return false
	return true


func unit_at(pos: Vector2i) -> Unit:
	for unit in units:
		if unit.is_alive() and unit.position == pos:
			return unit
	return null


func is_occupied(pos: Vector2i) -> bool:
	return unit_at(pos) != null


## Transitable y sin nadie encima. Ojo: una casilla `VOID` vacía **es libre** — te
## puedes mover ahí, y morirás. Quien quiera "libre y segura" tiene que preguntar
## además por `is_lethal()`.
func is_free(pos: Vector2i) -> bool:
	return is_walkable(pos) and not is_occupied(pos)


# ── Unidades ────────────────────────────────────────────────────

func add_unit(
	team: Unit.Team,
	pos: Vector2i,
	max_hp: int = DEFAULT_MAX_HP,
	max_mana: int = MANA_MAX,
) -> Unit:
	var unit := Unit.new(_next_unit_id, team, pos, max_hp, max_mana, MANA_START)
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


# ── Rondas ──────────────────────────────────────────────────────

## Avanza a la siguiente ronda y reparte maná.
##
## No se llama para entrar en la ronda 1: las unidades ya nacen con `MANA_START`.
## El maná **se acumula** en vez de rellenarse (GDD §4) porque eso crea la lectura
## "lleva tres rondas sin gastar, tiene algo grande listo". Si se rellenara al tope
## cada ronda, esa deducción no existiría.
func begin_round() -> void:
	round_number += 1
	for unit in units:
		if unit.is_alive():
			unit.grant_mana(MANA_PER_ROUND)


# ── Clonado ─────────────────────────────────────────────────────

## Copia profunda para que la IA pueda probar jugadas sin tocar el estado real
## (A-02, punto 3). Se copia también `rng.state` y no solo la semilla: dos clones
## de un mismo estado deben seguir produciendo la misma secuencia, y la semilla
## sola rebobinaría el generador al principio.
func clone() -> CombatState:
	var copy := CombatState.new(rng_seed)
	copy.rng.state = rng.state
	copy.round_number = round_number
	copy._terrain = _terrain.duplicate()
	copy._next_unit_id = _next_unit_id
	for unit in units:
		copy.units.append(unit.clone())
	return copy
