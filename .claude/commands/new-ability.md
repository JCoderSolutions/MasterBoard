---
description: Crear una habilidad nueva completa (recurso .tres + test)
argument-hint: <nombre-habilidad> <coste-mana> <descripción del efecto>
---

Crea la habilidad "$ARGUMENTS" siguiendo las convenciones del proyecto (ver CLAUDE.md y ARCHITECTURE.md A-04):

1. Revisa `resources/abilities/` para ver si un `Effect` ya componible cubre esto antes de crear uno nuevo.
2. Crea el recurso `.tres` en `resources/abilities/` con coste de maná, targeting y efectos.
3. Si hace falta un `Effect` nuevo, créalo en la carpeta de efectos siguiendo el patrón existente.
4. Comprueba en qué fase de la resolución actúa (ARCHITECTURE.md A-12: barreras → movimiento → ataques → terreno). Una habilidad que no encaje limpiamente en una fase está mal planteada.
5. Si es una barrera, su duración va en el `.tres`, nunca como regla global (GDD §6).
6. Escribe el test correspondiente en `test/` que cubra el caso normal y al menos un caso límite.
7. Corre los tests y confírmame que pasan antes de terminar.

No me preguntes por confirmación de cada paso — ejecuta todo el flujo y muéstrame el resultado final.
