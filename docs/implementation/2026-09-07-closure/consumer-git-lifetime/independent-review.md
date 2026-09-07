# Revisión independiente: consumer Git lifetime

Fecha: 2026-09-07. Worktree inspeccionado: `/workspace/scratch/adce1c53b293/closure-dependencies`. HEAD real `6677e9978dfd9fa344186a65adddcadabd21cc7e`; MERGE_HEAD real `b567669fcd41c40caa8235e758a0f1fdca9a00a5`; base común `e5bfa5343d064e376086e2b13e45203b4ad4a481`.

**Spec del helper y falsificación: PASS. Calidad global del ajuste de fixtures: CHANGES_REQUIRED por un Low residual. Resolución mecánica del merge: PASS.** Hallazgos nuevos: 0 High, 0 Medium, 1 Low. No se certifica full check ni CI.

## CG-L1 — Low — Un commit del fixture elude el helper corregido

En `tests/consumer-distribution.test.py:647`, la inyección de `test_head_change_after_prepare_blocks_selector_effect` ejecuta directamente `subprocess.run(['git','-C',target,'commit',...], check=True)`. No pasa por `git()` y no incluye `maintenance.autoDetach=false` ni `gc.autoDetach=false`. El entorno heredado tampoco introduce esas opciones para esa invocación. Por tanto, ese comando que escribe en el repositorio temporal conserva la posibilidad de lanzar mantenimiento detached si se activa su umbral/configuración; esperar al proceso inmediato no extiende por sí solo el lifetime hasta los descendientes detached.

Es una omisión concreta en la aplicación de la política del fixture, no una regresión del manager ni una explicación establecida del fallo CI. Los dos lifecycle tests ejercitan exclusivamente el helper y no detectan esta excepción. Mantener ambas opciones también en ese commit directo cerraría el hueco sin alterar su mutación intencional de HEAD. Si cambia el archivo del test, el hash current-test del oráculo y la nueva falsificación deben volver a corresponder a esos bytes; conservar los recibos anteriores.

## Helper, tests y evidencia causal

El cambio de `git()` añade únicamente dos opciones `-c` para mantener foreground el mantenimiento automático. No desactiva mantenimiento, no ignora errores de Git ni de limpieza y no altera el manager. Se conserva el timeout y la comprobación de retorno.

Los dos casos nuevos crean objetos reales alcanzables, preparan el fanout utilizado por auto-GC y disparan tanto `gc --auto` como un commit normal. Leen eventos Trace2 después del retorno del helper, exigen un `pack-objects` observado con salida cero, ausencia de `gc.pid` y un pack producido. No son mocks del mantenimiento; desactivarlo no satisface las aserciones. La espera de limpieza está en `finally`, después de las aserciones, y no puede convertir su fallo en PASS. Está acotada a 20 segundos y conserva el directorio si continúa el lock, en lugar de ocultar ese fallo.

La limpieza del RED usa observación de `gc.pid`, con una segunda lectura después de 100 ms. Es una mitigación acotada para estos casos; no constituye prueba universal de ausencia de cualquier descendiente o escritor externo. Tampoco los eventos leídos después del retorno proporcionan una medición atómica del instante exacto de retorno. Estos límites no invalidan el fallo retenido: en ambos RED no se había observado siquiera un packer al leer el trace. La prueba local separada sí conserva eventos de packing posteriores al timestamp de retorno y el mensaje explícito de auto-packing en background.

Comparé el RED retenido con el test actual: la única diferencia es el cuerpo del helper y su comentario; los dos casos y su cleanup son idénticos. El test original retenido coincide exactamente con el blob publicado b567669f. Los logs conservan RED 2/2 por la aserción de packing, GREEN 2/2 y E2E original 2/2. Revisé esos registros sin ejecutarlos. Los logs GREEN/E2E son evidencia local retenida; no sustituyen la verificación completa pendiente ni una reejecución independiente.

## Falsificación de aprobación y metadata

Los 34 archivos del manifest coinciden con sus hashes. No hay archivos extra en `approval-defective-snapshot`. Comparados con b567669f, los únicos cambios son el manager con exactamente los dos guards históricos de `read_plan` retirados y el test actual. El snapshot contiene assets, schema y runtime originales de b567, incluidos sus contratos; no se presenta como runtime integrado actual. El test del snapshot coincide byte por byte con el test vigente del worktree.

