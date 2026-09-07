# F26 cleanup: revisión de evidencia y falsificación

Fecha: 2026-09-07. Lectura de `tests/consumer-distribution.test.py`, `.harness/oracles/AC-CONSUMER-DISTRIBUTION.yaml`, manager y evidencia recovery-fix en `/workspace/scratch/adce1c53b293/closure-pr36-integrated`.

**Conclusión: la falsificación de aprobación es reconstruible exactamente y debe reobservarse si cambia cualquier byte del helper/test. El helper Git actual no controla explícitamente la vida de posibles descendientes de mantenimiento. Esto no demuestra que mantenimiento Git causara el ENOTEMPTY del job101607579425.** No se ejecutó ninguna prueba ni se generó un nuevo RED en esta revisión.

## Qué está demostrado por lectura

`run()` hereda el entorno del proceso y llama subprocess.run con capture_output y timeout60. `git()` lo invoca como `['git', *args]`, sin opciones de configuración de mantenimiento ni seguimiento explícito de procesos descendientes. Espera la terminación del comando Git directo. Esa espera no constituye por sí sola una garantía de que cualquier descendiente desprendido haya terminado; un descendiente que conserve stdout/stderr también puede afectar la espera de pipes. El comportamiento real requiere observarlo.

ConsumerEndToEnd crea y elimina TemporaryDirectory alrededor de repositorios independientes. Sus casos ejecutan add/commit de la instalación vendorizada, consultas Git y clone local antes de salir del contexto. La instalación incluye muchos archivos de dependencias; esos comandos ofrecen puntos plausibles para actividad de mantenimiento automático. El código no solicita explícitamente ejecución desprendida, pero tampoco la prohíbe/configura ni comprueba ausencia de escritores antes del cleanup. La configuración Git heredada puede influir.

Por ello es creíble que una escritura posterior al retorno del comando directo compita con rmtree. También son posibles otros escritores o condiciones de filesystem. ENOTEMPTY durante `.git` solo identifica el fallo de eliminación; no identifica al escritor ni prueba un defecto de producción del manager. El log remoto concreto se recibió como descripción del controlador; no fue consultado por red en esta revisión.

El manager también invoca Git, pero su helper es distinto y realiza consultas con controles propios. No debe ampliarse una corrección del helper de tests a la política de producción sin evidencia que lo requiera. Una posible corrección de fixture debería conservar la operación de mantenimiento y esperar su finalización según las opciones soportadas por el Git efectivamente usado, no convertir el cleanup fallido en éxito silencioso.

## Falsificación retenida y reconstrucción exacta

El oráculo actual referencia `recovery-fix/evidence/unauthorized-red-receipt.json`, con proved_sha `0a51623b5db42951a6091847a179262182abd67d`. El recibo liga el archivo de test completo, no solo la función focal. Sus cinco referencias de tests/source/logs coinciden actualmente. El patch retenido elimina exactamente dos guards en read_plan:

- rechazo si falta --approve-plan;
- rechazo si el digest aprobado no coincide con planDigest.

Los sustituye por comentarios de mutación causal y deja el resto de la validación intacto. La prueba focal llama apply sin aprobación y primero exige que active.json no exista y que los bytes del consumidor no cambien. El RED histórico falla concretamente con `missing approval created an active selection`, en la primera aserción. No depende de ENOTEMPTY.

Reconstruí únicamente en memoria el hunk de texto retenido, sin ejecutar ni escribir el manager mutado. El contexto completo encuentra una sola coincidencia tanto en el manager histórico como en el actual, y su reversión reproduce exactamente la entrada:

