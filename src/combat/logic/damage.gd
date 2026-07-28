class_name Damage
extends RefCounted

## Único punto por el que pasa el daño (A-02). Funciones puras, sin estado.
##
## Existe porque "resta vida y comprueba si murió" aparece en cuatro sitios distintos
## —impacto de empuje, efecto de daño, peligros del terreno, derrumbe— y duplicarlo
## significa que el día que aparezcan los escudos (backlog 1.11) hay que acordarse de
## los cuatro. Aquí solo hay que acordarse de uno.
##
## No vive como estático en `Unit` porque `unit.gd` es dato puro y no debe construir
## eventos: la diferencia entre morir por daño y morir por caída es información para la
## vista, y por eso viaja en el `Event`, no en el estado.
##
## Ojo con el nombre: la familia de habilidad "Daño" de GDD §6 será `DamageEffect` en
## `logic/effects/` (backlog 1.8). Esto es la regla; aquello serán los datos que la usan.


## Aplica el daño y narra lo que pasó.
##
## El `amount` del evento es el daño **efectivamente aplicado**, no el que pedía la
## habilidad: si a una unidad con 2 de vida le pegas 7, el evento lleva 2. La vista no
## debería mostrar un "-7" sobre una barra que solo bajó 2.
##
## Un daño de 0 o negativo no emite nada. Un evento de "no pasó nada" obligaría a la
## cola de animación a filtrarlo, y es más limpio que no llegue.
static func apply(unit: Unit, amount: int) -> Array[Event]:
	var events: Array[Event] = []
	if unit == null or not unit.is_alive() or amount <= 0:
		return events

	# El escudo se come el golpe primero. Que este sea el único camino del daño es lo
	# que hace que la absorción funcione igual venga de un ataque, del impacto de un
	# empujón o de la lava, sin que ninguno de los tres sepa que existen los escudos.
	var absorbed := unit.absorb(amount)
	if absorbed > 0:
		events.append(ShieldAbsorbed.new(unit.id, absorbed, unit.shield))
		if not unit.has_shield():
			events.append(ShieldExpired.new(unit.id))

	var remaining := amount - absorbed
	if remaining <= 0:
		return events

	var applied := mini(remaining, unit.hp)
	unit.take_damage(applied)

	events.append(UnitDamaged.new(unit.id, applied, unit.hp))
	if not unit.is_alive():
		events.append(UnitDied.new(unit.id, UnitDied.Cause.DAMAGE))
	return events
