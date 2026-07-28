@abstract class_name Effect
extends Resource

## Una pieza de comportamiento componible (A-04). Es el ladrillo con el que se arman
## las habilidades sin escribir código.
##
## Extiende `Resource` y no `RefCounted` —al revés que `Unit` o `Event`— porque los
## efectos **son datos**: viven dentro de un `.tres`, se editan desde el inspector y se
## serializan. El coste de `Resource` (paths, serialización) es justo lo que aquí se
## quiere. Las unidades no lo quieren porque se clonan miles de veces al simular.
##
## **Regla del diseño:** pocos efectos y ortogonales. Cada uno debe hacer una cosa que
## los demás no hagan. En cuanto dos efectos se solapan, empiezan a aparecer habilidades
## que se comportan distinto según cuál usaste, y el balance deja de ser predecible.

## `target` es la **casilla** elegida, no la unidad: hay efectos que apuntan a suelo
## vacío (un dash, un muro) y hacer que la firma dependa de que haya alguien ahí los
## dejaría fuera. Quien necesite la víctima la pide con `state.unit_at(target)`.
@abstract func apply(state: CombatState, caster: Unit, target: Vector2i) -> Array[Event]
