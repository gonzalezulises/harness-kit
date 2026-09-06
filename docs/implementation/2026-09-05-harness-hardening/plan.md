# Authorization

On 2026-09-05, after the review and MIGRATION-01 decision were presented, the owner instructed: **“Implementa todas las mejoras.”** This authorizes the proposed optional-pack transition and sequential H01–H09 implementation. It does not accept a baseline, deploy a consumer product, or grant access that the environment does not have. The original review remains immutable history at commit `9ee4eaaf6b19ded4b5e32349d77ba8fdaf6af79e`.

The historical implementation-stop text below is resolved by this authorization. Active task state and rulings live in `ledger.md`.

# Harness Hardening — approved implementation

> Historical design context: ejecutar secuencialmente con `superpowers:executing-plans`; revisión independiente mediante `superpowers:requesting-code-review`. No iniciar implementación hasta resolver MIGRATION-01. Las pruebas RED adjuntas son evidencia del diagnóstico, no un permiso para ampliar autonomía.

**Goal:** reducir intervenciones por operaciones mecánicas sin que una implementación errónea pueda ganar autoridad mediante tests verdes.

**Architecture:** reparar verificadores legacy; añadir un pack local opt-in con autoridad, identidad y replay verificables; conectar remediación, reviewer y objetivo de release sobre ese núcleo.

**Tech stack:** legacy Bash 3.2/Python; pack propuesto Node, parser YAML 1.2 y Zod con lockfile. Sin daemon, base de datos, proveedor adicional ni dependencia obligatoria de CI.

**Spec:** [architecture.md](../../reviews/2026-09-05-harness-hardening/architecture.md). **Requirements:** [requirements-original.md](../../reviews/2026-09-05-harness-hardening/requirements-original.md).

## Restricciones globales

- WIP=1, `make check` antes de cada commit, contexto gobernante `AGENTS.md` y `DECISIONS.md`.
- No asignar `passing` manualmente. La evolución mantiene un recibo verificable como única vía.
- Cada High/Critical: RED observable antes del fix; revisión independiente sin High/Critical antes del milestone siguiente.
- No regenerar hashes normativos, aceptar goldens/baselines ni otorgar permisos de deploy como efecto secundario.
- Root/template de scripts existentes se mantienen sincronizados. El nuevo pack tiene una sola fuente y una prueba de instalación real.
- No importar permisos ni reglas de producto de Aurobalance/Casabat. No reescribir los catorce claims históricos.
- Los budgets se toman de autoridad aprobada. Los máximos no se inventan durante una reparación.
- La matriz completa se ejecuta una vez integrada; pruebas focales por cambio. Repeticiones adicionales sólo para resolver riesgo concreto de concurrencia/tiempo.

## Orden y gates

`H01 → H02 → H03 → H04 → H05 → H06 → H07 → H08 → H09`.
H01/H02 reparan garantías existentes. H03–H08 construyen capacidades opt-in. H09 prueba adopción, integra y prepara baseline para aceptación humana. La finalización de un milestone no es un stop humano; sí lo es una nueva decisión normativa o una incompatibilidad no cubierta por MIGRATION-01.

Los paths de módulos v2 siguientes son propuestos; los existentes citados en H01/H02 son verificables en la base auditada. No se presentan como código implementado.

## Task 1 — H01 — Fallar cuando faltan contrato, autoridad o ejecución

**Goal/riesgo:** cerrar R01–R09 y R13 antes de ampliar permisos. Evitar falsos verdes y ejecución del campo repair.

**Files:** `scripts/{verify-feature,verify-claims,verify-decisions,check-arch}.sh` y sus espejos `templates/full/scripts/`; `tests/run-tests.sh`; nuevas regresiones focales extraídas de esta revisión; Agent Note de bug-fix.

**Interfaces:** conservar CLI y códigos de éxito; errors de configuración/autoridad se traducen a estados del registry sin cambiar el significado de PASS. No aceptar nuevos flags de bypass.

