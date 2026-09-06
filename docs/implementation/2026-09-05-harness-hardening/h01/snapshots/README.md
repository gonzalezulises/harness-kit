# Reproduce H01 RED from retained bytes

Each phase contains the exact pre-fix four verifier scripts and the permanent
test file paired with that source during review. Intermediate Git trees were
local review snapshots, not published commits; these retained files make the
proof independently reproducible after cloning. Manifests bind their bytes.
`initial` uses the published audit source at 9ee4eaa; later phases use the
preceding reviewed source. Audit probes imported by the test remain unchanged.

Run in an isolated exported checkout, replacing `fix-3` with the desired phase:

```bash
task_repo=$(mktemp -d)
git archive HEAD | tar -x -C "$task_repo"
phase="$task_repo/docs/implementation/2026-09-05-harness-hardening/h01/snapshots/fix-3"
cp "$phase/test-source.py" "$task_repo/tests/h01-hardening-regressions.py"
H01_SCRIPT_ROOT="$phase/source" PYTHONDONTWRITEBYTECODE=1 \
  python3 "$task_repo/tests/h01-hardening-regressions.py"
```

A nonzero assertion result is expected for these historical defective sources.
Do not interpret runner/import errors as RED. The recorded RED/GREEN logs and
independent verdicts live beside `snapshots/`, in each round's evidence folder.
The tests create their own disposable fixtures; no target repository is used.
