# Plantilla del Pack de Rendimiento

Archivos listos para copiar sobre un repositorio. Cada uno es funcional tal cual:
la única configuración obligatoria es `PERF_TARGET` y, para objetivos
autenticados, `PERF_APP_MARKER`.

```text
bin/perf-init.sh             Instalador: archivos, variables y regla de rama
bin/perf-resolve-target      Encuentra la vista previa de un commit, o nada
tests/load/lib/target.js     Resuelve objetivo y credenciales por tipo de plataforma
tests/load/lib/guard.js      Aborta si respondió algo que no es la aplicación
tests/load/lib/metrics.js    Umbrales y el detector de scripts rotos
tests/load/lib/summary.js    Evidencia en Markdown desde el resumen de k6
tests/load/smoke.js          Perfil determinista y bloqueante
tests/load/load.js           Perfil de carga, a demanda
bin/perf-check               Verificador fail-closed
.github/workflows/perf.yml   Compuerta en CI: smoke bloqueante, carga manual
.env.perf.example            Configuración documentada
```

## Orden de lectura

1. `.env.perf.example` — qué hay que configurar y por qué.
2. `bin/perf-check` — qué significa "aprobado". Es la definición ejecutable.
3. `tests/load/lib/guard.js` — la verificación que evita medir una pantalla de
   autenticación.
4. `tests/load/lib/metrics.js` — por qué existe el contador `perf_completed`.

## Instalación

Usa el instalador en lugar de copiar a mano; deja el `.gitignore`, las variables
del repositorio y la regla de rama configurados de una vez:

```sh
bash bin/perf-init.sh --dry-run --account <tu-cuenta> --marker '<texto de tu app>'
bash bin/perf-init.sh --account <tu-cuenta> --marker '<texto de tu app>'
```

Si prefieres copiar a mano, añade a tu `.gitignore`:

```gitignore
.env.perf
tests/load/results/
```

`tests/load/baseline.json` **sí** se versiona: es la referencia aprobada, y su
historial de cambios es el registro de las degradaciones que el equipo aceptó.

## Verificación mínima tras copiar

```sh
# Contra la aplicación corriendo en local
PERF_TARGET=http://127.0.0.1:3000 bin/perf-check smoke

# Confirma que la compuerta SÍ falla cuando debe
PERF_TARGET=http://127.0.0.1:3000 PERF_P95_MS=1 bin/perf-check smoke   # espera fallo
```

Si el segundo comando aprueba, la compuerta no está funcionando y no sirve de
nada haberla instalado.