- [ ] Ejecutar primero las regresiones independientes y el complemento local. Crear cada directorio con `mktemp -d`, pasarlo como `--output` y conservar output, exit, SHA del test y del script. Ejemplo reproducible:

  ```bash
  review_evidence_dir="$(mktemp -d)"
  python3 docs/reviews/2026-09-05-harness-hardening/red_regressions.py --repo . --output "$review_evidence_dir"
  local_evidence_dir="$(mktemp -d)"
  python3 docs/reviews/2026-09-05-harness-hardening/local_red_regressions.py --repo . --output "$local_evidence_dir"
  state_evidence_dir="$(mktemp -d)"
  python3 docs/reviews/2026-09-05-harness-hardening/supplemental_state_red.py --repo . --output "$state_evidence_dir"
  ```
- [ ] Validar JSON completo antes de emitir registros o ejecutar capas: objeto raíz, arrays/objetos correctos, IDs únicos, estados conocidos, comandos no vacíos, límites enteros válidos. Capturar y propagar el exit de cada parser.
- [ ] Sustituir framing TSV de comandos por registros inequívocos que preserven campos vacíos y multiline. El texto de reparación nunca entra al canal de ejecución.
- [ ] Validar active/WIP/budget antes de la primera capa. `blocked` y presupuesto agotado rechazan antes de cualquier efecto. Guardar intentos previos; una recuperación necesita un grant verificable, no editar `state`.
- [ ] Validar base explícita. Una base ilegible no equivale a ausencia comprobada de ledger. Distinguir repo nuevo documentado de fallo al leer Git.
- [ ] Invalidar cache de claims cuando cambia cualquiera de sus inputs declarados; hasta que esos inputs sean verificables, no reutilizar resultados de comandos arbitrarios. No afirmar pureza por igualdad de texto.
- [ ] Comparar decisiones preservando whitespace semántico de código, tablas y texto. Supersesión append-only; el formateo sólo se considera mecánico bajo un parser de documento definido.
- [ ] Propagar rc real de reglas `exit0`; parser de reglas inválido bloquea. Mantener explícita la diferencia entre grep sin matches y fallo de herramienta.
- [ ] Ejecutar regresiones focales GREEN, suite existente, `make gates`, `make check`, revisión independiente y commit atómico por defecto cerrado.

**Compatibilidad:** se endurecen inputs que antes generaban falsos verdes; los repos con datos inválidos reciben diagnóstico y no migración silenciosa. Hacer inventario de capas multiline/duplicados antes de rollout.

**Rollback:** revertir commits H01 preservando logs/recibos; no reabrir autonomía mientras el rollback restaure un bypass conocido. Un rollback de código no constituye aprobación de ese riesgo.

**PASS:** todos los High reproducidos pasan a rechazo correcto; nunca se ejecuta repair; no se reactiva un bloqueo; comandos válidos siguen pasando; ninguna prueba previa se elimina o se skippea.

## Task 2 — H02 — Aplicación real de gates y estabilidad de infraestructura

**Goal/riesgo:** cerrar R10–R12 y fricciones operacionales de R14–R22; impedir que tests del gate sustituyan el gate sobre el repo.

**Files:** `Makefile`, `scripts/run-gates.sh`, `bin/harness-init.sh`, `scripts/pre-commit-staged.sh`, `scripts/verify-{context-routes,oracles,delivery-doc,version-sync}.sh`, `bin/harness-status.sh`, `tests/run-tests.sh`, `packs/load-testing/verify-pack.sh`, `packs/load-testing/repo-template/bin/perf-resolve-target`, plantillas equivalentes; propuesta de cambios al workflow requerido en PR explícito.

