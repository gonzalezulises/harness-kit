# Problemas reales observados

Durante la ejecución de Aurobalance aparecieron bloqueos como:

## 1. Canonical serialization

Un `scope.yaml` era semánticamente correcto pero M03 exigía bytes canónicos.

La única corrección necesaria era:

```
```

```
parse
→ canonical serialize
→ recompute SHA
→ rebind desired state
→ preserve old run
→ create fresh run
```

Sin cambio semántico.

Sin embargo, el agente se detuvo porque cambiar hashes/bindings requería aprobación humana.

Esto es demasiada fricción.

---

## 2. Stale evidence / commit binding

Un run había capturado el workspace antes del commit final.

La implementación era correcta, pero el journal estaba ligado a un manifest anterior.

La solución correcta era mecánica:

```
```

```
old run → append-only REJECTED
preserve receipts
fresh M02 run
same authority
same scope
same AC
same threat model
bind final commit
replay
```

Esto tampoco debería requerir nueva decisión humana cuando se demuestra igualdad semántica.

---

## 3. Repeated golden remediation approvals

Una persona revisó un golden y pidió correcciones acotadas.

El agente implementó las correcciones, pero luego volvió a detenerse porque la autorización inicial no cubría formalmente otra remediación versionada.

Necesitamos una política de:

> bounded remediation autonomy

Si la corrección mantiene:

-  mismo AC; 
-  misma autoridad; 
-  mismo threat model; 
-  mismo scope semántico; 
-  misma clase de defecto; 

el agente debe poder continuar sin pedir permiso repetidamente.

---

## 4. Harness-only instability

Tests de infraestructura fallaron por:

-  contention; 
-  timeout; 
-  fixture cleanup; 
-  process timing; 
-  suite-wide interference; 

aunque el test focal pasaba.

El sistema exigió nueva aprobación para estabilizar la propia infraestructura de test.

Necesitamos una categoría explícita:

```
```

```
HARNESS_MECHANICAL_REMEDIATION
```

que pueda corregirse automáticamente cuando:

-  no cambia el claim; 
-  no reduce cobertura; 
-  no debilita expectativas; 
-  no cambia threat model; 
-  no altera producto. 

---

## 5. Adapter operational couplings

En M04 aparecieron problemas como:

-  config global incompatible; 
-  necesidad de `CODEX_HOME` aislado; 
-  modelo hardcoded incompatible; 
-  JSON Schema no soportado; 
-  shadow sin `.git`; 
-  trusted repo requirement. 

Todos fueron problemas operacionales, no semánticos.

El harness debe representar explícitamente:

```
```

```
adapter capability
adapter compatibility
adapter environment isolation
adapter model binding
schema compatibility
trusted workspace construction
```

y permitir remediation preautorizada dentro de ese dominio.

---

# Objetivo principal

Rediseñar/evolucionar el harness para que un agente pueda ejecutar:

```
```

```
requirements
→ authority
→ decisions
→ acceptance criteria
→ RED
→ implementation
→ verification
→ independent review
→ remediation
→ release integration
→ deployment
→ post-deploy certification
```

con la menor intervención humana razonable.

El humano debe aparecer principalmente cuando existe:

1.  nueva decisión normativa; 
2.  conflicto de autoridad; 
3.  significado de dominio indefinido; 
4.  cambio material de scope/shared semantics; 
5.  cambio arquitectónico importante; 
6.  riesgo relevante de seguridad/datos; 
7.  aceptación humana explícita de contenido donde sea realmente necesaria; 
8.  producción cuando exista un gate externo realmente humano; 
9.  baseline final. 

No por housekeeping técnico.

---

# Requisito crítico: Semantic vs Mechanical Change Classifier

Diseña una capa explícita que clasifique toda modificación solicitada.

Debe producir algo equivalente a:

```
```

```
change_class:
  one_of:
    - SEMANTIC
    - ARCHITECTURAL
    - SECURITY_RELEVANT
    - SHARED_SEMANTICS
    - MECHANICAL_CANONICALIZATION
    - DERIVED_BINDING_UPDATE
    - EVIDENCE_REFRESH
    - STALE_RUN_REPLACEMENT
    - HARNESS_STABILITY
    - BOUNDED_REMEDIATION
    - DOCUMENTATION_ONLY
```

Para cada clase debe existir una política de autonomía.

---

# Política deseada de autonomía

## Debe poder hacerse automáticamente

### Canonicalization

Ejemplo:

```
```

