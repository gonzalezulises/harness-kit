# Changelog

Formato: [Keep a Changelog](https://keepachangelog.com/es/1.1.0/).
Versionado semántico. Cada repositorio activado registra en `.harness/kit-version`
con qué versión se construyó, así que `harness-status.sh` puede decir cuál está atrasado.

---

## [2.2.0](https://github.com/gonzalezulises/harness-kit/compare/v2.1.0...v2.2.0) (2026-08-30)


### Añadido

* **audit:** add the Enforcement group and version the rubric ([d996682](https://github.com/gonzalezulises/harness-kit/commit/d9966822e108124c3f8405f8903de0a94268814e))
* **cli:** one command to activate, and an honest answer about what is enforced ([aa73fef](https://github.com/gonzalezulises/harness-kit/commit/aa73fef7146e4cda98927db56dd2baef795a2b3e))
* gate registry, Agent Notes lifecycle, and staged-only hooks ([0c416cc](https://github.com/gonzalezulises/harness-kit/commit/0c416ccb4d1d9dd007c2193c0a8a4482930bbda6))
* **packs:** add the Gherkin pack — executable specs that must actually execute ([eb9957f](https://github.com/gonzalezulises/harness-kit/commit/eb9957f3666d4b95c3a811c82a0d25cdfbfa5564))
* **packs:** add the k6 performance gate pack ([03c924b](https://github.com/gonzalezulises/harness-kit/commit/03c924b9ef796f51ed58eecb7b670ab966094d10))
* **packs:** carry production signal into the backlog, idempotently ([6330098](https://github.com/gonzalezulises/harness-kit/commit/6330098e90fc1b8a5936389bb31b1aed84b23313))
* **packs:** carry production signal into the backlog, idempotently ([ddec02f](https://github.com/gonzalezulises/harness-kit/commit/ddec02f2484071f6163221feeb1b6624dadda23b))
* **packs:** cover the rest of Sentry, not just the error pipeline ([bc0a816](https://github.com/gonzalezulises/harness-kit/commit/bc0a816f29f4647984355f864d53ddad19f99732))
* **packs:** cover the rest of Sentry, not just the error pipeline ([e631fc0](https://github.com/gonzalezulises/harness-kit/commit/e631fc0c0e842ef7aeb979889ec67dafab7d00bc))
* **packs:** gate observability on proof of arrival, not on configuration ([928976b](https://github.com/gonzalezulises/harness-kit/commit/928976bc65fccd88221ef43fec53389ec185e011))
* **packs:** Sentry observability gate + development-cycle diagram ([e81a333](https://github.com/gonzalezulises/harness-kit/commit/e81a3339d6e92718f092f959b1f1483c9a6f88b1))
* portable agent harness kit derived from learn-harness-engineering ([2654584](https://github.com/gonzalezulises/harness-kit/commit/2654584630d84d129f7df2e1f02b8824b7203320))
* **verify:** enforce anti-loop budgets in verify-feature ([d0e29ef](https://github.com/gonzalezulises/harness-kit/commit/d0e29ef48303c3383244b8320eb2e5a4052679dd))
* **verify:** make the decision ledger append-only ([0c027a6](https://github.com/gonzalezulises/harness-kit/commit/0c027a6f7d6552aef32357379e17f985dadd96b6))
* **verify:** re-verify claimed passing states on a runner the agent cannot control ([8f17aaf](https://github.com/gonzalezulises/harness-kit/commit/8f17aaf861b2d1642a7b4e0dcbb3fa6cb73e67dd))
* **version:** stamp the kit version into every repository it builds ([487250b](https://github.com/gonzalezulises/harness-kit/commit/487250bc95dae25caa0ca3e915f9e45d9cdec543))


### Arreglado

* **ci:** pin shellcheck, and drop the argument finish() never receives ([5257390](https://github.com/gonzalezulises/harness-kit/commit/5257390fe6f6ac1d75315630e81fe94ef8a40541))
* **ci:** protect the required workflow from being skipped into a pass ([37dfe88](https://github.com/gonzalezulises/harness-kit/commit/37dfe88f54b4f555c192ee7a9c11e95cd71d08fb))
* correct invalid deny rule pattern in project settings ([7dfcd14](https://github.com/gonzalezulises/harness-kit/commit/7dfcd14047498024f135d218567474a5d22ec6ec))
* correct invalid deny rule pattern in project settings ([5c0a81b](https://github.com/gonzalezulises/harness-kit/commit/5c0a81bffdbfbf6d7fbc60817b188e6860cea90a))
* falla() called itself — restore say in the definition ([8da6436](https://github.com/gonzalezulises/harness-kit/commit/8da64366d0b6a31a64832a15d2e5490578712773))
* guard the cd in install-githooks (SC2164) ([ec60174](https://github.com/gonzalezulises/harness-kit/commit/ec60174f3effbdde532d3e3b48033ffebbd51aa4))
* honor DECISIONS_BASE_FILE before requiring a git base ref ([234dac7](https://github.com/gonzalezulises/harness-kit/commit/234dac7b7ddc1dbe073411dd52dad4c9572b16df))
* **hygiene:** clear every shellcheck warning, and the bugs behind two of them ([ec04911](https://github.com/gonzalezulises/harness-kit/commit/ec0491127e065128e9b5b87fa6357330631013ee))
* isolate verify commands in a subshell; refine clean-state artifact checks ([84e8c71](https://github.com/gonzalezulises/harness-kit/commit/84e8c713d3dbeb52b58a885aa3fd1c9feda4f20a))
* mawk-compatible horizontal-rule match in decision splitting ([c4ef91e](https://github.com/gonzalezulises/harness-kit/commit/c4ef91e3b97b5a8719492d9826f2c0553fd9a474))
* parse k6 templates as ESM in the pack syntax gate ([06cb12a](https://github.com/gonzalezulises/harness-kit/commit/06cb12a3e612e8ae630ab05073930e17d00385ad))
* pin ambient GITHUB_REPOSITORY out of the no-repo usage test ([087a0d5](https://github.com/gonzalezulises/harness-kit/commit/087a0d5e39b0ae4e42f79387986ec1b0cb29c1e6))
* placeholder-prefixed values are not credentials ([07a1ef5](https://github.com/gonzalezulises/harness-kit/commit/07a1ef558c0ab1ada6b6e26b1d95e2f8be5de710))
* repeat pack failures in the final summary ([54cb52f](https://github.com/gonzalezulises/harness-kit/commit/54cb52f982f3a4e7d751383ee3bb4b2cfee79a48))
* secret scanner ignores env-var references and digitless identifiers ([000dffa](https://github.com/gonzalezulises/harness-kit/commit/000dffaa8beb909585dea3bdeaeff0a9d82ebc8b))
* **sentry:** read JSON at the depth the check means ([b96ec34](https://github.com/gonzalezulises/harness-kit/commit/b96ec349c2840ff59067b39073bb2fe439c1a40e))
* **sentry:** read JSON at the depth the check means ([b475e3b](https://github.com/gonzalezulises/harness-kit/commit/b475e3b2ad45154b3e261913c53b66bedaca9903))
* **status:** stop leaking a shell error, and stamp the kit's own version ([e555031](https://github.com/gonzalezulises/harness-kit/commit/e555031ffc59209fd839a601605903245caec29a))
* **status:** stop leaking a shell error, stamp the kit's own version ([a369e03](https://github.com/gonzalezulises/harness-kit/commit/a369e03cfdaba3258f34459edb89743bfa44f68c))
* **verify:** reject a passing feature whose verification was weakened ([c8147a2](https://github.com/gonzalezulises/harness-kit/commit/c8147a2b8ccd0ecc96df6da80eebd7f3de577c53))
* **verify:** show why a layer failed instead of swallowing its output ([e6e6092](https://github.com/gonzalezulises/harness-kit/commit/e6e60927df0ec2b1c3cec4958a840c125f117f95))


### Documentación

* diagram the development cycle, including the loop it was missing ([90d1579](https://github.com/gonzalezulises/harness-kit/commit/90d1579a1ac3788ef98c415d8d24e38278133609))
* **evidence:** record the gate blocking real pull requests ([2a62dd8](https://github.com/gonzalezulises/harness-kit/commit/2a62dd84439ab609230e9245720c61f4e9da2ac4))
* expose gates, agent-notes, and hooks-install in the kit's own contract ([5c612b7](https://github.com/gonzalezulises/harness-kit/commit/5c612b71f0c446fd923d0643c74cad4790054ff2))
* gate-proof note in PROGRESS ([efe7e25](https://github.com/gonzalezulises/harness-kit/commit/efe7e2559f9709fbdea37177552f716a2c84bd98))
* record the one setting that blocks the first release ([5cc93fa](https://github.com/gonzalezulises/harness-kit/commit/5cc93fa24cd09a966381650603a3f2d3e0e27431))
* record the one setting that blocks the first release ([7f47cd2](https://github.com/gonzalezulises/harness-kit/commit/7f47cd283a76394bbacbcfd34f0028168069ccbb))
* record what this is now, with the features promoted by the harness itself ([fc446bb](https://github.com/gonzalezulises/harness-kit/commit/fc446bb0656d888c0b9f2b4e2f0991f00b029113))

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
