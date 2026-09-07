# Revisión independiente: límite temporal de Required quality

Fecha: 2026-09-07. Alcance exclusivamente estático; no se ha editado, adoptado ni ejecutado ninguna propuesta.

**Dictamen: el cambio exacto `timeout-minutes: 30` → `timeout-minutes: 60` es un ajuste mecánico del tiempo disponible para CI, compatible con el mandato de cierre descrito. No exige una nueva adopción del juez ni una decisión específica sobre sus criterios de aprobación.** Sí es una modificación de un workflow protegido y debe tramitarse mediante los controles ordinarios aplicables. Esta clasificación no autoriza excepciones, bypass, cambios de rulesets ni marcar como exitoso el run cancelado.

## Evidencia del bloqueo

Worktree examinado: `/workspace/scratch/adce1c53b293/closure-pr35-integrated`, HEAD `6677e9978dfd9fa344186a65adddcadabd21cc7e`. El log identifica run `34079150314`, intento 1, base `e5bfa5343d064e376086e2b13e45203b4ad4a481` y workflow SHA `b056bcc327c2c9d04c5bdfa3d8428682c64a90c6`. El controller aporta job `101610962956` y duración 03:17:23–03:47:45.

El primer timestamp del runner en el archivo es 03:17:27.210; la cancelación figura a 03:47:39.419, unos 30 minutos y 12 segundos después. `.github/workflows/required-quality.yml:31` configura exactamente 30 minutos para todo el job. claims empezó a 03:35:37, después de completar el pipeline, y continuó avanzando por features hasta F24 a 03:46:35. El log termina esa fase con «The operation was canceled», no con una conclusión de claims.

La evidencia final conserva CHECK_OUTCOME=success, CHECK_EXIT=0, gates/lint/Gherkin success, CLAIMS_OUTCOME=cancelled sin exit, DECISIONS_OUTCOME=skipped y conclusión blocked. El mecanismo fail-closed funcionó: el éxito previo del pipeline no sustituye claims ni decisions.

**La causa timeout es una inferencia fuertemente respaldada, no un diagnóstico explícito de la plataforma en ese texto.** El mensaje genérico de cancelación por sí solo también sería compatible con cancelación manual o supersesión. No se inspeccionó red/API/auditoría para excluir esas causas. La coincidencia temporal con el límite, y el progreso visible hasta la cancelación, justifican revisar el margen del job; no demuestran que 60 minutos bastarán ni que claims terminará pasando.

## Relación con la política adoptada

El judge-contract, tanto en raíz como dentro del bundle v1, contiene exclusivamente schema_version=1 e interfaces target-root-v1, installation-profile-v1 y match-argv-v1. No declara un límite de 30 minutos. El oracle adoptado AC-F24-protected-ci exige resolver contrato, parser, runner, claims y decisiones bajo el checkout de base y no usar fallback del candidato; tampoco fija 30 minutos.

El bundle `.harness/protected-judge/v1/` no presenta diferencias Git frente al head de adopción `b6b93e4fd8241298471e9cfc4356ecca47412f43`. Sus 30 hashes y modos locales coinciden con SOURCE.json. Su manifest continúa siendo `81099c812e9c094ed6210b877f44b4317aadf0f8ec2c98cf26163285b5026143`. La documentación de adopción distingue ese snapshot protegido de los cambios posteriores del workflow que lo invoca.

La sustitución propuesta cambia sólo el techo de ejecución del job. Conserva las identidades exactas base/head, el checkout del juez de base, el contrato, los comandos, las verificaciones de claims y decisiones, el orden, los permisos de sólo lectura, acciones fijadas y todos los sentinels de salida cero. No modifica los límites firmados del runtime, las identidades de capas protegidas, el presupuesto de revisión ni las reglas que permiten PASS. Permite observar más tiempo la misma evaluación; no convierte un resultado distinto de cero, omitido o cancelado en aprobación.

La propuesta concreta examinada corresponde a sustituir una única aparición, con SHA-256 del workflow resultante calculado en memoria `7ee4a7cebb41fbf49bcdf8ded65c47de4bb4697314b2eb6ca79719192d77e1fd`. No se escribió ese archivo.

## Riesgos y controles ordinarios

El coste/ocupación máximo del runner y el tiempo hasta detectar un proceso colgado aumentan de 30 a 60 minutos. El límite sigue siendo finito. Las trazas actuales muestran trabajo adicional real en claims, de modo que el aumento tiene una justificación operativa concreta. No hay evidencia para considerar los 30 minutos un requisito de seguridad o aceptación funcional del producto. No debe extrapolarse este dictamen a aumentar timeouts firmados de efectos externos o a relajar otra condición de verificación.

F11 y los archivos de ruleset describen protección del path del workflow contra pushes ordinarios. Esos archivos locales no prueban el estado remoto actual. Si el control efectivo impide publicar esta línea, hay que respetarlo y usar el mantenimiento expresamente permitido por el owner; no cambiar la protección ni buscar otra representación para evitar el rechazo. Una autorización de contenido mecánico no proporciona por sí misma permisos que la plataforma deniega. La documentación exige además registrar el motivo del cambio de workflow conforme a AGENTS/context-routes; esa trazabilidad no es una nueva adopción del bundle.

Tras el cambio, el nuevo head necesita su evaluación completa por los mecanismos requeridos. Este informe no aprueba el merge ni convierte el run actual en success. El aumento puede revelar un fallo posterior genuino; ese fallo habrá que resolver conservando el criterio del juez.

## Alternativa compatible

La alternativa mínima sigue siendo ampliar únicamente este límite y conservar el resto del workflow. Si no existe una vía permitida para mantener el path protegido, mantener el estado bloqueado y solicitar únicamente esa intervención de mantenimiento del owner es compatible; sustituir el juez, omitir claims, aceptar sólo make check o usar un workflow alternativo como autoridad no lo es.

Como opción de ingeniería posterior, se podría reducir tiempo de implementación/setup de fixtures preservando exactamente comandos, aserciones y política, con su propia evidencia de equivalencia y revisión. Es un alcance mayor y no está demostrado que baste. Dividir jobs, cachear resultados de claims o alterar su ejecución cambia más invariantes y no forma parte de esta aprobación acotada.

## Identidad de las lecturas y límites

- Workflow actual SHA-256: `78edb63f69c734f362c6ffd28441a71f50ac7bc7251e04eeaf3e0147815af2b8`.
- Judge-contract raíz y bundle: `c370c0beee8d258b41e418b3bf6601b81d941b6d65a8e83d3f6055f8eeb4d175`.
- Log `pr35-667-cancelled-claims.log`: `487f239ffed62ab2e11182702e5ddcad1ca89c0c010a50271d3ed1c7095ffb74`.

Se leyeron workflow, contrato, manifest, documentación de adopción, oracle protegido, partes relevantes de verify-claims/feature_list/DECISIONS y reglas de arquitectura/protección. Se hicieron comparaciones de texto/hash/modos y del snapshot Git. No se ejecutaron tests, fullcheck, RED, programas del candidato, red ni credenciales; no se modificó el repositorio. Sólo se escribió este informe. No hubo rechazo automático durante esta revisión.
