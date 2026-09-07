# CG-L1 follow-up independiente

Fecha: 2026-09-07. Worktree `/workspace/scratch/adce1c53b293/closure-dependencies`. HEAD leído `6677e9978dfd9fa344186a65adddcadabd21cc7e`; MERGE_HEAD `b567669fcd41c40caa8235e758a0f1fdca9a00a5`.

**Spec PASS; calidad PASS para este follow-up. CG-L1 cerrado. Hallazgos abiertos del ajuste consumer Git lifetime: 0 High, 0 Medium, 0 Low.** La observación original y sus límites permanecen en `consumer-git-lifetime-review.md`; este informe actualiza únicamente su estado después de la corrección.

Comparé el test actual contra la copia exacta de la primera renovación. La única diferencia adicional es que el `git commit` directo dentro de `test_head_change_after_prepare_blocks_selector_effect` incorpora `-c maintenance.autoDetach=false -c gc.autoDetach=false`. Conserva el target, commit vacío, comprobación de retorno, mutación intencional de HEAD y aserciones de rechazo antes del selector. Así cierra la excepción al helper que motivó CG-L1. El manager conserva sus bytes aprobados.

El recibo GREEN del follow-up vincula el hash final del test y sus tres logs, cuyos hashes comprobé. El log contiene seis casos aprobados: dos lifecycle, drift de HEAD, aprobación y los dos E2E. Revisé esa evidencia retenida; no ejecuté los tests. La observación GREEN del drift verifica que el commit continúa produciendo el cambio esperado y que el manager mantiene su rechazo.

La nueva falsificación en `consumer-git-lifetime/approval-followup/` tiene 34 archivos; todos coinciden con el manifest. Frente a b567669f, las únicas diferencias son el manager con los dos guards originales retirados y el test final. Los bytes del test del snapshot, del worktree y del recibo son idénticos. El manager mutante conserva el hash revisado en la primera ronda. La metadata identifica explícitamente base b567, HEAD controlador 6677, MERGE_HEAD b567 y el cwd real del nuevo snapshot.

El nuevo recibo RED tiene exactamente las seis claves esperadas y todas las referencias de test, source y logs resuelven con sus hashes correctos. Su fallo es `missing approval created an active selection`, con exit 1; no hay error de limpieza ni dependencia sustituyendo esa falsificación. El oráculo apunta al nuevo recibo y mantiene el proved_sha del HEAD controlador real.

El recibo y la metadata de la primera renovación conservan exactamente los hashes previamente revisados. Su manifest de 34 archivos y sus logs siguen coincidiendo; su snapshot retiene el test anterior a CG-L1. La referencia histórica al test previo no se confunde con una validación del nuevo hash: el oráculo vigente usa la renovación nueva.

La primera verificación completa está registrada separadamente como `PASS_WITH_REVIEW_LOW_STILL_OPEN`, vinculada al test anterior `a9487a...`. Comprobé el hash de su log y la separación explícita de alcance. Ese recibo no certifica el test final. El nuevo full check y CI permanecen fuera de esta aprobación acotada. No revisé aquí el cambio de timeout CI 30→60 ni amplío el veredicto a ese cambio.

| Identidad | SHA256 |
|---|---|
| Test final | `ff257fbaa73fd81adbca5030dc73c760d4866dafa0962b4e5ec5fa84e6557804` |
| Manager intacto | `c204ad219c3137157e8edf7721392cb2554c1bc17edd1623f42dbfb96089264c` |
| Manager mutante retenido | `1ed806aa50d271419e9c5f9b84fc45617ba8edfa83e6679905962047e07e3d60` |
| Oráculo actual | `b4c8dea2b68776ad83adefb5bce46f0a78ce84cb04dfb3adf7f8d9132fed88f8` |
| Nuevo approval-red-receipt.json | `5483194d4047c0d17dd0b4568bc36d7aac607498dcabad24d252fc0d55b0cc54` |
| Nuevo approval-reproof-metadata.json | `4f0df2ad90fc16e1718737156c68473e8b0b2ebd3b0ee61ff970c9c9f3c3fe0a` |
| followup-green-receipt.json | `a57c418d93428cc06f7e360a1f80b6046d25835e7d40cbccb8cd20587a5da3cb` |

Revisión solo de código/datos/hashes/logs, sin ejecutar candidato, tests, full check, probes o red, sin editar el repositorio y sin subagentes. Siguen vigentes los límites previos: prueba local Git 2.51.1; causa/interleaving exacto del ENOTEMPTY remoto Git 2.55.0 no demostrado; ningún claim nuevo de main, adopción, piloto o release.
