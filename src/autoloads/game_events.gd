extends Node

## Bus único entre la capa lógica y la de presentación (ARCHITECTURE.md A-05).
##
## Regla que mantiene esto limpio: solo eventos del dominio de combate y del
## meta-juego. Nada de UI — `button_pressed` y similares no entran aquí.
##
## Está deliberadamente vacío. La forma final del flujo de eventos depende de la
## clase `Event` que devuelve el resolver (backlog 1.2) y de si la capa visual
## consume un stream ordenado o señales sueltas (backlog 1.17, cola de animación).
## Inventar la API ahora sería adivinar, y las señales del diseño anterior ya
## mostraron lo caro que sale equivocarse aquí.