- [ ] RED: full scaffold configurado tiene siete quick PASS y version-sync ausente; cambio de sólo repair bloquea; formatter no cero no bloquea; staging parcial captura cambios adicionales; dos suites comparten backup; consulta statuses falla y se lee como sin preview.
- [ ] Declarar aplicabilidad de cada gate en un perfil de instalación versionado y gobernado por base: gates del kit no se exigen indiscriminadamente a consumidores; gates universales sí se instalan y se exigen. No usar «optional» para ocultar una instalación rota.
- [ ] Hacer que la verificación integrada ejecute el registro quick sobre configuración viva sin recursión `full → make check → full`. En CI, juez/política desde base y target head separados; recuperar historia que requieran oracles/context sin usar una base implícita inválida.
- [ ] Separar identidad de la verificación (`cmd`, inputs, entorno) de guía de reparación; conservar comparación estricta de comandos. No usar una whitelist de strings benignos para aprobar cambios de contrato.
- [ ] Mover backup bajo el `$WORK` exclusivo; servidores con puerto asignado por OS y readiness bounded, no sleep fijo; cleanup sólo de procesos propios. Preservar asserts, cobertura y expectativas.
- [ ] Hook: preservar índice parcial; fallo del formatter bloquea. El diagnóstico identifica cómo repetir la reparación mecánica sin alterar el significado del commit.
- [ ] Actualizar lecturas de workspace para contexto/oracles y documentación de capacidades/estado; clasificar fallos de API como indeterminados, no como ausencia.
- [ ] GREEN: scaffold completo, concurrencia real de dos suites, timeout controlado bajo carga y gates vivos. Revisión y commit.

**Compatibilidad:** perfil explícito por tipo de instalación; paths/customizaciones se conservan. El caso de timeout histórico Aurobalance necesita su fixture original si se desea reproducir idéntica causalidad; la nueva prueba aquí se etiqueta como prueba de contención del kit.

**Rollback:** revertir perfil/runner juntos; conservar config anterior con hash y evidencia. No omitir gates requeridos por una política ya aprobada.

**PASS:** instalación consistente; ninguna regla requerida ausente; pruebas de contención y aislamiento pasan en suite; CI no sustituye la política viva por una suite de fixtures.

## Task 3 — H03 — Identidad y clasificación determinista

**Goal/riesgo:** satisfacer canonical YAML, derived SHA y anti-bypass sin normalizar significado.

**Files propuestos:** `packs/autonomy/{package.json,package-lock.json,index.md,verify-pack.sh}`, `repo-template/scripts/quality-orchestrator/{identity,classify,authority}.mjs`, `schemas/*.json`, `tests/identity.test.mjs`, `tests/classify.test.mjs`.

**API:** `identify(bytes, schemaBinding)` produce triple identidad y AST tipado; `classifyChange(request, verifiedContext)` produce clases/disposición/pruebas. Sin writes de producto.

- [ ] RED: reorden YAML igual; 100→99.9 desigual; campo renombrado desigual; whitespace humano desigual; enum distinto desigual; tipos boolean/número/string distintos; duplicate keys/tags/aliases rechazados; batch mixto bloqueado.
- [ ] Fijar parser YAML 1.2, Zod y lockfile; normalizador versionado. `verifiedContext` se construye desde archivos/objetos verificados, no booleanos del agente.
- [ ] Implementar identidad tipada completa y reglas de derivación cerradas; archivo/schema/policy desconocido devuelve UNKNOWN.
- [ ] GREEN unit/integration y revisión independiente de bypass. Ninguna clasificación concede permisos por sí sola.

**Compatibilidad:** pack opt-in, no dependencia nueva para minimal/full legacy. **Rollback:** retirar adopción antes de activar un run; preservar todos los objetos si ya existen. **PASS:** casos 1/3/12 de matriz, pruebas por schema hash y ningún false mechanical en adversariales.

## Task 4 — H04 — Journal, replay y migración de evidencia

**Goal/riesgo:** estado verificable y reemplazo de run stale sin reescribir historial.

**Files propuestos:** módulos `journal.mjs`, `runs.mjs`, `migration.mjs`, schemas `event`, `run`, `witness`; tests `journal`, `replay`, `crash`, `migration`.

**API:** `appendEvent(expectedHead, operation)` → recibo; `replay(journal, checkpoint)` → observed state; `replaceStaleRun(oldRun, finalBinding)` → nuevo run ligado por linaje.

