# Gate canary — evidencia del bloqueo real

**Fecha:** 2026-08-14
**Repositorio canario:** `rizo-ma/harness-kit-gate-canary-20260814` (privado, org plan Team)
**Kit:** rama `feat/anti-loop-budgets`, commits `d0e29ef`, `8f17aaf`, `37dfe88`

Esta es la evidencia que faltaba: hasta hoy el gate era un YAML que parecía correcto y
ningún PR real lo había atravesado.

## Rulesets instalados

Instalados con `bin/harness-protect.sh` **después** de que el workflow existiera en `main`.
Ese orden importa: el ruleset de integridad prohíbe tocar la ruta del workflow, así que
instalarlo antes impide subirlo.

| Ruleset | ID | Target | Enforcement | Bypass actors |
|---|---|---|---|---|
| `required-quality-check` | 20856548 | `branch` | active | 0 |
| `required-quality-workflow-integrity` | 20856550 | `push` | active | 0 |

Ambos confirmados con un GET posterior, no sólo por la respuesta de creación.

## Matriz de fallo

| # | Caso | Corrida | Resultado CI | Merge |
|---|---|---|---|---|
| 1 | Feature verde promovida por `verify-feature.sh` | `31813770292` | **success** | **MERGED** 15:19:16Z |
| 2 | Test roto (el cálculo ignora la cantidad) | `31813790317` | failure | **bloqueado** |
| 3 | `"state": "passing"` escrito a mano | `31813795611` | failure | **bloqueado** |
| 4 | `if: false` en el job del workflow | — | — | **rechazado en el push** |

### Razones exactas, no sólo códigos de salida

- **PR2** falló dentro de `make check`:
  `AssertionError [ERR_ASSERTION]: Expected values to be strictly equal`.
- **PR3** falló en el paso de re-verificación, con el producto compilando bien:
  `FAIL unit $ node tests/coupon.test.js` → `FALSE_CLAIM: 1 layer(s) failed across
  features marked passing`. La feature declaraba `evidence: ["listo, lo probe localmente"]`
  y su capa ni siquiera existía.
- **PR4** nunca llegó a ser un PR. El push fue rechazado en el servidor:

  ```
  remote: - GITHUB PUSH PROTECTION
  remote:     - File path is restricted
  remote:       .github/workflows/required-quality.yml
  ! [remote rejected] attack/skip-the-gate (push declined due to repository rule violations)
  ```

- **Intento real de merge** sobre los dos bloqueados:
  `the base branch policy prohibits the merge`.

## Matiz que importa al leer `gh pr view`

Los PRs bloqueados reportan `mergeable=MERGEABLE` con `mergeStateStatus=BLOCKED`.
`mergeable` sólo dice que no hay conflictos de Git; **el campo que refleja la protección es
`mergeStateStatus`**. Automatizar sobre `mergeable` daría un falso verde.

## Límites declarados

- **Un administrador puede saltarse el gate** con `gh pr merge --admin`. GitHub lo ofrece
  explícitamente en el mensaje de rechazo. Es el mismo límite residual que la fábrica
  registró en ADR-0002: la acción deliberada de un administrador no es un bypass actor de
  rutina, pero existe.
- Sólo probado en **organización con plan Team**. En cuenta personal, `required_workflows`
  devuelve HTTP 422 y los rulesets en repos privados con Free devuelven 403.
- El canario sigue vivo con los PRs 2 y 3 abiertos como evidencia inspeccionable. Borrarlo
  elimina la prueba.
