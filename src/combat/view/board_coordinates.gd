class_name BoardCoordinates
extends RefCounted

## Conversión entre la grilla lógica de CombatState y píxeles de pantalla (backlog
## 1.20). Funciones puras, sin nodo: no hace falta una escena montada para probarlas,
## igual que `Grid` no necesita un `CombatState` para calcular una distancia.
##
## `CombatState` usa `Vector2i(x = columna, y = fila)` a propósito desde 1.1 —"es el
## orden que espera `TileMap` cuando llegue la capa visual"— así que aquí no hay
## ninguna inversión de ejes que hacer. El día que eso cambiara, este es el único
## archivo que tendría que enterarse.
##
## `CELL_SIZE` tiene que coincidir con el `tile_size` de `board_tileset.tres`: son el
## mismo número contado dos veces porque un recurso no puede leer una constante de
## GDScript. Si algún día se desincronizan, las unidades no calzan sobre su casilla.

const CELL_SIZE: int = 40


## Esquina superior izquierda de la casilla, en píxeles locales del `TileMapLayer`.
## Es lo que usa `TileMapLayer` internamente (`map_to_local` sin el medio tile).
static func to_pixel(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)


## Centro de la casilla. Lo quiere quien coloca un sprite: un pivote centrado en la
## esquina se vería descuadrado medio tile hacia abajo y a la derecha.
static func to_pixel_center(grid_pos: Vector2i) -> Vector2:
	return to_pixel(grid_pos) + Vector2(CELL_SIZE, CELL_SIZE) / 2.0


## El sentido contrario: a qué casilla cae un punto de la pantalla. Es lo que
## necesita el input táctil (backlog 1.28) para saber qué casilla se tocó.
##
## `floori` y no `roundi`: una casilla ocupa desde su esquina hasta (esquina + tamaño)
## sin incluir el siguiente borde, y truncar hacia abajo es exactamente esa regla,
## incluidas las coordenadas negativas (fuera del tablero por la izquierda/arriba).
static func to_grid(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(floori(pixel_pos.x / CELL_SIZE), floori(pixel_pos.y / CELL_SIZE))
