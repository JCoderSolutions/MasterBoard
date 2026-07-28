class_name DamageEffect
extends Effect

## Daño directo a la unidad de la casilla objetivo (GDD §6, familia Daño).
##
## No distingue amigo de enemigo: si apuntas a tu propia casilla, te pegas. Filtrar por
## bando es trabajo del targeting de la habilidad, no del efecto — así una habilidad de
## área puede reutilizar este mismo efecto sin excepciones.

@export var amount: int = 1


func apply(state: CombatState, _caster: Unit, target: Vector2i) -> Array[Event]:
	var events: Array[Event] = []
	var victim := state.unit_at(target)
	if victim == null:
		return events
	return Damage.apply(victim, amount)
