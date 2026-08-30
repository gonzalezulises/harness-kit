# harness-kit

Sistema para **gobernar cómo la IA construye software**: que no derive, que no entre en
loops improductivos, y que no pueda declarar terminado nada que no haya sido comprobado.

Se activa en cualquier repositorio con un comando y funciona con cualquier agente. Todo lo
que produce es shell, Make y Markdown, así que Codex, Cursor, Claude Code, Windsurf y el CI
leen el mismo contrato. No depende del sistema de plugins de ningún agente.

```bash
cd mi-proyecto
~/GitHub/harness-kit/bin/harness-activate.sh
```

---

## El problema

Un modelo capaz falla en trabajo largo por razones que no tienen que ver con su capacidad:
empieza cada sesión a ciegas, se sale del alcance, y canta victoria antes de que nada se
haya ejecutado. Eso son propiedades **del repositorio**, no del modelo — y por eso se
arreglan en el repositorio.

El sistema cierra cinco modos de falla concretos. Cada uno tiene un mecanismo, y cada
mecanismo tiene un verificador que demuestra que sigue funcionando.

| Falla | Qué la cierra | Cómo se manifiesta |
|---|---|---|
| El agente insiste sin avanzar | **Presupuestos** en `verify-feature.sh` | `BUDGET_EXHAUSTED` (exit 3), la feature pasa a `blocked` |
| Declara `passing` sin comprobar | **`verify-claims.sh`** vuelve a correr las capas | `FALSE_CLAIM` (exit 1) |
| Debilita la compuerta que lo juzga | **Ruleset de integridad** sobre el workflow | El push es rechazado por GitHub |
| Escribe tests que pasan sin probar nada | **`packs/gherkin/`** lee el reporte, no el exit code | `ZERO_EXECUTION` (exit 2) |
| Borra la decisión que le estorbaba | **`verify-decisions.sh`**, ledger append-only | `DECISION_REWRITE_FORBIDDEN` |

La regla que atraviesa todo:

> **Un estado escrito a mano es una afirmación; un estado escrito por el harness es un recibo.**

---

## Los cinco controles, en detalle

### 1. Presupuestos anti-loop

Cada feature declara cuánto esfuerzo tiene disponible:

```json
"budgets": {
  "review_rounds_max": 2,
  "repeated_blocker_max": 3,
  "stop_condition": "Detenerse, registrar el bloqueo en PROGRESS.md y escalar a un humano."
}
```

Cada verificación fallida gasta una ronda, y el gasto lo escribe el script en el `ledger`
de la feature — **nunca a mano**. Al agotarse, la feature pasa a `blocked` y el proceso sale
con un código que el CI puede leer: `3` presupuesto agotado, `4` bloqueo repetido,
`67` declaró presupuesto sin condición de parada. Una corrida verde reinicia el ledger, de
modo que el presupuesto mide el intento actual y no la historia del repositorio.

Una feature con `budgets` pero sin `stop_condition` se rechaza: *"sin presupuesto"* sin una
respuesta definida sólo reinicia el loop.

### 2. Re-verificación de afirmaciones

`verify-feature.sh` es la puerta por la que pasa un agente honesto. `verify-claims.sh` es la
que nadie cruza voluntariamente: trata **todo** `passing` como una afirmación y vuelve a
correr las capas que la sostienen.

En el CI se ejecuta con la copia de la **rama base**, no la del pull request, así que un PR
no puede debilitar el script que lo juzga. Es fail-closed: una afirmación que no se puede
comprobar (sin capas, sin evidencia) es `NOT_VERIFIABLE`, nunca un aprobado. Y cuando no hay
nada que revisar lo dice en voz alta (`NO_CLAIMS`) en vez de pasar en silencio.

### 3. La compuerta que protege su propia definición

Éste es el control menos obvio y el más importante:

> **GitHub cuenta un job saltado por su propia condición como un check requerido EXITOSO.**

Exigir que pase el check llamado *"Required quality"* protege el resultado, pero no la
definición que lo produce: un PR que agregue `if: false` al job se fusiona en verde
pareciendo completamente protegido. Ningún workflow puede defenderse de no ejecutarse, así
que la defensa está fuera, en el límite del push:

- `required-quality-check` — ruleset de rama: hace vinculante la compuerta.
- `required-quality-workflow-integrity` — ruleset de push: rechaza cualquier cambio a la
  ruta del workflow, antes de que exista un PR.

`bin/harness-protect.sh` instala ambos y **los vuelve a leer con un GET**, fallando si no
quedaron `active` con cero bypass actors. Crear un ruleset es una afirmación; leerlo de
vuelta es el recibo.

El workflow además fija cada acción externa a un SHA de 40 hex (un tag se puede reapuntar a
otro código) y exige archivos centinela escritos sólo tras un cero observado, de modo que un
paso saltado, cancelado o nunca ejecutado no puede reportarse como éxito.

