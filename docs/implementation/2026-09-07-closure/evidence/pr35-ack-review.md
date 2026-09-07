# Revisión independiente del backport PR35 acknowledgement

Fecha: 2026-09-07. Worktree: `/workspace/scratch/adce1c53b293/closure-pr35-integrated`. Alcance: backport de publicación del acknowledgement v1 respecto de `pr35-ack-publication/integrated-product-before-fix.mjs`, sus dos nuevos archivos de prueba, oráculo y evidencia.

**Código: spec PASS, calidad PASS. Entrega completa de evidencia/oráculo: INCOMPLETE.** Hallazgos: 0 Critical, 0 High, 1 Medium y 1 Low, ambos de metadatos; ningún defecto concreto en el nuevo código de producción. El full make check sigue pendiente para esta revisión.

## Código y contrato

La diferencia respecto del producto integrado anterior añade publishAcknowledged y sustituye dos publicaciones directas: la recuperación de un paso pendiente y la publicación posterior a retener el resultado. Las correcciones M1/M3 permanecen. journal.mjs mantiene el hash aprobado previamente.

El helper realiza como máximo tres intentos, con esperas de 250 y 1000 ms, exclusivamente cuando recibe journalStatus BLOCKED_BY_OWNERSHIP. Una autoridad vencida, un acknowledgement ausente, un error de vinculación o cualquier otro error no recibe este reintento. Ningún intento vuelve a invocar verifier/worker, crea otro INTENT, genera una nueva clave o consume una unidad adicional.

Cada intento verifica loaded antes de adquirir custodia y lo repite dentro de ella; allí vuelve a leer el producto y comprueba fresh. Si otro proceso ya publicó el paso, termina de forma idempotente. De lo contrario exige la clave pendiente original y lee el acknowledgement mediante el mismo digest de dominio product.step.v1, objetivo y clave. persist utiliza el callback append ya protegido por custodia, preservando las validaciones existentes de resultado, binding, tipo de operación y estado anterior sin doble adquisición del lock.

La adquisición fallida no elimina un lock ajeno. Agotados los tres intentos, devuelve el bloqueo conservando el acknowledgement y el gasto. El helper no contiene renovación de autoridad ni de presupuesto. El PATCH original conserva su publicación interna bajo custodia; no se cambian esquemas, readiness ni concesiones.

## Pruebas y significado causal

Las nuevas pruebas generan un proceso verificador real y fuerzan una colisión mediante un wrapper de fs.openSync después de existir un acknowledgement. El fixture crea el lock de prueba y, solo para la variante transitoria, simula que su propietario lo libera en el siguiente intento. El código de producción no realiza esa eliminación.

El RED conservado muestra tres casos: publicación transitoria falla con un efecto, una carga, un acknowledgement y cero observaciones; el control de lock persistente pasa; la variante de expiración falla porque el código anterior nunca llega al segundo intento. Esta última caída demuestra falta de recuperación/revalidación después de liberar custodia, no que el código anterior publicara con autoridad vencida.

El GREEN muestra cinco casos aprobados sin skips: los tres anteriores más linked-worktree y UTF-8. La variante transitoria conserva un efecto y una carga con una observación, y resume sin otro efecto. La persistente registra seis colisiones entre execute y resume, conserva los bytes del lock antes de la limpieza del fixture y deja una carga/acknowledgement sin observación. La variante de expiración modifica el reloj al liberar el lock y confirma BLOCKED_BY_STALE_AUTHORITY sin publicar.

Los 42 hashes referenciados por los dos receipts coinciden con los archivos retenidos actuales. Los 33 archivos del manifiesto RED coinciden byte a byte con sus objetos Git de `dd8a20c1465b3ccd7e9a4d86ed6a11860146e7f7`. El snapshot integrado previo tiene el hash esperado de M1/M3 ya corregidos. Estas comprobaciones respaldan la procedencia local de los archivos; no autentican por sí solas la ejecución histórica.

El diagnóstico del full race anterior queda preservado. Su log establecía un efecto y cero observaciones, sin resultados de los hijos. Este RED determinista establece una carencia reproducida por separado; no demuestra la intercalación exacta de aquel fallo.

## ACK-M1 — Medium — El recibo RED no cumple el contrato del oráculo

AC-product-ack-publication referencia red-receipt.json. Tanto scripts/verify-oracles.sh como el verificador protegido exigen en su línea 269 exactamente las claves schema_version, command, exit_code, tests, source y logs. El recibo observado contiene además working_directory, pass, fail e historical_failure_limit. Por inspección directa del contrato, será rechazado con invalid receipt fields antes de validar sus hashes.

Las rutas relativas, hashes y conjunto de los dos tests del oráculo son coherentes; el problema es el esquema del recibo. Conservar el registro detallado como evidencia y añadir un recibo de seis campos referenciado por el oráculo, ubicando el contexto adicional en un archivo de verificación/metadata. No relajar el verificador protegido. Este hallazgo impide dar PASS al paquete completo aunque el código sea correcto.