- [ ] RED: byte alterado, evento omitido/reordenado, tail parcial, operación repetida con distintos inputs, crash después de write y antes de index, run terminal preservado, semantic bindings distintos rechazados.
- [ ] Implementar append exclusivo/content-addressed, secuencia/hash chain, CAS de head y replay estricto. Checkpoint/testigo confiable obligatorio para la garantía fuerte.
- [ ] Importar v1 sin borrar bytes: `LEGACY_UNVERIFIED`; nunca fabricar RED/approval/PASS. Estado v2 proyectado al formato de lectura legacy con procedencia explícita.
- [ ] Implementar fresh run y revalidación completa del commit final. Propagar presupuesto de objetivo y revocaciones.
- [ ] GREEN con crash-injection y replays repetidos idénticos; revisión y commit.

**Compatibilidad:** sólo modo adoptado en MIGRATION-01; readers legacy conservados, writers directos bloqueados en v2. **Rollback:** conmutar a snapshot v1 preservado, mantener journals para consulta; ningún PASS v2 se traduce por simple edición. **PASS:** casos 2/3, no overwrite, no resets por fresh run, replay determinista y adopción reversible.

## Task 5 — H05 — Capabilities y contención de efectos

**Goal/riesgo:** que autorización mecánica no conceda un shell genérico ni acceso fuera de scope.

**Files propuestos:** `workspace.mjs`, `lease.mjs`, `commands.mjs`; fixtures de symlink/hardlink, procesos hijos, contención y manifests.

**API:** `acquireLease(runBinding)` → fencing token; `executeCapability(id, typedArgs, token)` → pre/post manifests y resultado supervisado.

- [ ] RED: denylist gana a allowlist; path traversal/symlink/hardlink; token stale; dos writers; proceso huérfano; command/script cambiado tras binding; output desbordado; test que muta región congelada.
- [ ] Implementar argv sin shell, allowlist exacta, inputs/output content-addressed, env acotado, supervisión del grupo de procesos y fencing. Revalidar paths al usar, no sólo al planear.
- [ ] Permitir sólo la mutación derivada que recomputó la capability; cualquier delta extra clasifica POLICY.
- [ ] GREEN: contención bajo full suite, cleanup propio, congelación íntegra; revisión y commit.

**Compatibilidad:** los comandos v1 con shell siguen identificados como legacy; no se convierten automáticamente en capabilities. **Rollback:** suspender nuevas operaciones y terminar/recuperar lease antes de volver a v1. **PASS:** casos 5/6 y matriz adversarial de filesystem/lease sin escapes.

## Task 6 — H06 — Continuación acotada y presupuestos

**Goal/riesgo:** reutilizar decisiones humanas sin inventar semántica ni loops infinitos.

**Files propuestos:** `continuation.mjs`, `budget.mjs`; schemas `human-gate`, `remediation-grant`; tests correspondientes.

**API:** `evaluateContinuation(grant, observedDefect, verifiedContext)` y `spendBudget(kind, objectiveId, operationKey)`; los contadores se derivan del journal.

- [ ] RED: mismo defecto/AC/regla permite siguiente round; cambio de autoridad/scope/threat/arquitectura bloquea; grant expirado/revocado bloquea; new golden no hereda approval de bytes; regression falta; rebind no resetea budget.
- [ ] Grant de acciones acotadas separado de aceptación de artefacto. Comprobar regresión durable y gate de expectativas/cobertura sin aceptar booleans del implementador.
- [ ] Tres budgets más límite total; keys idempotentes; agotamiento no revive al crear otro run.
- [ ] GREEN casos 4/10, intentos y revocaciones en replay; revisión y commit.

**Compatibilidad:** approvals v1 sin continuación no ganan permisos nuevos. **Rollback:** revocar grants futuros por evento, preservar aprobaciones originales y bytes. **PASS:** no nueva consulta para corrección cubierta, gate inmediato ante nueva semántica.

## Task 7 — H07 — Adapter Codex y revisión independiente

**Goal/riesgo:** eliminar acoplamientos operacionales sin debilitar aislamiento o cambiar modelo.

**Files propuestos:** `review/{preflight,codex,shadow,output}.mjs`; `review.schema.mjs` con Zod; fixtures y pruebas contractuales del adapter.

**API:** `preflightReview(approvedAdapterPolicy)` → binding congelado; `reviewRun(binding, shadow)` → salida no confiable y recibos; `validateReview(raw, binding)` → findings estructurados.

