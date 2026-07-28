class_name PhaseStarted
extends Event

## Empezó una fase de la ronda.
##
## Es el único evento que no narra un cambio de estado: marca dónde se corta el flujo.
## La cola de animación lo necesita para reproducir la resolución **por tramos** en vez
## de todo seguido (R-08), y el indicador de fase de la UI (backlog 1.27) para saber qué
## resaltar. Sin él, la vista recibiría una lista plana de eventos y el jugador no podría
## reconstruir por qué pasó lo que pasó.
##
## Se emite **siempre**, aunque la fase no produzca nada: una fase vacía también se ve
## —el indicador pasa por ella— y hacerla condicional obligaría a la vista a adivinar.

var phase: Phase.Type


func _init(p_phase: Phase.Type) -> void:
	super(Type.PHASE_STARTED)
	phase = p_phase


func _to_string() -> String:
	return "PhaseStarted(%s)" % Phase.Type.keys()[phase]
