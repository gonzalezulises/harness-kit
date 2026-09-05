# Evidencia y reproducción

Base auditada: `88ea1e6c45faf5b5db9e29935eef6e25e50f633b`.
Los scripts ejecutados son los originales del repositorio. Las fixtures están
fuera del checkout; las pruebas no despliegan ni acceden a servicios externos.

| Archivo | Qué acredita | Límite |
|---|---|---|
| `baseline-init.log` | 273 aserciones del núcleo | No es la suite completa |
| `baseline-check.log` | `make check`: 411 aserciones, 2 casos omitidos | Los 2 requieren `gh` autenticado; no se cuentan como PASS |
| `baseline-gates.log` | 8 PASS del registro quick | Algunos gates no tienen artefactos aplicables |
| `final-check.log`, `final-gates.log` | Reejecución previa al commit: mismos 411 PASS/2 omitidos y 8 gates PASS | No transforma los probes RED en fixes |
| `independent-review.md` | Dictamen del actor independiente, líneas/hashes y contraejemplos | No es un reviewer Codex CLI del futuro adapter |
| `document-review-final.md`, `document-corrections-verified.json` | Revisión independiente de propuestas y 16 contrastes antes/después | Sin High/Critical documentales pendientes en su alcance; los defectos del runtime siguen abiertos |
| `document-review-snapshot/` | Bytes de los documentos anteriores a las correcciones | Archivo histórico parcial: conserva rutas relativas originales y no es el diseño vigente |
| `policy-validation-independent.json` | Reejecución independiente de los 42 checks sobre la propuesta corregida | Validación estructural, sin activación |
| `independent-red-baseline/` | 8 métodos, 11 aserciones fallidas, cero errores del runner | Son RED de expectativas nuevas, no pruebas aprobadas |
| `supplemental-state-baseline/` | R13: 3 métodos y 3 fallos de aserción, cero errores | Prueba activation, WIP y unicidad de IDs por separado |
| `local-probes.json`, `local-red.log` | R08/R09: éxito indebido; R11: 7 PASS y un required gate ausente | Pruebas locales; R10 sigue siendo lectura de workflow |
| `policy-validation.json` | 42 comprobaciones estructurales, cero fallos | No demuestra autorización ni ejecución del runtime |
| `policy-validation-initial.json` | 32 comprobaciones de la primera propuesta | Histórico anterior a la revisión independiente; hashes distintos de la propuesta final |
| `github-ruleset.json` | Snapshot del ruleset visible durante la auditoría | No certifica integridad del workflow ni permisos no observados |
| `provenance.json` | Fuente, herramientas, original y límites | El entorno no incluye Codex CLI ni gh autenticado |
| `manifest.sha256` | Integridad de los artefactos de revisión enumerados | Un hash local no es un testigo externo contra un actor malicioso |

El informe independiente conserva sus rutas originales (`red-baseline/`); aquí
se archiva ese resultado bajo `independent-red-baseline/`. Se incluyen entradas,
salidas, estados y hashes en JSON, pero no copias de los directorios `.git` de
fixtures. Los comandos siguientes recrean y conservan todas las fixtures.
Las rutas absolutas en logs son procedencia de esta ejecución, no dependencias.
Se conservan los espacios finales del requerimiento original y del log bruto
de unittest. `git diff --check` los señala; no se limpiaron porque cambiaría
esos bytes de procedencia. Los documentos y scripts redactados no presentan
errores de whitespace en el diff.

## Regresiones

Desde la raíz del repo, con Python 3, Bash y Git:

```bash
review_evidence_dir="$(mktemp -d)"
python3 docs/reviews/2026-09-05-harness-hardening/red_regressions.py --repo . --output "$review_evidence_dir"
local_evidence_dir="$(mktemp -d)"
python3 docs/reviews/2026-09-05-harness-hardening/local_red_regressions.py --repo . --output "$local_evidence_dir"
state_evidence_dir="$(mktemp -d)"
python3 docs/reviews/2026-09-05-harness-hardening/supplemental_state_red.py --repo . --output "$state_evidence_dir"
```

Cada suite debe salir **1 en la base auditada**, por las aserciones descritas,
con `error_count: 0` y fuentes sin cambios. Fallar al arrancar, invocar mal un
comando o cargar un módulo inexistente no es el RED buscado. Durante el
desarrollo de la prueba local se corrigió un argumento `--quick` por `quick`;
la evidencia archivada corresponde a la ejecución corregida, que alcanza el
gate real y reproduce únicamente la ausencia de `version-sync` en ese scaffold.

Después de H01/H02 habrá que observar GREEN de los casos remediados y conservar
el RED original. Estos probes no se agregaron a `make check`: esta entrega es
una revisión bloqueada antes de implementación, no un fix ni un nuevo gate de
producto que se declare completo.

## Contratos propuestos

En un entorno de verificación con **PyYAML 6.0.3** y **jsonschema 4.26.0**:

```bash
proposal_evidence_dir="$(mktemp -d)"
python3 docs/reviews/2026-09-05-harness-hardening/validate_proposals.py --output "$proposal_evidence_dir/policy-validation.json"
```

PyYAML se usa aquí para leer estos cuatro documentos propuestos. No constituye
la implementación del parser YAML 1.2 estricto ni la prueba de equivalencia
del futuro pack. `runtime_verified` debe seguir siendo `false` en este informe.

La revisión independiente detectó dos diferencias entre prosa y contratos:
continuación humana/presupuesto demasiado amplia y falta de la prueba de
cobertura para remediación acotada. Se corrigieron en YAML y schemas, se añadieron
diez negativas y se preservó el resultado anterior. Son correcciones de diseño;
no cierres de los bypasses existentes del runtime.

## Verificación del repositorio

`./init.sh` y `make gates` funcionan con las dependencias legacy.
`make check` requiere además las herramientas de los packs: Node y k6 v2.1.0.
El primer intento sin k6 bloqueó; al instalar el binario oficial fijado por el
workflow en un directorio de herramientas de esta sesión, la suite completa
terminó con exit 0. No se modificaron las dependencias del repositorio.

No se ejecutó producción, no se validaron los doce escenarios históricos de
Aurobalance y no se aceptó una baseline. Sus estados PLANNED constan en la
[matriz](../test-matrix.md).
