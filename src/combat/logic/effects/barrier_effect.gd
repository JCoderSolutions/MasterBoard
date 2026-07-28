class_name BarrierEffect
extends Effect

## Levanta un muro temporal en la casilla objetivo (GDD §6, familia Barrera).
##
## La duración es campo de la carta, no regla global: las baratas se desvanecen al final
## de la ronda en que se pusieron —apuesta pura de predicción— y las caras aguantan hasta
## el final de la siguiente, que ya es negación de zona. Balancear eso no toca código.
##
## Va en fase `BARRIER`, antes de que nadie se mueva, y ese orden es lo único que hace
## que negar sea una apuesta real: pones el muro donde **crees** que va a ir. Si se
## resolviera después del movimiento no bloquearía nunca a nadie.

@export var duration: int = 1


func apply(state: CombatState, _caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []
	if not state.place_barrier(target, duration):
		return events

	events.append(BarrierPlaced.new(target, duration))
	return events
