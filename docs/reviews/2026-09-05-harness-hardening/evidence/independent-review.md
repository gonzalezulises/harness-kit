# Revisión independiente de verificadores

**Estado: `HARNESS_REVIEW_BLOCKED`.** Fecha: 2026-09-05. Revisión limitada al
repositorio `harness-kit`, snapshot exacto `88ea1e6c45faf5b5db9e29935eef6e25e50f633b`.
Se confirmaron siete defectos High de integridad del verificador y una fricción
Medium. No se demostró un defecto Critical ni se afirma haber eludido todo el
pipeline de GitHub.

Los verificadores y las pruebas existentes quedaron intactos. Se leyeron
`AGENTS.md`, `PROGRESS.md`, `feature_list.json`, `DECISIONS.md`, las rutas de contexto
y las pruebas relacionadas. `bash ./init.sh` terminó con **273 passed, 0 failed**.
La suite independiente ejecutó los scripts reales en fixtures Git aisladas:
**8 tests, 11 fallos de aserción, 0 errores del runner**, salida 1 esperada.
Los fallos corresponden a expectativas seguras no cumplidas; no son reparaciones
implementadas. Tres tests tienen dos variantes cada uno.

La severidad High describe una garantía central del gate que produce un aprobado
indebido o permite continuar tras un bloqueo. No equivale a una clasificación de
explotación remota. Los cambios de política propuestos requieren la decisión que
corresponda; estas pruebas no conceden autoridad para hacerlos.

## Evidencia y reproducción

`red_regressions.py` admite `--repo` y `--output`. Usa `tempfile.mkdtemp` dentro de
`--output/fixtures`, copia los tres scripts byte por byte y conserva los inputs,
outputs, códigos de salida y estados anteriores y posteriores. Rechaza escribir
dentro del repositorio fuente y rechaza sobrescribir evidencia existente. Necesita
Python 3, Bash y Git; no usa red ni instala dependencias.

```bash
python3 red_regressions.py \
  --repo /absolute/path/to/harness-kit \
  --output /absolute/path/to/new-independent-evidence
```

En el snapshot auditado debe terminar en **exit 1** con once aserciones fallidas.
Una salida 0 futura sólo probaría que estos contraejemplos quedaron resueltos;
no probaría la seguridad completa del harness ni aprobaría una release.

La ejecución conservada está en `red-baseline/`: `results.json`, `unittest.log`,
un JSON por test y sus fixtures. `results.json` registra que los tres scripts
fuente conservaron sus hashes después de ejecutar la suite.

| Script auditado | SHA-256 |
|---|---|
| `scripts/verify-feature.sh` | `3de5c857ac0f8bd574803cf53fb0aa3d6c430241f426a03a11321dd930011635` |
| `scripts/verify-claims.sh` | `490df3894b603871bbefe2b019d7478b1628e66b32f1984cf84201d7dc13a940` |
| `scripts/verify-decisions.sh` | `4ebffe568fc05764a20ca0a80eedb4faf7b16db9a54d10c2acb571801757da87` |

Los números de línea siguientes corresponden exclusivamente a ese snapshot. La
suite original comprobó también que las copias de `templates/full/scripts/`
estaban sincronizadas con las de `scripts/`.

## Hallazgos confirmados

| ID | Severidad | Localización principal | Reproducción y resultado observado |
|---|---|---|---|
| IR-H01 | High | `scripts/verify-feature.sh:93`, `:98`, `:232`, `:237` | Test 01. Presupuesto máximo 2; el mismo comando falla dos veces: salidas 1 y 3, estado `blocked`. Se corrige una entrada del comando sin modificar estado, ledger o autorización. Una tercera llamada ejecuta otra vez, sale 0, escribe `passing` y reinicia el ledger. Se observan tres ejecuciones. |
| IR-H02 | High | `scripts/verify-feature.sh:71`, `:74`, `:127`, `:143` | Test 02. Una capa con `cmd: ""` y `repair: "printf ... > repair-executed"` termina en exit 0 y `passing`; el archivo marcador demuestra que se ejecutó `repair`. La separación TSV mediante IFS colapsa el campo vacío y desplaza el texto de reparación a la columna comando. |
| IR-H03 | High | `scripts/verify-claims.sh:117`, `:134`, `:136` | Test 03, dos variantes. JSON malformado imprime traceback, después `NO_CLAIMS` y exit 0. Con JSON válido, F1 correcta y F2 con `layers: [123]`, imprime traceback, ejecuta sólo F1 y declara `Every passing state is backed by a run`, exit 0. Se ignora el fallo del proceso que recopila los claims. |
| IR-H04 | High | `scripts/verify-claims.sh:56`, `:58`, `:69`, `:73` | Test 04, dos variantes. La base real exige `test -f required-evidence`; head lo cambia a un comando siempre verde. Si `CLAIMS_BASE_FILE` apunta a un archivo ausente o JSON malformado, la comparación se omite y se ejecuta head: exit 0 y marcador `layer-executed`. Ausencia de autoridad se interpreta como ausencia de restricciones. |
| IR-H05 | High | `scripts/verify-claims.sh:202`, `:203`, `:215` | Test 05. Una feature tiene capas `test -f ready && echo ready`, `rm ready`, y la primera orden otra vez. El gate reutiliza el primer resultado y sale 0. Ejecutar directamente la última orden sobre la misma fixture termina en exit 1. El texto idéntico no demuestra equivalencia cuando cambiaron las entradas. |
| IR-H06 | High | `scripts/verify-decisions.sh:57`, `:59`, `:64`, `:65` | Test 06, dos variantes. Se altera una decisión existente. Pasar una ref inexistente o `DECISIONS_BASE_FILE` ausente produce `NO_LEDGER`, exit 0. El verificador no distingue base ilegible de ausencia de ledger demostrada en una base válida. |
| IR-H07 | High | `scripts/verify-decisions.sh:116`, `:117` | Test 07. En un bloque Python de la decisión, `deploy()` pasa de ocho a cuatro espacios y deja de depender de `owner_approved`, manteniéndose dentro de `authorized`. Ambos programas son válidos. Con `authorized=True, owner_approved=False`, base no despliega y head sí. `diff -b -B` lo considera intacto: exit 0. |
| IR-M01 | Medium | `scripts/verify-claims.sh:88`, `:106` | Test 08. Sólo cambia `repair`; `cmd` conserva exactamente sus bytes. Se sigue la instrucción mostrada por el propio gate: volver a `active`, ejecutar `verify-feature.sh` y volver a verificar claims. Las salidas son 0, 0 y 5. `WEAKENED_VERIFICATION` muestra el mismo comando en `was` y `now`; el flujo recomendado no permite completar esa misma PR. |

