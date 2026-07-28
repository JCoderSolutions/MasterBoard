class_name Terrain
extends RefCounted

## Tipos de casilla (A-13). El terreno es **dato de la arena**, no regla del juego.
##
## Existe como clase y no como enum suelto dentro de `CombatState` porque las arenas
## son `.tres` (A-04) y necesitan poder referirse a estos valores desde datos.
##
## Sustituye a la regla global "salir de la grilla mata" del GDD v0.1. Que los bordes
## maten pasa a ser propiedad de cada arena: unas son tableros cerrados, otras tienen
## vacío en dos lados, otras lava en el centro. Un solo sistema cubre las tres.

enum Type {
	FLOOR,   ## Normal
	WALL,    ## Intransitable. Bloquea movimiento, empuje y línea de visión
	VOID,    ## Entrar mata. Solo en arenas que lo declaren
	HAZARD,  ## Daña al terminar la fase de movimiento sobre ella
}

## Daño de una casilla peligrosa. Sale de aquí y no de la arena porque en el MVP
## todos los peligros pegan igual; cuando dejen de hacerlo, pasa a ser campo del .tres.
const HAZARD_DAMAGE: int = 2


## Se puede intentar entrar. Ojo: `VOID` es transitable **y** letal — moverse ahí es
## una jugada válida que termina en muerte, no un movimiento ilegal. La diferencia
## importa porque un empuje sí puede meterte en el vacío.
static func is_walkable(type: Type) -> bool:
	return type != Type.WALL


static func is_lethal(type: Type) -> bool:
	return type == Type.VOID
