#!/usr/bin/env bash
# F15 — a pack must not open a hole in the repository it is installed into.
#
# The packs' failure matrices measure whether a gate DETECTS failure. None of them
# measured what the gate EXPOSES by being installed. Two shapes are checked here,
# both static, both offline:
#
#   1. No `${{ … }}` expression inside a `run:` script of any workflow a pack
#      ships. GitHub substitutes the expression before bash reads the line, so the
#      surrounding quotes bound nothing: whoever controls the value controls the
#      shell. Values travel through `env:` and are read as "$VAR".
#   2. Every Sentry.init a pack ships wires a scrubber through `beforeSend` AND
#      `beforeSendTransaction`. `sendDefaultPii: false` does not filter the URL,
#      and a capability token in a path is a credential, not PII.
#
# Usage: bash tests/contract/F15-packs-expose-nothing.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

echo "${BOLD}F15 — packs expose nothing by being installed${RESET}"
command -v python3 >/dev/null 2>&1 || { echo "needs python3" >&2; exit 3; }

# ── 1. expressions inside run: scripts ───────────────────────────────────────
WORKFLOWS="$(find "$KIT_DIR/packs" "$KIT_DIR/templates" -path '*/.github/workflows/*' \
  \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | sort)"
if [[ -z "$WORKFLOWS" ]]; then
  bad "no shipped workflow was found — the probe inspected nothing"
else
  while IFS= read -r wf; do
    [[ -z "$wf" ]] && continue
    rel="${wf#$KIT_DIR/}"
    HITS="$(python3 - "$wf" <<'PYEOF'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().splitlines()
in_block, block_indent = False, 0
for n, line in enumerate(lines, 1):
    stripped = line.lstrip(" ")
    indent = len(line) - len(stripped)
    if in_block:
        if stripped == "" or indent > block_indent:
            if "\x24{{" in line:
                print(f"{n}: {stripped.strip()}")
            continue
        in_block = False
    m = re.match(r"^(-\s+)?run:\s*(.*)$", stripped)
    if not m:
        continue
    rest = m.group(2)
    if re.match(r"^[|>][+-]?\s*$", rest):
        in_block, block_indent = True, indent + (len(m.group(1)) if m.group(1) else 0)
    elif "\x24{{" in rest:
        print(f"{n}: {stripped.strip()}")
PYEOF
)"
    if [[ -z "$HITS" ]]; then
      ok "$rel — no expression is interpolated into a run: script"
    else
      bad "$rel — \${{ }} inside run: (move it to env: and read \"\$VAR\")"
      printf '%s\n' "$HITS" | sed 's/^/         line /'
    fi
  done <<< "$WORKFLOWS"
fi

# ── 2. every Sentry.init carries a scrubber ──────────────────────────────────
INITS="$(grep -rlE 'Sentry\.init[[:space:]]*\(' "$KIT_DIR/packs" \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.mjs' --include='*.cjs' \
  2>/dev/null | sort)"
if [[ -z "$INITS" ]]; then
  bad "no Sentry.init was found — the probe inspected nothing"
else
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    rel="${f#$KIT_DIR/}"
    if grep -qE '\bbeforeSend\b[[:space:]]*[:,]' "$f" && grep -qE '\bbeforeSendTransaction\b[[:space:]]*[:,]' "$f"; then
      ok "$rel — beforeSend and beforeSendTransaction are wired"
    else
      bad "$rel — Sentry.init ships without a scrubber on both hooks"
    fi
  done <<< "$INITS"
fi

finish "F15"
