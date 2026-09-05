# Dictamen independiente final de la propuesta documental

Fecha: 2026-09-05. Alcance: `docs/reviews/2026-09-05-harness-hardening/` y el
complemento portable de R13. El reviewer no modificó el repositorio; las
correcciones de las propuestas las hizo el agente implementador.

**No quedan hallazgos documentales High/Critical pendientes en el alcance
revisado después de las dos correcciones descritas abajo.** Se mantiene
`HARNESS_REVIEW_BLOCKED` por MIGRATION-01. Este dictamen no acepta una baseline,
no activa políticas, no aprueba una implementación y no cambia el estado de los
defectos de runtime de la auditoría original.

Se revisaron arquitectura, plan de migración, cuatro políticas, schemas,
taxonomía, matriz y la separación de resultados observados frente a escenarios
planificados. La documentación corregida distingue estructura válida, evidencia
real y autoridad; no presenta como implementados M01–M04 ni como ejecutado el
adapter Codex o un despliegue. No se verificaron de nuevo fuentes web ni servicios
externos en esta revisión final.

## Hallazgos detectados y verificación de corrección

Los dos hallazgos eran High del contrato propuesto: discrepancias que debían
resolverse antes de adoptar la política. No se afirma que existiera un runtime
activo capaz de explotar esas discrepancias.

| ID | Defecto documental detectado | Corrección verificada |
|---|---|---|
| DOC-H01 | `architecture.md:65` y `migration-plan.md:138` exigían preservar expectativas/cobertura en remediación acotada, pero `BOUNDED_REMEDIATION` no exigía esa prueba en YAML ni schema. El contrato estructurado admitía la omisión. | `policies/autonomy-policy.v1.yaml:112` exige `expectations_and_coverage_preserved`; `schemas/autonomy-policy.schema.json:848` lo fija como requisito mediante `contains`. Quitar esa prueba del documento corregido ahora falla validación. |
| DOC-H02 | La continuación genérica `new_verified_evidence_or_owner_decision` se aplicaba también a sign-off, aceptación de baseline y agotamiento de presupuesto. Era ambigua frente a las reglas que exigen aprobación o reautorización identificable y permitía describir esos gates con una ruta de continuidad insuficientemente específica. | Los estados HUMAN_DECISION requieren recibos humanos explícitos; sign-off/baseline usan `human_approval_receipt_verified` (`policies/stop-taxonomy.v1.yaml:44`, `:48`); budget usa `explicit_budget_reauthorization_verified` (`:72`). El schema fija esas mismas constantes y rechaza restaurar la continuación anterior. |

Se preservó el snapshot anterior en `document-review-snapshot/`, con manifest de
hashes y la observación estructural original. `document-corrections-verified.json`
contrasta ambas versiones: antes, la omisión de coverage y las continuaciones
ambiguas validaban; después, las mismas mutaciones se rechazan. Esta comparación
tuvo **16 checks, 0 fallos, exit 0**. Comprueba contratos estructurales y el estado
inactivo de las propuestas, no autenticidad de recibos ni efectos del runtime.

También se ejecutó de forma independiente `validate_proposals.py` sobre los
archivos corregidos: **42 checks, 0 fallos, exit 0**, con PyYAML 6.0.3 y jsonschema
4.26.0. La salida independiente está en `policy-validation-independent.json`.
Las dos cuentas son verificaciones de documentos; no deben sumarse como tests de
producto ni como demostración de equivalencia semántica del futuro motor.

| Documento corregido | SHA-256 revisado |
|---|---|
| `policies/autonomy-policy.v1.yaml` | `8bfc73b58350b306e2d0da11166a86fca0501eae76a7baaa3e1536f93bc442a5` |
| `policies/stop-taxonomy.v1.yaml` | `361d32e28edacb91880b5bdbb420ea21b7075121c9cc479b224f947c8ee60f37` |
| `schemas/autonomy-policy.schema.json` | `84fd34c6fe44dfb161847fedac25eba7e81738d6f823c16f7e80a09a20f85992` |
| `schemas/stop-taxonomy.schema.json` | `21cd00bfaaaa9591f02ae9f4055339cec53a988ba1d9b9057e7f55953aeac059` |

## Complemento portable R13

Se creó `supplemental_state_red.py` fuera del repositorio y se ejecutó contra la
base `88ea1e6c45faf5b5db9e29935eef6e25e50f633b`. Resultado: **3 tests, 3 fallos de
aserción esperados, 0 errores del runner, exit 1**. Cada caso usa una fixture Git
nueva creada mediante `tempfile`, con copia byte por byte de
`scripts/verify-feature.sh`. Las entradas, salidas y estados antes/después quedan
en `supplemental-state-baseline/`.

| Test | Expectativa segura | Resultado real del script sin cambios |
|---|---|---|
| 01, activación | `not_started` debe rechazarse antes de ejecutar y conservar estado/evidencia | Ejecutó la capa, creó marcador, promovió a `passing`, exit 0 |
| 02, WIP | Dos features `active` deben bloquear antes de ejecutar una de ellas | Ejecutó F1 y cambió su estado/evidencia, exit 0 |
| 03, unicidad | IDs duplicados deben rechazarse antes de ejecutar o emitir recibos | Promovió ambos registros homónimos; sólo corrió la primera capa, la segunda contenía `false`, exit 0 |

En el caso de IDs duplicados sólo una feature inicial estaba `active` y la otra
`not_started`: el defecto de unicidad queda aislado de la violación de WIP. No se
simulan funciones internas ni se acepta una excepción del runner como RED.

Reproducción, con un directorio de salida nuevo o vacío fuera del repo:

```bash
python3 supplemental_state_red.py \
  --repo /absolute/path/to/harness-kit \
  --output /absolute/path/to/new-state-evidence
```

| Artefacto | SHA-256 |
|---|---|
| `supplemental_state_red.py` | `46681b29d7f44fe26db64297942753b44875683ee1bd0d6f676e88b717508025` |
| `supplemental-state-baseline/results.json` | `e1fb6a319f879688a92e093c46fe0bc6332fddae75d3b4bd5fcd70152cba428a` |
| `scripts/verify-feature.sh` auditado | `3de5c857ac0f8bd574803cf53fb0aa3d6c430241f426a03a11321dd930011635` |

El hash del verificador fuente permaneció igual después de la ejecución. La copia
del complemento incorporada por el implementador al entregable se comparó con la
del reviewer y es byte idéntica.

Los defectos legacy permanecen abiertos porque esta entrega es documental. El
runtime futuro debe demostrar por ejecución sus invariantes; los schemas y este
dictamen no sustituyen TDD, revisión independiente posterior, adopción autorizada
ni aceptación humana de la baseline final.
