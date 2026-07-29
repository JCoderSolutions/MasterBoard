class_name BoardView
extends TileMapLayer

## Dibuja el terreno del tablero (backlog 1.20). Solo escucha y pinta, nunca decide
## reglas (A-02): lo único que hace es leer `CombatState.terrain_at()` y reflejarlo.
##
## El orden de los tiles del atlas coincide con `Terrain.Type` (FLOOR=0, WALL=1,
## VOID=2, HAZARD=3) a propósito: convertir un tipo de terreno en coordenadas de
## atlas es directo, sin una tabla de traducción aparte que se pueda desincronizar
## del enum si algún día se añade un quinto tipo de terreno.
##
## El atlas de `board_tileset.tres` es arte de relleno —cuatro cuadrados de color—
## mientras 0.8 siga bloqueada. El día que el pack real llegue, se sustituye la
## textura del `TileSet`; ni este script ni el orden de los tiles cambian.

const TERRAIN_ATLAS_ROW: int = 0


func _init() -> void:
	tile_set = load("res://src/combat/view/board_tileset.tres")


## Redibuja el tablero entero a partir del estado actual. Se llama al montar la
## partida y cada vez que el terreno cambia (una barrera se coloca o caduca, el
## derrumbe del tablero avanza) — la vista no lo sabe por sí sola, alguien tiene que
## avisarle a través de `GameEvents` (1.22).
func sync_from_state(state: CombatState) -> void:
	var source_id := tile_set.get_source_id(0)
	for y in CombatState.GRID_HEIGHT:
		for x in CombatState.GRID_WIDTH:
			var pos := Vector2i(x, y)
			var terrain_type := state.terrain_at(pos)
			set_cell(pos, source_id, Vector2i(terrain_type, TERRAIN_ATLAS_ROW))
