#!/usr/bin/env bash
# F20 — activation records which files belong to the kit, with their hashes.
#
# The kit copies ~30 files into a repository and then forgets which ones. Without
# that record nothing can answer the two questions an upgrade has to ask of every
# file: «is this mine to replace?» and «did someone change it since I wrote it?».
# The only tool left is `--force`, which answers «yes» and «do not care» for all of
# them — including DECISIONS.md.
#
# Two classes, and the lock is where the line is drawn:
#
#   managed  the judge — verifiers, runner, required workflow. Replaced on upgrade;
#            a local edit is drift and must be visible.
#   owned    the repository's memory and policy — DECISIONS.md, PROGRESS.md,
#            feature_list.json, arch rules, context routes, gate registry, AGENTS.md,
#            Makefile. Written once at activation, never touched again.
#
# Proposed contract: `.harness/kit-lock.json` =
#   { "kit_version": "...", "managed": { "<path>": "<sha256>", ... } }
#
# Usage: bash tests/contract/F20-lock-records-what-the-kit-owns.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$HERE/../.." && pwd)"
# shellcheck source=tests/contract/lib.sh
. "$HERE/lib.sh"

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
echo "${BOLD}F20 — the lock records what the kit owns${RESET}"
command -v python3 >/dev/null 2>&1 || { echo "needs python3" >&2; exit 3; }

new_repo "$WORK/consumer"
printf '%s\n' '{"name":"x","version":"1.0.0","scripts":{"check":"echo ok","dev":"echo dev"}}' > package.json
commit_all "base"
bash "$KIT_DIR/bin/harness-init.sh" --target . --level full >/dev/null 2>&1
commit_all "harness"

LOCK=".harness/kit-lock.json"
if [[ ! -f "$LOCK" ]]; then
  bad "activation wrote no $LOCK — nothing records which files are the kit's"
  finish "F20"
fi

REPORT="$(python3 - "$LOCK" <<'PYEOF'
import hashlib, json, os, sys
try:
    lock = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception as e:
    print(f"BAD\tlock is not valid JSON: {e}"); sys.exit(0)
managed = lock.get("managed")
if not isinstance(managed, dict) or not managed:
    print("BAD\tlock has no non-empty `managed` map"); sys.exit(0)
print("OK\tlock parses and lists %d managed files" % len(managed))
print(("OK" if str(lock.get("kit_version") or "").strip() else "BAD") + "\tlock records the kit version it came from")

must_manage = ["scripts/verify-claims.sh", "scripts/verify-decisions.sh", "scripts/run-gates.sh",
               "scripts/check-arch.sh", ".github/workflows/required-quality.yml"]
must_own = ["DECISIONS.md", "PROGRESS.md", "feature_list.json",
            ".harness/arch-rules.json", ".harness/context-routes.json"]
for p in must_manage:
    print(("OK" if p in managed else "BAD") + f"\tthe judge is managed: {p}")
for p in must_own:
    print(("BAD" if p in managed else "OK") + f"\tthe repository's memory is NOT managed: {p}")

stale = []
for path, want in managed.items():
    if not os.path.isfile(path):
        stale.append(path + " (missing)"); continue
    got = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if got != str(want).lower().replace("sha256:", ""):
        stale.append(path)
print(("OK" if not stale else "BAD") + "\tevery recorded hash matches the file on disk"
      + ("" if not stale else ": " + ", ".join(stale[:5])))
PYEOF
)"
while IFS=$'\t' read -r verdict label; do
  [[ -z "$verdict" ]] && continue
  if [[ "$verdict" == "OK" ]]; then ok "$label"; else bad "$label"; fi
done <<< "$REPORT"

# ── drift is visible ─────────────────────────────────────────────────────────
printf '\n# local hotfix\n' >> scripts/verify-claims.sh
OUT="$(NO_COLOR=1 bash "$KIT_DIR/bin/harness-status.sh" --target . 2>&1)"
case "$OUT" in
  *scripts/verify-claims.sh*) ok "harness-status names a managed file that was edited locally" ;;
  *)                          bad "a locally edited judge is invisible to harness-status" ;;
esac

finish "F20"