```
YAML semantically equal
→ canonical representation
→ recompute hash
→ update derived bindings
```

Solo si:

```
```

```
parse(old) == parse(new)
```

o la equivalencia definida por el schema se demuestra determinísticamente.

---

### Derived hash / binding updates

Si cambia un artefacto únicamente como consecuencia determinística de una transformación previamente autorizada:

```
```

```
artifact
→ sha256
→ lock
→ desired binding
→ receipt
```

el sistema debe poder actualizar los derivados.

No debe tratar un hash derivado como una decisión normativa.

---

### Fresh run replacement

Permitir automáticamente:

```
```

```
old run preserved
→ append-only terminal classification
→ fresh run
```

cuando:

-  authority identical; 
-  scope semantic hash identical; 
-  AC identical; 
-  threat model identical; 
-  architecture binding identical; 
-  only workspace/commit/evidence freshness changed. 

Nunca reescribir el run anterior.

---

### Bounded remediation

Permitir remediation automática si:

```
```

```
same AC
AND same defect class
AND same violated rule
AND same threat model
AND same scope semantics
AND no new authority
AND no architecture expansion
```

El counterexample debe convertirse en regression durable.

---

### Harness stability fixes

Permitir:

-  timeout local; 
-  race fix; 
-  fixture isolation; 
-  cleanup; 
-  deterministic scheduling; 
-  resource contention fixes; 

si:

-  expectation no cambia; 
-  coverage no disminuye; 
-  test no se skippea; 
-  claim no cambia; 
-  threat model no cambia. 

---

### Documentation/evidence updates

Permitir append-only:

-  PROGRESS; 
-  Agent Notes; 
-  evidence; 
-  receipts; 
-  hashes; 
-  review records; 

sin detener ejecución.

---

# Debe seguir requiriendo humano

Nunca autoautorizar:

-  nuevo significado clínico/domain semantics; 
-  cambio de fórmula; 
-  cambio de threshold; 
-  cambio de peso; 
-  cambio de scoring; 
-  nuevo authority source; 
-  precedence entre authorities conflictivas; 
-  ampliación material de scope; 
-  cambio de threat model; 
-  nueva arquitectura no prevista; 
-  final baseline acceptance; 
-  contenido human-facing que explícitamente requiera sign-off humano. 

---

# Human Gate Continuation

Un gate humano aprobado debe incluir también política de continuación.

Ejemplo:

```
```

```
human_gate:
  artifact_sha256: ...
  approved: true
  allowed_follow_up:
    bounded_remediation: true
    regenerate_golden: true
    rerun_review: true
    continue_to_next_slice: true
```

Una vez aprobada una corrección específica, el agente no debe pedir aprobación otra vez por el mismo defecto si:

-  no introduce semántica nueva; 
-  no cambia la autoridad; 
-  no cambia el AC; 
-  no cambia el scope. 

---

# Release Objective

El harness debe soportar objetivos de release, no solo tasks/slices.

Ejemplo:

```
```

```
release:
  id: RELEASE-1
  components:
    - OligoCheck
    - NeuralCheck
    - Chakra
    - Integrativo
    - BioWell
    - InBody

  done_when:
    - all required slices passed
    - integrated branch green
    - required human gates complete
    - deployed_to_production
    - production_smoke_passed
```

El agente no debe detenerse porque:

```
```

```
slice PASS
PR merged
preview PASS
```

si el objetivo explícito es:

```
```

```
RELEASE-1 = PRODUCTION_PASS
```

---

# Mechanical Rebind Policy

Diseña una política reusable equivalente a:

```
```

```
mechanical_rebind:
  autonomous: true

  permitted:
    - canonical_serialization
    - recompute_derived_sha256
    - refresh_manifest
    - refresh_receipt
    - rebind_desired_state
    - replace_stale_run
    - replay_same_scope

  invariants:
    authority_same: true
    acceptance_criteria_same: true
    scope_semantics_same: true
    threat_model_same: true
    architecture_same: true
    product_behavior_same: true

  historical_evidence:
    preserve_append_only: true
```

---

# Stable Semantic Identity

No uses solo SHA de bytes para determinar identidad semántica.

Considera introducir:

```
```

```
content_sha256
semantic_sha256
canonical_sha256
```

Por ejemplo:

```
```

```
scope:
  content_sha256: hash(raw_bytes)
  canonical_sha256: hash(canonical_serialization)
  semantic_sha256: hash(canonical_parsed_representation)
```

Analiza cuidadosamente si esto mejora el diseño.

