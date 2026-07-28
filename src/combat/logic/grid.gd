class_name Grid
extends RefCounted

## Geometría del tablero. Funciones puras: no conocen el estado ni el terreno (A-02).
##
## Todo lo que dependa de *este* tablero concreto —si hay un muro, si alguien ocupa
## una casilla— vive en `CombatState`. Aquí solo hay matemáticas de coordenadas, que
## es lo que permite testearlas sin montar una partida.
##
## Coordenadas `Vector2i(x = columna, y = fila)`, igual que en `CombatState`.

const ORTHOGONAL: Array[Vector2i] = [
	Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
]

const DIAGONAL: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1),
]

const ALL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i(1, -1), Vector2i.RIGHT, Vector2i(1, 1),
	Vector2i.DOWN, Vector2i(-1, 1), Vector2i.LEFT, Vector2i(-1, -1),
]


# ── Distancias ──────────────────────────────────────────────────

## Pasos ortogonales. Es la distancia que importa para moverse, porque el movimiento
## básico del GDD §4 es una casilla ortogonal.
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Pasos permitiendo diagonal. Es la distancia que importa para alcance de
## habilidades: "en un radio de 2" incluye las esquinas.
static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ── Adyacencia ──────────────────────────────────────────────────

static func is_orthogonally_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return manhattan_distance(a, b) == 1


## Incluye diagonales. Una unidad y ella misma no son adyacentes.
static func is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return a != b and chebyshev_distance(a, b) == 1


static func orthogonal_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in ORTHOGONAL:
		result.append(pos + dir)
	return result


static func all_neighbors(pos: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in ALL_DIRECTIONS:
		result.append(pos + dir)
	return result


# ── Líneas ──────────────────────────────────────────────────────

## Dos casillas están alineadas si comparten fila, columna o diagonal exacta.
##
## Deliberadamente **no** se usa Bresenham para trazar líneas arbitrarias: en un
## tablero de 5×5, "la línea entre (0,0) y (1,2)" no tiene una respuesta que el
## jugador pueda predecir mirando la pantalla, y una habilidad de línea que el
## jugador no puede prever es una habilidad rota. Solo hay líneas en las 8
## direcciones, que se leen de un vistazo.
static func is_aligned(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return false
	var delta := b - a
	return delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y)


## Paso unitario de `from` hacia `to`. `Vector2i.ZERO` si no están alineadas.
##
## Es lo que necesita el empuje: hacia dónde sale despedida la unidad golpeada.
static func direction(from: Vector2i, to: Vector2i) -> Vector2i:
	if not is_aligned(from, to):
		return Vector2i.ZERO
	return Vector2i(signi(to.x - from.x), signi(to.y - from.y))


## Casillas **estrictamente entre** `from` y `to`, en orden desde `from`.
##
## Excluye ambos extremos a propósito: quien pregunta por una línea casi siempre
## quiere saber qué hay en medio (línea de visión, trayectoria de un empuje), no
## repetir el origen y el destino que ya tiene.
##
## Devuelve vacío si no están alineadas o si son adyacentes: entre dos casillas
## pegadas no hay nada.
static func line_between(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var step := direction(from, to)
	if step == Vector2i.ZERO:
		return result

	var current := from + step
	while current != to:
		result.append(current)
		current += step
	return result


## Casillas desde `from` en una dirección, sin incluir el origen. `length` es cuántas.
##
## Sirve para patrones de habilidad ("golpea 3 casillas hacia delante") sin tener que
## calcular antes dónde termina la línea.
static func ray(from: Vector2i, dir: Vector2i, length: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if dir == Vector2i.ZERO or length <= 0:
		return result

	var current := from
	for i in length:
		current += dir
		result.append(current)
	return result