## ACK-L1 — Low — Directorio de ejecución GREEN ambiguo/incoherente

El green-receipt.json declara como working_directory el snapshot exacto original de PR35 descrito por source-manifest.json. Ese manifiesto describe el RED con producto original, mientras GREEN referencia el producto integrado corregido y un argv con rutas completas desde la raíz del repositorio. A diferencia de RED, no usa `tests/product-ack-publication.test.mjs` relativo a una copia directa del runtime.

Precisar el directorio/layout real del comando GREEN y la relación con sus archivos corregidos. No basta copiar el texto del recibo RED. El log sí muestra cinco resultados GREEN y el hash del producto corregido coincide; no se establece falsificación ni defecto del runtime. Como mejora de completitud del registro, GREEN también puede vincular explícitamente product-corrections-fixture.mjs, importado por los dos tests M1/M3 (su hash actual sigue siendo e57fa5d6b9b8d24148c9a0df83247ba89fcd819d96521a2a1aa118a65de0ce41).

## Identidades inspeccionadas

| Archivo relativo al worktree | SHA256 |
|---|---|
| packs/autonomy/repo-template/scripts/quality-orchestrator/product.mjs | `01e1338655c5c835242308e2e833ee27f375cf6e47989f027ae8d8b6a930d8e0` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-ack-publication.test.mjs | `c45bc825f37b6e41177850723721d449c8dc3c717ded9501851777f86518a6f4` |
| packs/autonomy/repo-template/scripts/quality-orchestrator/tests/product-ack-fixture.mjs | `de87e5347ea111cf57df5dfa476294639811c9e3c4f812661c01d2634d7357b8` |
| docs/implementation/2026-09-07-closure/pr35-ack-publication/integrated-product-before-fix.mjs | `5202e4994c008acb08739670a90bd43adb2e5275f8f29f310cd0961701e6e006` |
| docs/implementation/2026-09-07-closure/pr35-ack-publication/red-receipt.json | `6378a68217d41c2384ac8f72e493d0c174666618c526d3fa9259eec8e486d64a` |
| docs/implementation/2026-09-07-closure/pr35-ack-publication/green-receipt.json | `dff719a13832d35fdc89b46d2e194efcd41605e1a398ac7faad8ce0543524c7d` |
| docs/implementation/2026-09-07-closure/pr35-ack-publication/source-manifest.json | `e4776f4e404284c0b7f10a06adcaa5e29c19c13a24d07477ab86c500d52fc361` |
| .harness/oracles/AC-product-ack-publication.yaml | `c4e39c1bd5dd1418d0da9401df0341b2668c57e3a8d75fb2f5770549500b4bce` |

## Límites

Revisión estática y comparación de bytes/datos únicamente. No ejecuté código candidato, pruebas, probes ni verificador; no usé red, credenciales, autoridad, subagentes, cambios del repositorio o commits. Los resultados de ejecución proceden de logs suministrados. Los fixtures no representan dos propietarios reales independientes en esta prueba determinista, ni autoridad/modelo/aislamiento de producción. No certifico full check, CI remoto, aceptación real, integración completa ni la causa exacta del fallo concurrente previo.


## Follow-up de metadatos — 2026-09-07T03:02:00.922665+00:00

**Veredicto vigente: spec PASS, calidad PASS. ACK-M1 y ACK-L1 cerrados. Hallazgos abiertos: 0 Critical, 0 High, 0 Medium, 0 Low.** Se conserva arriba la observación inicial; esta sección actualiza su estado tras una nueva lectura independiente.

El oráculo ahora referencia red-gate-receipt.json. Verifiqué que contiene exactamente las seis claves admitidas por el contrato, que todos sus valores son idénticos a los correspondientes del recibo detallado original y que todos sus hashes de tests/source/logs coinciden. El registro detallado y sus límites históricos siguen presentes. No se necesita ninguna modificación del juez. SHA256 del nuevo recibo canónico: `7135791449ca03f0061cb75e2f90eb88c3df7daf9b7e4bddad7200e27a0ab320`.

GREEN declara ahora el directorio real `/workspace/scratch/adce1c53b293/closure-pr35-integrated`, coherente con su argv relativo a la raíz y el producto corregido. Su SHA256 actual es `dff719a13832d35fdc89b46d2e194efcd41605e1a398ac7faad8ce0543524c7d`. La nota aparece bajo implemented/bug-fix y el primer fallo de metadata queda preservado en first-metadata-gate-failure.log. No se certificó por ejecución el gate de lifecycle.

Producto, journal y ambos nuevos archivos de prueba mantienen exactamente los hashes revisados arriba; el producto sigue en `01e1338655c5c835242308e2e833ee27f375cf6e47989f027ae8d8b6a930d8e0`. No ejecuté pruebas ni modifiqué el repositorio. El full check reanudado, CI remoto, aceptación real y la causa exacta del race histórico permanecen fuera de este PASS acotado.
