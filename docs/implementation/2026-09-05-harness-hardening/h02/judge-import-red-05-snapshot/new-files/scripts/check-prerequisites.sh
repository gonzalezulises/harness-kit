#!/usr/bin/env bash
# core: portable kit tests plus the full oracle parser; full: every pack matrix.
set -uo pipefail
MODE="${1:-core}"
case "$MODE" in core|full) ;; *) exit 64 ;; esac
for tool in bash python3 git; do
  command -v "$tool" >/dev/null 2>&1 || { echo "TOOL_FAILURE: missing $tool" >&2; exit 3; }
done
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARSER=python3
[[ ! -x "$ROOT/.harness/tools/oracles-venv/bin/python3" ]] || PARSER="$ROOT/.harness/tools/oracles-venv/bin/python3"
"$PARSER" -c 'import yaml; assert yaml.__version__ == "6.0.3"' >/dev/null 2>&1 || {
  echo 'TOOL_FAILURE: PyYAML==6.0.3 required; run bash scripts/setup-oracles.sh' >&2; exit 3;
}
if [[ "$MODE" == full ]]; then
  for tool in node k6 curl; do
    command -v "$tool" >/dev/null 2>&1 || { echo "TOOL_FAILURE: full verification needs $tool" >&2; exit 3; }
  done
fi
printf 'Prerequisites verified for %s scope; no verification tests ran in this step.\n' "$MODE"