No lo implementes automáticamente si introduce nuevos bypasses.

Quiero que determines cuál debe gobernar:

-  integrity; 
-  semantic identity; 
-  reproducibility; 
-  historical evidence. 

---

# Desired State / Observed State

Mantener la propiedad:

```
```

```
observed_state = verified journal replay
```

Pero evitar que cambios mecánicos obliguen a intervención humana innecesaria.

Analiza cómo modelar:

```
```

```
desired_semantics
desired_representation
desired_binding
```

por separado.

---

# Append-only evidence

Conservar:

-  no overwrite; 
-  no history rewrite; 
-  content addressing; 
-  witnesses; 
-  operation keys; 
-  replay; 
-  idempotency. 

Nunca solucionar fricción sacrificando auditabilidad.

---

# Workspace Guards

Conservar o mejorar:

-  exact allowlists; 
-  denylist precedence; 
-  frozen regions; 
-  symlink/path containment; 
-  WIP=1; 
-  mutation lease; 
-  pre/post manifests; 
-  subprocess supervision; 
-  stale workspace detection. 

Pero distinguir:

```
```

```
unexpected semantic change
```

de:

```
```

```
expected derived workspace mutation
```

---

# Independent Review

Mantener:

-  independent actor/session/process; 
-  read-only reviewer; 
-  fixed OpenAI/ChatGPT-only adapter policy if applicable; 
-  deterministic probes; 
-  reviewer output treated as untrusted; 
-  shadow reproduction; 
-  durable counterexamples; 
-  green tests != contract PASS. 

Mejorar la integración para evitar que problemas del adapter detengan innecesariamente todo el pipeline.

---

# Reviewer Model Policy

No diseñar un marketplace de modelos.

Preferencia:

```
```

```
provider: OpenAI
auth: ChatGPT account
execution: Codex
model: highest-capability compatible model
```

Resolver modelo al inicio del review run y congelarlo para ese run.

No permitir cambio silencioso entre rounds.

---

# Testing strategy

Quiero TDD real.

Antes de implementar mejoras, crea RED tests que reproduzcan al menos:

1.  canonical YAML semantic-equal rebind; 
2.  stale workspace run replacement; 
3.  derived SHA refresh; 
4.  bounded remediation continuation; 
5.  harness timeout under full suite; 
6.  concurrent fixture interference; 
7.  reviewer adapter config isolation; 
8.  schema compatibility fallback-to-local-Zod; 
9.  trusted Git shadow; 
10.  human gate continuation; 
11.  release objective continuity; 
12.  prevention of semantic bypass disguised as mechanical change. 

---

# Critical adversarial test

Intenta engañar al mechanical classifier.

Ejemplos:

```
```

```
threshold 100 → 99.9
```

NO debe clasificarse como canonicalization.

```
```

```
rename field + same value
```

puede o no ser mecánico dependiendo del schema.

```
```

```
reorder YAML keys
```

sí puede ser mecánico.

```
```

```
normalize whitespace inside human-facing text
```

puede cambiar significado / golden y debe analizarse.

```
```

```
change enum label while keeping numeric code
```

debe considerarse semantic unless explicitly declared alias-equivalent.

El sistema debe fail-closed si no puede demostrar equivalencia.

---

# Authority model

Introduce o mejora una representación explícita:

```
```

```
authority_binding:
  source:
  version:
  sha256:
  precedence:
  semantic_role:
```

Los artefactos derivados nunca deben convertirse accidentalmente en authority.

---

# Stop taxonomy

Actualmente demasiadas cosas terminan como:

```
```

```
BLOCKED_BY_UNEXPECTED_COUPLING
```

Quiero una taxonomía más útil.

Propón algo como:

```
```

```
BLOCKED_BY_NEW_NORMATIVE_DECISION
BLOCKED_BY_AUTHORITY_CONFLICT
BLOCKED_BY_UNDEFINED_DOMAIN_MEANING
BLOCKED_BY_ARCHITECTURE_CHANGE
BLOCKED_BY_SECURITY_RISK
BLOCKED_BY_SHARED_SEMANTICS_CHANGE

AUTO_REMEDIABLE_CANONICALIZATION
AUTO_REMEDIABLE_DERIVED_BINDING
AUTO_REMEDIABLE_STALE_EVIDENCE
AUTO_REMEDIABLE_HARNESS_STABILITY
AUTO_REMEDIABLE_BOUNDED_DEFECT
```

Evalúa y mejora esta taxonomía.