### 4. Especificación ejecutable que realmente se ejecuta

El código de salida de Cucumber responde *"¿falló algo?"*, no *"¿corrió algo?"*. Un
directorio `features/` renombrado, un filtro que no coincide con nada, o steps sin conectar
producen **exit 0 con cero escenarios**. Es el mismo modo de falla de k6: un script roto sale
con éxito.

`packs/gherkin/` lee el reporte `messages` y emite su propio veredicto, con `--expect N` como
contador absoluto. `pending` y `skipped` cuentan como fallas: son steps que nunca comprobaron
nada.

### 5. Ledger de decisiones inmutable

`PROGRESS.md` guarda lo que es cierto ahora; `DECISIONS.md` guarda **por qué**, y su valor
viene de que sólo se pueda agregar. Cuando una decisión previa estorba, lo más barato para un
agente es editar la razón por la que existía — y la siguiente sesión lee un ledger prolijo
sin forma de saber que se abandonó una restricción en vez de resolverla.

Agregar es libre. Reemplazar una decisión se hace **agregando** una entrada que referencia la
anterior. Editarla o borrarla sale con `DECISION_REWRITE_FORBIDDEN`, nombrando la entrada.

---

## Empezar

```bash
cd mi-proyecto
~/GitHub/harness-kit/bin/harness-activate.sh
```

Detecta el stack y el remoto, pide **una** confirmación, instala todo, activa en GitHub las
reglas que el plan permita, y cierra diciendo en qué estado quedó y qué sigue siendo tu
trabajo. Nunca sobrescribe un archivo existente, así que volver a correrlo es seguro.

```
Detectado:    Next.js + npm
Verificación: npm run check
Remoto:       gonzalezulises/mi-app

  ok   harness instalado
  ok   compuerta requerida activa en gonzalezulises/mi-app
  --   workflow NO protegido (los push rules requieren repo de organización)
```

Opciones: `--with gherkin` añade el pack de especificación ejecutable, `--dry-run` no escribe
nada, `--yes` salta la confirmación.

### Los tres estados

`bin/harness-status.sh` responde la pregunta que el score no responde:
*¿esto bloquea de verdad, o todo está en confianza?*

| Estado | Qué significa |
|---|---|
| `READY_DUAL` | La compuerta bloquea **y** protege su propia definición. Sólo en repos de organización. |
| `READY_PARTIAL` | Bloquea tests rotos y `passing` falsos, pero el workflow es editable. Repos personales. |
| `READY_LOCAL` | El harness corre local; nada en GitHub bloquea una fusión todavía. |
| `NOT_ACTIVATED` | Aquí no hay harness. |

**Medido contra GitHub el 2026-08-14** — esto decide dónde puedes usar qué:

| Capacidad | Repo privado personal | Organización (plan Team) |
|---|---|---|
| `required_status_checks` | ✅ activo | ✅ |
| `file_path_restriction` (push rules) | ❌ HTTP 422 *"Only org-owned repos can have push rules"* | ✅ |
| `required_workflows` | ❌ HTTP 422 incluso con Pro | (no se usa) |

En un repositorio personal tienes una compuerta real contra tests rotos y afirmaciones
falsas; lo único que no puedes cerrar ahí es que alguien edite la compuerta. Decirlo claro
es mejor que aparentar protección total o negarse a funcionar.

---

## Niveles y auditoría

**`--level minimal`** — 8 archivos, sin suponer sistema de build: contrato de operación,
ruta de arranque, estado de features, memoria de progreso y checklist de cierre.

**`--level full`** — agrega las compuertas mecánicas: `Makefile`, `verify-feature.sh`,
`verify-claims.sh`, `verify-decisions.sh`, `check-arch.sh` con registro de reglas,
`clean-state-check.sh`, trazas de sesión, el workflow y los payloads de ruleset.

```bash
bin/harness-audit.sh .              # legible
bin/harness-audit.sh . --json       # para CI
bin/harness-audit.sh . --strict     # exit 2 si falla cualquier recomendado
```

**84 checks, rúbrica v2**, con denominador estable: dos repositorios distintos dan scores
comparables. La versión de rúbrica viaja en la salida, así que un `71/74` anotado bajo la v1
sigue siendo legible en vez de competir en silencio con un total nuevo. Sale con 1 si falla
cualquier check crítico.

Los archivos de instrucciones se reconocen en inglés *o* español, y las reglas documentadas
en archivos enlazados de `docs/` cuentan para el score: el archivo de entrada debe quedarse
corto.

---

## Qué hay dentro

