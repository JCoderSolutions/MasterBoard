---
description: Crear una carta nueva completa (recurso .tres + test)
argument-hint: <nombre-carta> <coste> <descripción del efecto>
---

Crea la carta "$ARGUMENTS" siguiendo las convenciones del proyecto (ver CLAUDE.md y ARCHITECTURE.md A-04):

1. Revisa `resources/cards/` para ver si un efecto ya componible cubre esto antes de crear uno nuevo.
2. Crea el recurso `.tres` en `resources/cards/` con coste, targeting y efectos.
3. Si hace falta un `Effect` nuevo, créalo en la carpeta de efectos siguiendo el patrón existente.
4. Escribe el test correspondiente en `test/` que cubra el caso normal y al menos un caso límite.
5. Corre los tests y confírmame que pasan antes de terminar.

No me preguntes por confirmación de cada paso — ejecuta todo el flujo y muéstrame el resultado final.