IR-H01 contradice la condición de parada que el script imprime y el contrato de
presupuestos. La corrección de una entrada no es una autorización de reapertura.
La comprobación debe ocurrir antes de ejecutar más trabajo y la evidencia de
agotamiento no debe desaparecer. El diseño exacto de autorización y del journal
queda fuera de esta revisión y requiere decisión explícita.

IR-H02 cruza una frontera de autoridad: un campo de orientación se vuelve código
ejecutable. La prueba no necesita cambiar el verificador. Es más que aceptar una
capa vacía: demuestra qué texto acaba ejecutándose.

IR-H03, IR-H04 e IR-H06 muestran resultados verdes de verificadores individuales
con datos o bases ilegibles. Otro gate correctamente integrado podría bloquear
algunas de esas entradas; esta revisión no presume ni demuestra tal cobertura.
No se propone prohibir un repositorio legítimamente sin ledger: se exige
distinguir esa situación de una lectura fallida de la base.

IR-H05 no depende de relojes, servicios externos o aleatoriedad. Es un
contraejemplo determinista a que el mismo texto, dentro de un checkout, siempre
autorice reutilizar el resultado anterior. No se encontró un contrato ejecutable
de inmutabilidad de entradas que justificara esa equivalencia.

IR-H07 afecta decisiones que contengan formatos donde la sangría o los espacios
tengan significado, por ejemplo código o configuración. No se afirma que el
`DECISIONS.md` actual haya sido alterado así. La ejecución Python sólo agrega
eventos a una lista local; no realiza un despliegue.

IR-M01 documenta una expectativa de política propuesta: no clasificar como
verificación debilitada el cambio de `repair` cuando los comandos y sus entradas
autorizadas conservan su equivalencia. La expectativa no autoriza cambios
semánticos, de presupuesto, de evidencia ni de condiciones de parada. Su aserción
RED permite revisar la fricción de forma concreta antes de decidir la excepción.

## Cobertura existente y límites

`tests/run-tests.sh:425` comprueba presupuestos sin condición de parada;
`:439` comprueba el instante del agotamiento, pero no un reintento posterior.
`:457` comprueba el reset de una corrida verde antes de agotar el presupuesto.
Por eso esos tests no detectan IR-H01.

`tests/run-tests.sh:510` y siguientes cubren claims honestos, falsos, sin capas y
sin evidencia. No cubren errores de parseo, recorrido parcial ni pérdida de la
base explícita. `:572` cubre la transición intermedia a `active`, pero no la
promoción posterior seguida de otra llamada al checker. `:1036` y siguientes
cubren deduplicación con resultados estables; no insertan una capa que cambie las
entradas de la comprobación reutilizada.

`tests/run-tests.sh:744` y siguientes cubren decisiones intactas, anexadas,
editadas o borradas y la base recibida como archivo. No cubren la ref ilegible,
el archivo base ausente ni espacios con significado dentro de una decisión.

Se confirmaron además dos problemas Medium, fuera de los ocho tests portables:
`verify-feature.sh` permite `not_started → passing` sin comprobar WIP, y con IDs
duplicados carga las capas del primer elemento pero marca todos los homónimos
como `passing` (`:64`, `:75`, `:230`). En la fixture del segundo caso la segunda
feature contenía `false` y nunca se ejecutó. El checker de claims puede detectar
posteriormente ese comando falso, por lo que no se presenta como bypass completo
del CI.

Una hipótesis de colisión de slugs de títulos en decisiones **no** reprodujo un
bypass: el script rechazó el cambio. Se excluyó de la suite y de los hallazgos.

No se revisaron otros repositorios ni se ejecutaron ataques contra GitHub,
servicios o releases. Las pruebas no cubren todas las combinaciones de esquema,
concurrencia, señales o comandos arbitrarios. No hay cambios de runtime,
relajación de gates, aprobación nueva, journal migrado ni release preparada por
esta revisión. El resultado justifica mantener `HARNESS_REVIEW_BLOCKED` mientras
se decide y revisa el contrato de transición.
