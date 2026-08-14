# Pack de Especificación Ejecutable (Gherkin)

Este pack convierte los criterios de aceptación en escenarios que se ejecutan, y
añade una compuerta que distingue entre *"los tests pasaron"* y *"los tests
probaron algo"*.

Úsalo cuando necesites que una funcionalidad no pueda declararse terminada sin
que su comportamiento observable haya sido ejecutado y comparado contra un valor
esperado.

## El problema que resuelve

El código de salida de Cucumber responde **"¿falló algo?"**. No responde
**"¿corrió algo?"**, y esas son preguntas distintas:

| Situación | Qué ejecuta Cucumber | Qué reporta |
|---|---|---|
| Se renombró o movió `features/` | Nada | **Éxito, código de salida 0** |
| Un filtro por tag no coincide con ningún escenario | Nada | **Éxito, código de salida 0** |
| Los steps nunca se conectaron | Nada | **Éxito, código de salida 0** |
| Un escenario quedó en `pending` o `skipped` | Se salta | Éxito |

Es el mismo modo de falla que ya conocías de k6: *un script roto sale con éxito*.
Un agente que escribe pruebas y las ve en verde no tiene forma de notar la
diferencia, y la funcionalidad se declara aprobada sin que nada se haya
comprobado.

## Hallazgos medidos (Cucumber 13.2.1, Node 26.3.1, agosto 2026)

Verificados ejecutando el runner, no leyendo su documentación:

```
$ mv features features-old && cucumber-js
0 scenarios
0 steps
exit = 0          <-- verde, sin haber ejecutado nada

$ bin/gherkin-check --expect 1
GHERKIN_ZERO_EXECUTION: the run exited without executing a single scenario
exit = 2          <-- bloqueado
```

## Cómo funciona

La compuerta **no confía en el código de salida**: lee el reporte `messages`
(NDJSON, el formato canónico de Cucumber) y emite su propio veredicto.

- `bin/gherkin-check` — ejecuta Cucumber y delega el veredicto al validador.
- `bin/gherkin-validate.mjs` — el corazón. Recibe el reporte y decide.

`--expect N` es el **contador absoluto**: declaras cuántos escenarios deben
ejecutarse, y una corrida que silenciosamente ejecute menos deja de ser un
aprobado. Sin él, perder la mitad de los escenarios sigue viéndose verde.

### Códigos de salida

| Código | Significado |
|---|---|
| `0` | La corrida es confiable |
| `1` | Un escenario o step no pasó (`FAILED`, `UNDEFINED`, `AMBIGUOUS`, `PENDING`, `SKIPPED`, id duplicado) |
| `2` | La corrida no probó nada (`ZERO_EXECUTION`, `COUNT_MISMATCH`) |
| `3` | El reporte es inservible (ausente, malformado o truncado) |

`pending` y `skipped` **no son aprobados**: son steps que nunca comprobaron nada.

## Instalación

Copia `repo-template/` en el repositorio y conéctalo como una capa más de la
funcionalidad en `feature_list.json`:

```json
"layers": [
  { "label": "unit",    "cmd": "npm test",                    "repair": "..." },
  { "label": "gherkin", "cmd": "bin/gherkin-check --expect 4",
    "repair": "Si dice ZERO_EXECUTION, el runner no encontró los escenarios: revisa la ruta de features/ y la configuración de import antes de tocar los steps." }
]
```

Requiere `@cucumber/cucumber` como dependencia de desarrollo y `node` en el PATH.
Es la única parte del pack con dependencias externas; el validador usa solo
módulos internos de Node.

## Verificar el pack

```bash
bash packs/gherkin/verify-pack.sh
```

Provoca cada modo de falla y exige que **todos bloqueen** (15 casos). La compuerta
solo vale mientras ese script esté en verde. Los reportes se sintetizan en vez de
generarse ejecutando Cucumber, así que el pack se verifica en cualquier máquina
con Node, sin `npm install` ni red.

## Trampas conocidas

- **El validador es `.mjs`, no `.js`.** En un repositorio con `"type": "module"`
  un archivo `.js` se interpreta como ESM y `require()` revienta. La extensión
  fija el sistema de módulos sin importar cómo esté configurado el repositorio
  anfitrión. Esto se descubrió ejecutándolo de verdad: la matriz sintética pasaba
  en verde mientras el camino real fallaba.
- **`--expect` hay que actualizarlo** al agregar escenarios, y esa fricción es
  deliberada: es lo que impide que el conteo se degrade en silencio.
- Un step que no compara nada pasa siempre. La compuerta exige que cada escenario
  **ejecute y termine en `PASSED`**, pero no puede saber si tu `Then` compara algo
  real — eso sigue siendo responsabilidad de quien escribe el escenario.
