class_name Phase
extends RefCounted

## Las fases de resolución de una ronda (A-12, GDD §5). El orden **es** el juego.
##
## Vive en su propia clase y no dentro de `Round` para que `Ability` pueda declarar en
## qué fase actúa sin que las dos clases se referencien en círculo. Mismo patrón que
## `Terrain`.
##
## Cada corte gana algo concreto:
##
## - **Barreras primero** hace que negar sea una apuesta real: pones el muro donde crees
##   que va a ir. Después del movimiento no bloquearían nunca.
## - **Ataques después del movimiento** es lo que convierte moverse en esquivar, y es la
##   principal expresión de habilidad del juego.
## - **Terreno al final** permite que empujar a alguien a la lava funcione en la misma
##   ronda, y que el daño se cobre una sola vez llegases como llegases.

enum Type {
	BARRIER,   ## Muros y bloqueos, antes de que nadie se mueva
	MOVEMENT,  ## Ambos bandos a la vez
	ATTACK,    ## Desde las posiciones ya actualizadas
	TERRAIN,   ## Peligros de la casilla donde acabaste. No lo elige nadie
}

## Orden de resolución. Es la lista que recorre `Round`, y estar escrita una sola vez
## evita que el orden real y el que se documenta se separen.
const ORDER: Array[Type] = [Type.BARRIER, Type.MOVEMENT, Type.ATTACK, Type.TERRAIN]


## `TERRAIN` no se puede elegir: no es una carta, es lo que hace el tablero cuando ya
## se movió todo el mundo.
static func is_selectable(type: Type) -> bool:
	return type != Type.TERRAIN