- [ ] RED: config global incompatible no contamina config aislada; auth mode distinto bloquea; binary/model/schema cambiados entre rounds bloquean; Git shadow no confiable bloquea; JSON Schema remoto no soportado habilita sólo validación local equivalente; output malformed/extra/cancelado bloquea.
- [ ] Descubrir capabilities/modelos, aplicar orden de capacidad aprobado, congelar binding. Un catálogo no es ranking semántico; no elegir modelo por nombre lexicográfico.
- [ ] Construir shadow Git exacto sin hooks/credenciales heredadas; proceso/session read-only con egress/MCP acotados. No editar home global ni saltar trust check.
- [ ] Reproducir contraejemplos en shadow y convertirlos en regresión. Green tests no sustituye contrato.
- [ ] GREEN casos 7/8/9 y una sesión real contra la versión fijada de Codex. Pruebas simuladas por sí solas no autorizan adapter.

**Compatibilidad:** opt-in OpenAI/ChatGPT/Codex, sin marketplace. **Rollback:** conservar run y sus bindings; desactivar adapter nuevo, nunca cambiarlo a mitad de run. **PASS:** proceso independiente real, primary manifest sin delta, output validado localmente y sin High/Critical pendientes.

## Task 8 — H08 — Objetivo de release y certificación

**Goal/riesgo:** continuar hasta el objetivo explícito, impedir PR/preview verdes interpretados como producción certificada.

**Files propuestos:** `release.mjs`, schemas `release-objective`, `deployment-receipt`; adapters cerrados al tipo de target aprobado; tests release/resume/postdeploy.

**API:** `nextObligation(objective, replayState)` → acción tipada o parada; `certifyRelease(objective, verifiedReceipts)` → estado, nunca un booleano suministrado por LLM.

- [ ] RED: slice PASS con deploy pendiente continúa; PR merged exige revalidación del commit integrado; deployment A no puede consumir smoke de B; approval de otro artifact no aplica; crash/resume no duplica deploy; rollback invalida objetivo presente sin borrar historia.
- [ ] Derivar estados por obligaciones. Deployment bajo permiso explícito y gate externo si existe; recertificar después de remediar.
- [ ] GREEN caso 11, smoke funcional y observabilidad independientes, integración con grants y budgets; revisión y commit.

**Compatibilidad:** Release Please permanece gestor de versiones; no recibe facultad de desplegar productos. **Rollback:** volver al deployment anterior sólo bajo capability autorizada y emitir nuevo recibo. **PASS:** `PRODUCTION_PASS` exige todas las obligaciones presentes y vigentes; preview nunca satisface producción.

## Task 9 — H09 — Canario de migración, entrega y baseline humana

**Goal/riesgo:** comprobar utilidad real y evitar una nueva carpeta de políticas no operativas.

**Files:** instalador/status y docs de adopción; evidence canary; Agent Notes; feature_list/PROGRESS actualizados por rutas verificadas.

- [ ] RED de extremo a extremo: YAML normal → canonical → RED → cambio de commit → fresh run → verificación/review → defecto acotado → nueva evidencia → next slice → release/certificación. Intercalar threshold alterado y comprobar gate humano inmediato.
- [ ] Ejecutar en consumidor canario autorizado, con baseline v1 preservada y rollback probado. Contar intervenciones humanas por reason code y tiempo de recuperación; no perseguir un número arbitrario de bloqueos cero.
- [ ] Comparar alcance, falsos PASS, falsos bloqueos, idempotencia, frescura y todos los casos históricos. No dar PASS a pruebas omitidas por permisos o capacidad.
- [ ] Integrar cambios compatibles tras gates/revisión; preparar bundle de baseline final con SHA exacto y pedir su aceptación humana una vez.

**Compatibilidad:** rollout por adopción, sin `--force` masivo. **Rollback:** probado en el canario; preservar todas las evidencias v1/v2. **PASS:** caso real completo; cero High/Critical sin resolver; baseline presentada al owner y aceptación explícita antes de promoverla a autoridad.
