#!/usr/bin/env bash
# F17 — a freshly activated repository passes its own gates, on every stack the
#       scaffolder claims to detect.
#
# The suite exercises each gate script against fixtures. It never ran the one path
# every consumer takes: activate, then `make gates`. Twice that gap shipped a red
# baseline to real repositories:
#
#   · 2026-09-03 → 09-15  `version-sync` required + script absent = NOT_EXECUTED
#                         in every installation; found in a client repo.
#   · 2026-09-19          harness-init writes `make dev` as a bare TODO for any
#                         repo without a dev/start script, and makefile-gates —
#                         the kit's own gate — rejects it. Libraries, CLIs and
#                         Python pipelines are born red.
#
# A red baseline teaches people to skim the gate output, which is the failure the
# kit exists to prevent. The control at the bottom keeps the repair honest: the
# phantom-gate check must still bite.
#
# Usage: bash tests/contract/F17-fresh-scaffold-is-green.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F17 — a fresh scaffold passes its own gates${RESET}"

# seed_<stack> — the smallest manifest harness-init recognises as that stack.
seed_node_app()   { printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","test":"echo ok","dev":"echo dev"}}' > package.json; echo '{}' > package-lock.json; }
seed_node_lib()   { printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","test":"echo ok"}}' > package.json; echo '{}' > package-lock.json; }
seed_python_uv()  { printf '[project]\nname = "x"\nversion = "0.1.0"\n' > pyproject.toml; : > uv.lock; }
seed_python_pip() { echo 'pytest' > requirements.txt; }
seed_go()         { printf 'module example.com/x\n\ngo 1.22\n' > go.mod; }
seed_rust()       { printf '[package]\nname = "x"\nversion = "0.1.0"\n' > Cargo.toml; }
seed_bare()       { :; }

for stack in node_app node_lib python_uv python_pip go rust bare; do
  new_repo "$WORK/$stack"
  "seed_$stack"
  commit_all "base"
  if ! bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1; then
    bad "$stack — harness-init failed"; cd "$WORK" || exit 70; continue
  fi
  commit_all "harness"
  OUT="$(bash scripts/run-gates.sh quick 2>&1)"; RC=$?
  if [[ "$RC" -eq 0 ]]; then
    ok "$stack — run-gates quick is green straight after activation"
  else
    bad "$stack — born red (exit $RC)"
    printf '%s\n' "$OUT" | grep -E '^[[:space:]]+(·|make )' | sed 's/^/        /'
  fi
  cd "$WORK" || exit 70
done

# ── control: the phantom-gate check still bites ──────────────────────────────
new_repo "$WORK/control"; seed_node_app; commit_all "base"
bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1
python3 - <<'PYEOF'
import re
p = "Makefile"; s = open(p, encoding="utf-8").read()
s = re.sub(r"(?m)^(e2e:.*\n)\t.*$", r"\1\t@echo 'TODO: wire the browser suite'", s, count=1)
open(p, "w", encoding="utf-8").write(s)
PYEOF
commit_all "phantom e2e"
bash scripts/run-gates.sh quick >/dev/null 2>&1
expect_nonzero "control: an e2e target that announces a TODO and exits 0 still blocks" $?

finish "F17"