| Bytes | SHA256 |
|---|---|
| Test original/actual inspeccionado | `3651818b4be511ac88f8c96aead84c962d8e3ff714004393d109613a5199c76a` |
| Patch de dos guards retenido | `f8718e5e0ba58b25a7f4f2c627a9ec68403bf66e0638fbe804e0fbead8d95f51` |
| Manager histórico guardado en Git PR36 43e3283 | `35d4e2ca41c3a3585ee4edb13def46596a6336dc1d61451ffd5363ae16c56b73` |
| Mutante histórico reconstruido en memoria | `0378b8a87bf3130f74ad979f3aa672a9418284854ede8c3dbfb96a3cd28f0d8c` |
| Manager actual aprobado | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` |
| Mutante del manager actual reconstruido en memoria | `1ed806aa50d271419e9c5f9b84fc45617ba8edfa83e6679905962047e07e3d60` |

Los hashes de mutantes describen reconstrucción de datos, no ejecución histórica recién autenticada. Para reproducir los bytes históricos originales, se parte de 43e3283 y su manager35d4, no del manager c204; para un nuevo test corregido sobre la fuente actual, se documenta una nueva observación con el manager c204 y su mutante correspondiente. No se sustituye una historia por la otra.

## Evidencia necesaria si se cambia git()

1. Preservar el test original de hash3651818b, el patch y todos los recibos/logs históricos antes de modificar el helper. Mantener la pérdida histórica F26-F1-M3 como HISTORICAL_INPUT_UNAVAILABLE: esta falsificación de aprobación reconstruible no recupera aquella entrada distinta.
2. Registrar el diff acotado del helper, versión/configuración Git relevante y los bytes finales del test. Capturar la observación que relacione el cleanup con un proceso/escritura concreta. Para atribuir causa a mantenimiento se necesita evidencia de su inicio, detach o lifetime y escrituras posteriores al comando padre; un rerun verde aislado no basta.
3. En una copia desechable de fuente declarada, conservar las rutas reales de repo que el test calcula mediante KIT. Incluir manager/runtime/assets/schema y archivos locales de dependencias requeridos. Sobre el manager base elegido aplicar únicamente el hunk retenido de los dos guards, exigir coincidencia única y registrar hash antes/después; no modificar el manager de trabajo/publicación.
4. Ejecutar allí, por el controlador autorizado, los bytes finales del test con el comando focal original: `python3 -I tests/consumer-distribution.test.py -k ConsumerRuntime.test_missing_approval_cannot_create_managed_effects`. El RED válido debe mostrar una selección activa sin aprobación y exit no cero. Un fallo de cleanup, dependencia, sintaxis o construcción de bundle no es ese RED. Conservar stdout/stderr/exit y el snapshot mutante.
5. Ejecutar el mismo test final sobre el manager íntegro y registrar GREEN sin efectos no autorizados. Por separado, observar los casos ConsumerEndToEnd afectados y el cleanup bajo las condiciones Git/CI pertinentes; luego cumplir el full gate requerido. La falsificación de aprobación comprueba que el cambio de helper no vacía aquella frontera, pero no es evidencia causal suficiente del arreglo de cleanup.
6. Crear un nuevo recibo RED con las seis claves exactas exigidas por el juez: schema_version, command, exit_code, tests, source, logs. tests debe vincular los bytes actuales; source debe vincular snapshots/patch; logs debe contener el fallo observado. Mantener cwd, versión Git, método de reproducción y límites en metadata separada. Apuntar el oráculo al nuevo recibo y usar un proved_sha real ancestro asociado a esa nueva observación, sin inventar una ejecución del commit histórico. Preservar el recibo anterior sin reescribir su hash para simular vigencia.

Cualquier cambio del helper invalida inmediatamente el test hash del recibo activo actual, aunque las aserciones no cambien. No resolverlo actualizando solo el digest dentro del recibo histórico. El nuevo RED/GREEN también debe distinguir el directorio de ejecución real para evitar el anterior problema de metadata de PR35.

## Límites y siguiente decisión

La lectura permite planificar una renovación exacta de evidencia y confirma que falta una garantía explícita de lifetime en el helper. No demuestra aún la causa del fallo remoto ni selecciona una opción Git concreta: el controlador está investigando qué mantenimiento se ejecutó y qué mecanismo de espera soporta su versión. No se recomienda borrar .git mientras un escritor siga vivo, ignorar errores de limpieza, matar procesos Git ajenos ni ampliar autoridad.

Solo inspección de texto, lectura de objetos Git y transformaciones/hash en memoria. Ningún código candidato o prueba ejecutado, ningún proceso persistente, red, credencial, cambio de repo o subagente. No se certifica CI, full check, aprobación de un cambio aún inexistente ni adopción de consumidor.
