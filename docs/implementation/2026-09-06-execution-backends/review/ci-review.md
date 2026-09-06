### Spec Compliance

- ✅ Spec compliant. The workflow changes are confined to the eight required protected-base locations: contract/setup/parser/gates at `.github/workflows/required-quality.yml:137-149`, claims at `.github/workflows/required-quality.yml:184-187`, and decisions at `.github/workflows/required-quality.yml:206-209`. The final protected-gate sentinel remains required at `.github/workflows/required-quality.yml:248`; the locked Node setup and dependency install remain at `.github/workflows/required-quality.yml:152-161`.
- ✅ The focused regression exercises the extracted real workflow run block, a valid relocated base bundle, and real quick gates at `tests/protected-workflow-regression.py:21-34,94-97`; its candidate-only negative moves the full judge to head, removes it from base, requires `ADOPTION_REQUIRED`, and requires the sentinel to remain absent at `tests/protected-workflow-regression.py:99-105`. It is invoked once in the normal core verification path at `Makefile:32`, and its falsifiable criterion is registered at `.harness/oracles/AC-F24-protected-ci.yaml:2-29`.
- ✅ The current static verifier compares the normalized workflow AST to the exact before snapshot, requires all eight relocated paths, and preserves the locked Node/dependency steps at `docs/implementation/2026-09-06-execution-backends/verify-ci-static.sh:16-41`. It also binds the finalized RED/GREEN evidence and retained historical receipt at `docs/implementation/2026-09-06-execution-backends/verify-ci-static.sh:50-68` without changing the historical verifier.
- ✅ The capability/preflight documentation records the versioned protected-root contract and explicit owner adoption boundary at `docs/harness-capabilities.md:21-23` and `docs/implementation/2026-09-06-execution-backends/ci-adoption-preflight.md:19-29`; the required Agent Note records the authority decision and rejected candidate fallback at `.agents/notes/implemented/process/2026-09-06-versioned-protected-judge-path.md:1-14`.
- ✅ The separate adoption-checkout diff is limited to the inherited telemetry opt-out at `/workspace/scratch/adce1c53b293/harness-judge-adoption/packs/load-testing/verify-pack.sh:14-16`.
- ⚠️ Cannot verify from this task diff: owner review/adoption of the pre-existing 28-file bundle, a remote required-quality run against an adopted base, and controller-owned F19/F23/F24 rebinding/full feature-layer verification. These are deliberately outstanding rather than implementation omissions; the preflight keeps the proposal non-authoritative until owner merge at `docs/implementation/2026-09-06-execution-backends/ci-adoption-preflight.md:7-11,27-30`. The earlier interrupted global cybersecurity review remains incomplete and is outside this task-scoped verdict.

### Strengths

- The implementation makes the authority boundary visually explicit through literal base-bundle paths and contains no head-derived path or fallback (`.github/workflows/required-quality.yml:137-149,184-209`).
- The regression tests behavior rather than reproducing a path list: it extracts the shipped workflow step and requires both a real zero-blocking quick-gate result and the post-success sentinel (`tests/protected-workflow-regression.py:21-34,94-105`).
- The static check combines semantic whole-workflow equivalence with exact checks for security-sensitive pins and evidence hashes, so the allowed relocation stays narrow (`docs/implementation/2026-09-06-execution-backends/verify-ci-static.sh:16-68`).
- Focused unchanged-code inspection for one named integration risk: the test's parser fixture could have accidentally replaced the gate runner itself. `scripts/setup-oracles.sh:4-7` confines the mocked operations to venv creation/install/version setup, while `scripts/run-gates.sh:25-75` still executes the real registry and target scripts; this matches the wrapper behavior at `tests/protected-workflow-regression.py:69-88`.

### Issues

#### Critical (Must Fix)

- None.

#### Important (Should Fix)

- None.

#### Minor (Nice to Have)

- None.

### Assessment

**Task quality:** Approved

**Reasoning:** The diff implements the requested protected-root relocation without broadening authority, adds a portable behavioral regression to the required verification path, and uses a strong frozen-structure/evidence verifier. The reported focused runs are clean, and the remaining adoption and feature-layer work is explicitly assigned outside this bounded task.