```
bin/harness-activate.sh   activación en un comando (detecta, pregunta una vez, instala)
bin/harness-status.sh     qué está realmente protegido, ahora mismo
bin/harness-audit.sh      auditor de 84 checks, sin dependencias
bin/harness-protect.sh    instala los rulesets y los verifica por GET
bin/harness-init.sh       scaffolder (--level minimal|full)
scripts/verify-feature.sh la única ruta a passing; hace cumplir los presupuestos
scripts/verify-claims.sh  re-verifica todo passing declarado
scripts/verify-decisions.sh  ledger append-only
templates/minimal/        contrato base y archivos de estado
templates/full/           Makefile, compuertas, workflow, payloads de ruleset
packs/gherkin/            especificación ejecutable + matriz de modos de falla
packs/load-testing/       compuerta de rendimiento k6
packs/sentry/             compuerta de observabilidad: prueba que los errores llegan
packs/openai-advanced/    estructura pesada para bases de código grandes
docs/evidence/            evidencia de que la compuerta bloquea de verdad
tests/run-tests.sh        verificación end-to-end del kit
```

### Packs

Opt-in, porque traen dependencias externas que no todo repositorio necesita.

- **`packs/gherkin/`** — criterios de aceptación ejecutables. Requiere `node` y
  `@cucumber/cucumber`. Su `verify-pack.sh` provoca 15 modos de falla y exige que todos
  bloqueen.
- **`packs/load-testing/`** — compuerta de rendimiento con k6: smoke determinista que puede
  bloquear una fusión, prueba de carga a demanda con evidencia de entrega, y línea base que
  detecta degradación. Requiere `k6` en el PATH.
- **`packs/sentry/`** — compuerta de observabilidad: prueba que un evento **llega y se
  almacena**, no que el SDK esté instalado. Un DSN vacío, un `sampleRate: 0` o una cuota
  agotada dejan el build en verde y el proyecto vacío; los tres bloquean aquí. Cubre
  además source maps, commits asociados (sin ellos Sentry nunca nombra el cambio que
  rompió algo), salud del release y cron monitors — un trabajo programado que dejó de
  correr no produce errores, produce silencio. Requiere `curl` y una cuenta de Sentry para
  la ruta viva; su `verify-pack.sh` corre sin red.

---

## Requisitos

`bash` 3.2+ (el de macOS de fábrica sirve) y `git`. `python3` sólo para el nivel full.
Sin `npm install`, sin runtime, sin nada que mantener al día. Las únicas excepciones son los
packs: `k6` para el de rendimiento, `node` para el de Gherkin, `curl` y una cuenta de Sentry
para el de observabilidad.

---

## Verificar el kit

```bash
make check                          # 149 aserciones end-to-end
bash packs/gherkin/verify-pack.sh   # 15 modos de falla, todos deben bloquear
bash packs/load-testing/verify-pack.sh
bash packs/sentry/verify-pack.sh    # 55 modos de falla, todos deben bloquear
```

Sin mocks: construye repositorios desechables, corre los scripts reales y afirma sobre
comportamiento observable — que una capa fallida no promueve una feature, que hace falta
`--force` para sobrescribir, que un secreto commiteado activa una regla, que un presupuesto
agotado bloquea, que un `passing` escrito a mano no sobrevive.

### Evidencia contra GitHub real

`docs/evidence/2026-08-14-gate-canary.md` registra la compuerta bloqueando pull requests
reales en un canario de organización: una feature verificada fusionada, un test roto
bloqueado, un `passing` escrito a mano bloqueado por `FALSE_CLAIM` **con el producto
compilando bien**, y un intento de saltar la compuerta rechazado en el push.

Un detalle que importa al automatizar: un PR bloqueado reporta `mergeable=MERGEABLE` con
`mergeStateStatus=BLOCKED`. `mergeable` sólo significa "sin conflictos de Git" — leer ese
campo daría un falso verde.

---

## Límites conocidos

- **Un administrador puede saltarse la compuerta** con `gh pr merge --admin`; GitHub lo
  ofrece en el propio mensaje de rechazo. Es una acción humana deliberada, no un bypass de
  rutina, pero existe.
- **En repositorios personales el workflow no se puede proteger** (los push rules son
  exclusivos de organizaciones). Ahí la defensa es revisar a mano cualquier PR que toque
  `.github/workflows/`.
- **El score mide estructura, no eficacia.** Un repositorio puede sacar 84/84 y aun así
  alojar malas sesiones. La prueba real son corridas antes/después sobre tareas
  representativas.
- **Un step que no compara nada pasa siempre.** La compuerta de Gherkin exige que cada
  escenario ejecute y termine en `PASSED`, pero no puede saber si tu `Then` compara algo
  real: eso sigue siendo responsabilidad de quien escribe el escenario.

---

## Créditos

Derivado de [learn-harness-engineering](https://github.com/walkinglabs/learn-harness-engineering)
de WalkingLab (MIT). Ver [CREDITS.md](CREDITS.md) para qué se adoptó y qué cambió.

Los presupuestos anti-loop, el modelo de compuerta fail-closed y el ledger de decisiones
provienen del diseño de `ai-software-factory` (archivado), que los especificó y nunca llegó
a implementarlos.
