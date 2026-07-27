# MasterBoard

Deckbuilder táctico por turnos, móvil (Android), Godot 4.7.1, GDScript.
Dev solo. Diseño en `docs/GDD.md`, decisiones técnicas en `docs/ARCHITECTURE.md`.

## Reglas que no se rompen

1. **`src/combat/logic/` es GDScript puro.** Cero `Node`, cero `await`, cero acceso a escena.
   Si necesitas un nodo ahí, la solución está mal planteada.
2. **Determinismo.** Nada de `randi()`, `randf()` ni `shuffle()` global. Toda aleatoriedad sale
   del `RandomNumberGenerator` con semilla que vive en `CombatState`.
3. **Cartas y enemigos son datos** (`.tres` en `resources/`), no código. Añadir contenido no
   debe tocar la lógica.
4. **La capa visual nunca decide reglas.** Solo escucha `GameEvents` y anima.
5. **Tipado estático siempre**: `var hp: int = 10`, `func apply(state: CombatState) -> Array[Event]:`.

## Comandos

```bash
godot --path . --editor              # abrir editor
godot --path . --headless --quit     # verificar que el proyecto carga
godot --path . --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/   # tests
```

**El binario no está en el PATH todavía.** Ruta en esta PC (ojo: al descomprimir se creó
una carpeta que se llama igual que el `.exe`, de ahí el nombre repetido):

```
C:\Users\Jose\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe
```

En Windows hay que usar la variante **`_console.exe`**: el ejecutable normal se desprende de
la consola y no verías la salida de los tests ni de `--headless`. Conviene ponerlo en el PATH
como `godot` para que los comandos de arriba funcionen tal cual en ambas PCs.

## Convenciones

- Archivos y carpetas: `snake_case.gd`. Clases: `PascalCase`. Señales: pasado (`unit_died`).
- Un archivo por clase. `class_name` en todo lo que se instancie desde fuera.
- Comentarios solo para el "por qué", nunca para el "qué".
- Commits: `feat:`, `fix:`, `refactor:`, `test:`, `chore:` + ámbito. Ej: `feat(combat): empuje mata al caer`.

## Al trabajar en este proyecto

- **Antes de implementar una mecánica nueva**, revisa si ya existe un efecto componible en
  `resources/` que la cubra. Preferir composición sobre carta con lógica especial.
- **Todo cambio en `src/combat/logic/` necesita test** en `test/` antes de darse por hecho.
- **Preferir `git`/CLI sobre MCP** para operaciones de repositorio.
- **Sin MCP conectado hasta Fase 1C.** Fase 0/1A/1B es lógica pura y tests por terminal — no
  necesita editor. El MCP de Godot se agrega recién cuando empieza el trabajo visual/de escena.
- **No usar el MCP de Godot para leer código** — usa lectura de archivos directa. El MCP es para
  inspeccionar la escena viva, el debugger y el árbol de nodos.
- Si una tarea produce salida verbosa (correr tests, explorar muchos archivos, buscar docs),
  delegar a un subagente para no contaminar el contexto principal.

## No tocar

- `addons/` — plugins de terceros, se actualizan por su cuenta.
- `project.godot` — pídeme confirmación antes de modificar autoloads, layers o input map.

## Compact

Al compactar, prioriza: cambios de código de esta sesión, decisiones de diseño tomadas, y
tests que fallan. Descarta exploración de archivos y salidas de comandos ya resueltas.
