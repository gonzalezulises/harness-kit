# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).
Versionado semántico. Cada repositorio activado registra en `.harness/kit-version`
con qué versión se construyó, así que `harness-status.sh` puede decir cuál está atrasado.

---

## [2.1.0] — 2026-08-14

Remediación de la auditoría DevOps. **Contiene un arreglo de seguridad: los repositorios
en 2.0.0 deben actualizarse.**

### Seguridad

- **`WEAKENED_VERIFICATION` (exit 5).** El re-verificador de afirmaciones tomaba el
  *script* de la rama base protegida, pero ejecutaba los *comandos* del pull request.
  Cambiar `"cmd": "node tests/checkout.test.js"` por `"cmd": "true"` en el mismo cambio
  que mantenía el estado `passing` hacía que la compuerta respondiera *"every passing
  state is backed by a run"*. La garantía principal del sistema era evadible sin tocar
  el estado a mano: bastaba con reescribir el verificador.

  Ahora, una feature que ya estaba `passing` en la base y sigue `passing` debe conservar
  sus `layers`. Cambiar la verificación invalida el recibo anterior: se pone la feature
  en `active` y se vuelve a ganar. No bloquea refactorizar, ni features nuevas, ni
  eliminar una feature.

### Añadido

- CI propio del kit: `shellcheck`, la suite completa y el pack de Gherkin en cada PR.
- `VERSION` como fuente única, `.harness/kit-version` en cada repo activado, y
  `harness-status.sh` avisando cuando un repositorio quedó atrás.
- `.github/dependabot.yml` para los SHAs pinneados de las actions, incluida la copia
  bajo `templates/` que se replica en cada repositorio activado.

### Corregido

- `SC2319` en `packs/gherkin/verify-pack.sh`: el `$?` de la rama `else` refería al
  `[[ ]]`, no al comando, así que ese caso reportaba siempre el código equivocado.
- `cd` sin `|| exit` en seis scripts que escriben y borran archivos.
- `clean-state-check.sh` escribía su log en una ruta fija de `/tmp` (colisión entre
  proyectos concurrentes y blanco de symlink en máquina compartida).
- `harness-protect.sh` escribía los errores de la API dentro de `.github/rulesets/` del
  usuario y dejaba el archivo huérfano si la instalación fallaba a medias.

### Nota sobre dos falsos positivos

`PLAN_BRANCH` y `PROPOSED` en `packs/load-testing/verify-pack.sh` aparecen como variables
sin usar (SC2034). No lo están: se expanden dentro del string que `check()` evalúa después.
Borrarlas habría eliminado en silencio dos aserciones de un pack que reporta 57/57.

---

## [2.0.0] — 2026-08-14

Capa de gobierno. El harness pasa de aconsejar a poder negarse.

### Añadido

- **Presupuestos anti-loop** en `verify-feature.sh`: `review_rounds_max`,
  `repeated_blocker_max` y `stop_condition` obligatoria. Exit 3, 4 y 67.
- **`verify-claims.sh`**: todo `passing` es una afirmación hasta que sus capas vuelven a
  correr desde la base protegida. `FALSE_CLAIM`, `NOT_VERIFIABLE`, `NO_CLAIMS`.
- **Compuerta que protege su propia definición**: workflow fail-closed con base protegida
  y centinelas, más dos rulesets. GitHub cuenta un job saltado por su propia condición
  como check *exitoso*, así que exigir el nombre del check no basta.
- **`packs/gherkin/`**: especificación ejecutable que valida el reporte, no el código de
  salida. Cucumber sale 0 con cero escenarios ejecutados.
- **`verify-decisions.sh`**: `DECISIONS.md` append-only, `DECISION_REWRITE_FORBIDDEN`.
- **`harness-activate.sh` y `harness-status.sh`**: un comando y tres estados honestos
  (`READY_DUAL`, `READY_PARTIAL`, `READY_LOCAL`).
- Auditor en rúbrica v2: 84 checks con el grupo Enforcement, y la versión de rúbrica en
  la salida para que los scores anteriores sigan siendo legibles.

### Capacidades medidas contra GitHub

`required_status_checks` funciona en repositorio privado personal; las push rules
(`file_path_restriction`) son exclusivas de organizaciones (HTTP 422). De ahí
`READY_PARTIAL`: la compuerta bloquea, pero no puede protegerse a sí misma.

---

## [1.0.0] — 2026-08-05

Kit inicial: auditor de 74 checks, scaffolder en dos niveles, `verify-feature.sh` como
única ruta a `passing`, y los packs `openai-advanced` y `load-testing`.