El recibo de falsificación conserva exactamente sus seis claves (`schema_version`, `command`, `exit_code`, `tests`, `source`, `logs`); todas sus referencias y hashes coinciden con los archivos leídos. El manifest queda ligado mediante el hash de `approval-reproof-metadata.json`. El cwd registrado existe y corresponde al snapshot. El RED guard falla específicamente con `missing approval created an active selection`, no por limpieza, imports ni dependencias; el control GREEN retenido pasa esa misma prueba en el manager intacto.

El `proved_sha` del oráculo coincide con el HEAD real del controlador, 6677e997. La metadata declara explícitamente b567669f como base de fuentes y MERGE_HEAD durante el merge, y la presencia del test actual/mutante. Es una nueva observación local sobre un overlay identificado, no una afirmación de que 6677 o b567 ya contuviesen el test nuevo. Los recibos históricos y su test previo permanecen conservados. El input perdido F26-F1-M3 sigue separado y no se recertifica.

## Unión inversa y política

Reconstruí en memoria la selección de tres vías de ambos padres. De los 2.034 archivos no conflictivos, 2.032 coinciden en bytes y modo; las dos diferencias son exactamente el test y el oráculo de esta corrección. No hay omisiones inesperadas. Los únicos cuatro archivos modificados por ambos padres son PROGRESS, feature_list, inventory y quality-document. En la lectura final no hay entradas unmerged en el índice ni marcadores de conflicto en esos documentos.

Los 27 objetos de features preservan literalmente todos los registros de ambos padres: F09/F25 blocked, F26 passing y F28 única active. Los cuerpos históricos completos de PR35 y PR36 están retenidos en PROGRESS, incluidos la carrera sin interleaving demostrado y los límites P0. La integración corriente mantiene explícitos el fallo remoto y el full gate pendiente. Los 31 archivos del juez v1 permanecen intactos. Producto, journal, manager y runner coinciden con las cuatro identidades aprobadas de source-resolution, cuyo primer padre y MERGE_HEAD corresponden a Git. No se debilita el juez para acomodar el cambio del orden de merge.

GR03/GR05 continúan abiertos; instalación no equivale a adopción, y la limitación de migración entre managers permanece documentada. Esta revisión no autoriza main, piloto ni release.

## Identidades verificadas

| Fuente | SHA256 |
|---|---|
| Test actual | `a9487a0596038df75d57754366ac91fd56b7e707773679e3962c35dc5124e17e` |
| Test RED con helper original | `c23085b1d2a3b1c5937bed2485dc6b5cf6e0a73267a181ee03e3619cd940009f` |
| Test original b567 | `3651818b4be511ac88f8c96aead84c962d8e3ff714004393d109613a5199c76a` |
| Manager intacto | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` |
| Manager mutante | `1ed806aa50d271419e9c5f9b84fc45617ba8edfa83e6679905962047e07e3d60` |
| product.mjs | `01e1338655c5c835242308e2e833ee27f375cf6e47989f027ae8d8b6a930d8e0` |
| journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| tests/run-tests.sh | `2427fe61ce005711b6a11627d8d8d716cfcc0bd90d8e2dfb872d9d36a77b68c7` |
| Oráculo AC-CONSUMER-DISTRIBUTION | `90d8fc641ec6c6b6481b708e17a268aff2e9105b822a02eab5988e85934cbbc2` |
| approval-red-receipt.json | `57faa6a3bfe4b3d56c3b4628822ce2dc296eda0bc1efec53e1fc433cc043e63c` |
| approval-reproof-metadata.json | `ce13f986bfae154ae3d6b3b8117de14d09839bc05ddafe790e3a041b3effc41e` |

## Límites de revisión

Solo lectura de código, Git, datos, hashes y logs; sin ejecutar candidato, tests, probes o red, sin modificar repositorio y sin subagentes. La prueba de lifecycle local corresponde a Git 2.51.1. El escritor/interleaving de la excepción ENOTEMPTY de CI Git 2.55.0 no está identificado: compatibilidad de síntomas no demuestra causalidad exacta. El full make check combinado está pendiente según el alcance recibido y no se declara aprobado aquí.