---

# Review budget

Mantener review budget para evitar loops infinitos.

Pero diferenciar:

```
```

```
product semantic review
harness implementation review
mechanical remediation verification
```

Una canonicalization no debería consumir el mismo presupuesto que una revisión semántica.

---

# Deliverables

Primero realiza una auditoría completa del repo.

Entrega:

## 1. Current architecture map

-  componentes; 
-  state flow; 
-  authority flow; 
-  evidence flow; 
-  execution flow; 
-  review flow; 
-  release flow. 

## 2. Friction analysis

Identifica todos los puntos donde el harness puede detener agentes innecesariamente.

Clasifica:

```
```

```
necessary safety stop
unnecessary governance friction
architecture debt
test debt
operational coupling
```

## 3. Gap analysis

Compara el repo actual contra los requisitos de este documento.

## 4. Proposed architecture

No reinventes el sistema si puede evolucionarse incrementalmente.

## 5. Migration plan

Por milestones pequeños:

```
```

```
H01
H02
H03
...
```

Cada milestone debe tener:

-  goal; 
-  risk reduced; 
-  files; 
-  RED tests; 
-  implementation; 
-  migration compatibility; 
-  rollback; 
-  PASS criteria. 

## 6. Autonomy policy

Entregar YAML versionado.

## 7. Mechanical-change policy

Entregar YAML/schema.

## 8. Release execution policy

Entregar YAML/schema.

## 9. Stop taxonomy

Entregar definición formal.

## 10. Test matrix

Incluye los casos históricos anteriores.

---

# Ejecución

Después de producir la auditoría y el plan:

Si encuentras contradicciones importantes o riesgo de romper compatibilidad:

```
```

```
HARNESS_REVIEW_BLOCKED
```

y explica la decisión humana mínima requerida.

Si el diseño puede evolucionarse sin cambiar principios fundamentales:

continúa implementando milestones secuencialmente.

No detenerse después de cada milestone si:

-  tests verdes; 
-  no Critical/High; 
-  no cambio normativo; 
-  siguiente milestone sigue dentro de este mandato. 

---

# Reglas de implementación

-  No reescribir el harness desde cero salvo evidencia extraordinaria. 
-  No introducir servicios externos innecesarios. 
-  No hacer CI obligatorio para lógica que debe funcionar localmente. 
-  No esconder decisiones en prompts. 
-  Preferir schemas + deterministic runtime. 
-  No tratar LLM output como autoridad. 
-  No autoaprobar baselines. 
-  No debilitar existing fail-closed controls. 
-  Cada bypass reproducido debe convertirse en regression test. 
-  Cada remediation Critical/High debe observar RED antes del fix. 
-  Medium/Low pueden quedar en backlog. 
-  Evitar regex whack-a-mole cuando una restricción estructural sea mejor. 
-  Preferir capabilities cerradas sobre interfaces genéricas. 
-  Evitar arbitrary shell. 
-  Mantener `shell: false` donde sea posible. 
-  Conservar immutable/append-only audit trail. 

---

# Success Criteria

Consideraré exitosa la evolución del harness si puede completar un flujo real como:

```
```

```
scope authored in normal YAML
↓
canonicalized automatically
↓
semantic identity proven
↓
desired state bound
↓
RED
↓
implementation
↓
workspace commit changes
↓
fresh rebind automatically
↓
verification
↓
independent review
↓
bounded remediation
↓
new golden
↓
existing human decision reused when applicable
↓
next slice
↓
release integration
↓
production
↓
post-deploy certification
```

sin detener al humano por transformaciones mecánicas, pero deteniéndose de inmediato ante una nueva decisión real de producto o riesgo material.

---

# Final instruction

No optimices para “menos bloqueos” de forma aislada.

Optimiza para:

> **menos bloqueos humanos innecesarios sin reducir la capacidad del harness de detectar que el producto equivocado está pasando tests verdes.**

Ese es el objetivo central.

```
```

```

Este prompt tiene una ventaja importante: le da a Astra **los defectos reales que descubrimos usando el harness en producción de desarrollo**, no una lista teórica de features.

Yo además le pasaría, si están disponibles en el repo del harness, los diseños de M01–M04 como material de referencia, porque ahí ya probaste varias ideas que funcionan: journal replay, WIP=1, frozen regions, reviewer independiente, shadow reproduction, etc. Así Astra puede **absorber lo bueno y corregir la fricción**, en lugar de empezar otra arquitectura desde cero.
```