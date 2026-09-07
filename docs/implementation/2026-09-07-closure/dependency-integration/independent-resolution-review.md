# Revisión mecánica final de resolución PR35 → PR36

Fecha: 2026-09-07. Worktree `/workspace/scratch/adce1c53b293/closure-dependencies`. HEAD real leído: `5a1a0b872fb8f1eb8fd0e54b767f019657eb1ea0`; MERGE_HEAD real: `b567669fcd41c40caa8235e758a0f1fdca9a00a5`.

**Spec PASS; calidad PASS para la recomposición y preservación revisadas. Hallazgos: 0 High, 0 Medium, 0 Low.** El full check final en curso no se certifica aquí.

Comparé los 248 archivos del snapshot `dependencies-before-ci-parent/files` contra su manifest y el worktree. El snapshot es consistente con todos sus hashes. Los 248 archivos están presentes; 245 coinciden exactamente en bytes y modo. Las tres diferencias son PROGRESS, inventory y source-resolution: actualizan el padre actual, el cierre independiente de CG-L1 y el checkpoint CI, conservando la historia. No cambia el test final, el oráculo ni sus fuentes/recibos históricos al restaurarlos.

La comparación de tres vías entre ambos padres y su base encuentra 2.042 archivos no conflictivos. Solo difieren de la selección esperada el test consumidor y su oráculo, exactamente las correcciones ya aprobadas. No hay archivos esperados omitidos. Los únicos cuatro archivos modificados por ambos padres son PROGRESS, feature_list, inventory y quality-document. El índice no contiene entradas unmerged; la resolución documental inspeccionada no contiene marcadores de conflicto.

Los 27 objetos de feature_list preservan literalmente los registros de ambos padres. F09 conserva su bloqueo histórico, F25 sigue blocked, F26 passing y F28 es la única active. No desaparece ningún ítem del inventario de ninguno de los padres; las diferencias frente a cada padre seleccionan los checkpoints PR35-MERGE-1 y PR36-MERGE-1 actualizados del padre correspondiente. CG-L1 queda cerrado con su revisión vinculada. El nuevo current_dependency_worktree identifica el padre 5a1a, mientras el objeto previo dependency_integration conserva la identidad histórica 6677.

PROGRESS conserva los bloques históricos PR35/P0 y PR36 del snapshot y solo actualiza el resumen actual. Distingue el primer full check combinado, anterior a CG-L1, del full check final requerido; mantiene desconocida la causa exacta del fallo remoto de limpieza. quality-document permanece idéntico al snapshot: conserva los límites de migración entre managers, NOT_ADOPTED, F09 histórico y aceptación real. GR03/GR05, main, piloto y release permanecen abiertos.

Todos los seis hashes de source-resolution coinciden con los archivos actuales. El workflow es idéntico al blob del nuevo padre 5a1a; esta revisión verifica su preservación, sin sustituir la revisión mecánica del timeout ya realizada por otro revisor. Los 31 archivos del juez v1 permanecen intactos. El oráculo consumidor conserva el hash aprobado y apunta a la falsificación final de CG-L1.

Las dos metadata de falsificación mantienen literalmente `controller_head: 6677e9978dfd9fa344186a65adddcadabd21cc7e`: la primera con SHA256 `ce13f986bfae154ae3d6b3b8117de14d09839bc05ddafe790e3a041b3effc41e` y el follow-up con `4f0df2ad90fc16e1718737156c68473e8b0b2ebd3b0ee61ff970c9c9f3c3fe0a`. No se reescribe la observación histórica como si hubiese ocurrido en 5a1a. El follow-up CG-L1 aprobado se incorpora separadamente.

| Fuente preservada | SHA256 |
|---|---|
| product.mjs | `01e1338655c5c835242308e2e833ee27f375cf6e47989f027ae8d8b6a930d8e0` |
| journal.mjs | `fdf4d7d59184b78f2dafdee53a863bc8832b8c33ec945e2a7abadbaca0b3c944` |
| bin/harness-consumer.py | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` |
| tests/run-tests.sh | `2427fe61ce005711b6a11627d8d8d716cfcc0bd90d8e2dfb872d9d36a77b68c7` |
| tests/consumer-distribution.test.py | `ff257fbaa73fd81adbca5030dc73c760d4866dafa0962b4e5ec5fa84e6557804` |
| .github/workflows/required-quality.yml | `7ee4a7cebb41fbf49bcdf8ded65c47de4bb4697314b2eb6ca79719192d77e1fd` |
| AC-CONSUMER-DISTRIBUTION.yaml | `b4c8dea2b68776ad83adefb5bce46f0a78ce84cb04dfb3adf7f8d9132fed88f8` |

Alcance: lectura de Git, archivos, datos y hashes; sin ejecutar candidato, tests, probes o red y sin modificar repositorio. No es una nueva revisión funcional completa, aprobación global, certificado CI ni aceptación de main/piloto/release. La prueba local de Git lifetime y el desconocimiento del interleaving remoto mantienen los límites de los informes anteriores.
