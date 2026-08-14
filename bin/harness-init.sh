#!/usr/bin/env bash
# harness-init.sh — scaffold an agent harness into a repository.
#
# Usage:
#   harness-init.sh --target /path/to/repo [--level minimal|full] [--force] [--dry-run]
#
# Levels:
#   minimal  AGENTS.md, CLAUDE.md pointer, init.sh, PROGRESS.md, feature_list.json,
#            clean-state-checklist.md, session-handoff.md, DECISIONS.md
#   full     everything above, plus Makefile, verify-feature / check-arch /
#            clean-state-check / session-trace scripts, arch rules, sprint contract,
#            evaluator rubric and quality document
#
# Existing files are never overwritten without --force. Run with --dry-run first
# to see exactly what would be written.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET=""
LEVEL="minimal"
FORCE=0
DRYRUN=0
PROJECT_PURPOSE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)  TARGET="${2:-}"; shift 2 ;;
    --level)   LEVEL="${2:-}"; shift 2 ;;
    --purpose) PROJECT_PURPOSE="${2:-}"; shift 2 ;;
    --force)   FORCE=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         TARGET="$1"; shift ;;
  esac
done

[[ -n "$TARGET" ]] || { echo "harness-init: --target is required" >&2; exit 64; }
[[ -d "$TARGET" ]] || { echo "harness-init: not a directory: $TARGET" >&2; exit 66; }
[[ "$LEVEL" == "minimal" || "$LEVEL" == "full" ]] || {
  echo "harness-init: --level must be minimal or full" >&2; exit 64; }

TARGET="$(cd "$TARGET" && pwd)"
PROJECT_NAME="$(basename "$TARGET")"
DATE="$(date -u +%Y-%m-%d)"

# ── Detect the project's real commands ───────────────────────────────────────
INSTALL_CMD=""; VERIFY_CMD=""; START_CMD=""; TEST_CMD=""; E2E_CMD=""

has_script() {
  [[ -f "$TARGET/package.json" ]] && \
    grep -qE "\"$1\"[[:space:]]*:" "$TARGET/package.json" 2>/dev/null
}

if [[ -f "$TARGET/package.json" ]]; then
  PM="npm"
  [[ -f "$TARGET/pnpm-lock.yaml" ]] && PM="pnpm"
  [[ -f "$TARGET/yarn.lock" ]] && PM="yarn"
  { [[ -f "$TARGET/bun.lockb" ]] || [[ -f "$TARGET/bun.lock" ]]; } && PM="bun"

  case "$PM" in
    npm)  INSTALL_CMD="npm install"; RUN="npm run" ;;
    pnpm) INSTALL_CMD="pnpm install"; RUN="pnpm run" ;;
    yarn) INSTALL_CMD="yarn install"; RUN="yarn" ;;
    bun)  INSTALL_CMD="bun install"; RUN="bun run" ;;
  esac

  if   has_script "check";     then VERIFY_CMD="$RUN check"
  elif has_script "typecheck"; then VERIFY_CMD="$RUN typecheck && $RUN build"
  elif has_script "build";     then VERIFY_CMD="$RUN build"
  elif has_script "test";      then VERIFY_CMD="$RUN test"
  fi

  has_script "test" && TEST_CMD="$RUN test"
  has_script "e2e"  && E2E_CMD="$RUN e2e"
  if   has_script "dev";   then START_CMD="$RUN dev"
  elif has_script "start"; then START_CMD="$RUN start"
  fi

elif [[ -f "$TARGET/pyproject.toml" ]]; then
  if [[ -f "$TARGET/uv.lock" ]]; then
    INSTALL_CMD="uv sync"; VERIFY_CMD="uv run pytest"; TEST_CMD="uv run pytest"
  elif [[ -f "$TARGET/poetry.lock" ]]; then
    INSTALL_CMD="poetry install"; VERIFY_CMD="poetry run pytest"; TEST_CMD="poetry run pytest"
  else
    INSTALL_CMD="pip install -e ."; VERIFY_CMD="pytest"; TEST_CMD="pytest"
  fi
elif [[ -f "$TARGET/requirements.txt" ]]; then
  INSTALL_CMD="pip install -r requirements.txt"; VERIFY_CMD="pytest"; TEST_CMD="pytest"
elif [[ -f "$TARGET/Cargo.toml" ]]; then
  INSTALL_CMD="cargo fetch"; VERIFY_CMD="cargo test"; TEST_CMD="cargo test"; START_CMD="cargo run"
elif [[ -f "$TARGET/go.mod" ]]; then
  INSTALL_CMD="go mod download"; VERIFY_CMD="go test ./..."; TEST_CMD="go test ./..."; START_CMD="go run ."
fi

[[ -n "$VERIFY_CMD" ]]  || VERIFY_CMD="echo 'TODO: set the verification command'; false"
[[ -n "$START_CMD" ]]   || START_CMD="echo 'TODO: set the start command'"
[[ -n "$TEST_CMD" ]]    || TEST_CMD="$VERIFY_CMD"
[[ -n "$E2E_CMD" ]]     || E2E_CMD="echo 'TODO: set the end-to-end command'"
[[ -n "$INSTALL_CMD" ]] || INSTALL_CMD=""

if [[ -z "$PROJECT_PURPOSE" ]]; then
  PROJECT_PURPOSE="a software project. Replace this line with one sentence describing what it does and who uses it"
fi

# ── Placeholder substitution ─────────────────────────────────────────────────
PY=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done

render() {
  # render <src> <dest>
  local src="$1" dest="$2"
  if [[ -e "$dest" && $FORCE -eq 0 ]]; then
    echo "  skip    ${dest#$TARGET/} (exists — use --force to overwrite)"
    return 0
  fi
  if [[ $DRYRUN -eq 1 ]]; then
    echo "  would write ${dest#$TARGET/}"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -n "$PY" ]]; then
    PROJECT_NAME="$PROJECT_NAME" PROJECT_PURPOSE="$PROJECT_PURPOSE" \
    INSTALL_CMD="$INSTALL_CMD" VERIFY_CMD="$VERIFY_CMD" START_CMD="$START_CMD" \
    TEST_CMD="$TEST_CMD" E2E_CMD="$E2E_CMD" DATE="$DATE" \
    "$PY" - "$src" "$dest" <<'PYEOF'
import os, sys
src, dest = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
for key in ("PROJECT_NAME","PROJECT_PURPOSE","INSTALL_CMD","VERIFY_CMD",
            "START_CMD","TEST_CMD","E2E_CMD","DATE"):
    text = text.replace("{{%s}}" % key, os.environ.get(key, ""))
open(dest, "w", encoding="utf-8").write(text)
PYEOF
  else
    sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{PROJECT_PURPOSE}}|$PROJECT_PURPOSE|g" \
        -e "s|{{INSTALL_CMD}}|$INSTALL_CMD|g" \
        -e "s|{{VERIFY_CMD}}|$VERIFY_CMD|g" \
        -e "s|{{START_CMD}}|$START_CMD|g" \
        -e "s|{{TEST_CMD}}|$TEST_CMD|g" \
        -e "s|{{E2E_CMD}}|$E2E_CMD|g" \
        -e "s|{{DATE}}|$DATE|g" \
        "$src" > "$dest"
  fi
  echo "  write   ${dest#$TARGET/}"
}

M="$KIT_DIR/templates/minimal"
F="$KIT_DIR/templates/full"

echo "Harness init"
echo "  target: $TARGET"
echo "  level:  $LEVEL"
echo "  verify: $VERIFY_CMD"
[[ $DRYRUN -eq 1 ]] && echo "  (dry run — nothing will be written)"
echo ""

# ── Minimal layer ────────────────────────────────────────────────────────────
if [[ "$LEVEL" == "minimal" ]]; then
  render "$M/AGENTS.md" "$TARGET/AGENTS.md"
else
  # full: AGENTS.md is the minimal contract plus the mechanical-gate appendix
  if [[ -e "$TARGET/AGENTS.md" && $FORCE -eq 0 ]]; then
    echo "  skip    AGENTS.md (exists — use --force to overwrite)"
  elif [[ $DRYRUN -eq 1 ]]; then
    echo "  would write AGENTS.md (contract + full appendix)"
  else
    TMP_AGENTS="$(mktemp)"
    cat "$M/AGENTS.md" "$F/AGENTS-appendix.md" > "$TMP_AGENTS"
    render "$TMP_AGENTS" "$TARGET/AGENTS.md"
    rm -f "$TMP_AGENTS"
  fi
fi

render "$M/CLAUDE.md"                  "$TARGET/CLAUDE.md"
render "$M/init.sh"                    "$TARGET/init.sh"
render "$M/PROGRESS.md"                "$TARGET/PROGRESS.md"
render "$M/feature_list.json"          "$TARGET/feature_list.json"
render "$M/clean-state-checklist.md"   "$TARGET/clean-state-checklist.md"
render "$M/session-handoff.md"         "$TARGET/session-handoff.md"
render "$M/DECISIONS.md"               "$TARGET/DECISIONS.md"
render "$M/docs-decisions-README.md"   "$TARGET/docs/decisions/README.md"

# ── Full layer ───────────────────────────────────────────────────────────────
if [[ "$LEVEL" == "full" ]]; then
  render "$F/Makefile"                        "$TARGET/Makefile"
  render "$F/scripts/verify-feature.sh"       "$TARGET/scripts/verify-feature.sh"
  render "$F/scripts/verify-claims.sh"        "$TARGET/scripts/verify-claims.sh"
  render "$F/scripts/verify-decisions.sh"     "$TARGET/scripts/verify-decisions.sh"
  render "$F/.github/workflows/required-quality.yml" \
                                              "$TARGET/.github/workflows/required-quality.yml"
  render "$F/.github/rulesets/required-quality-check.json" \
                                              "$TARGET/.github/rulesets/required-quality-check.json"
  render "$F/.github/rulesets/required-quality-integrity.json" \
                                              "$TARGET/.github/rulesets/required-quality-integrity.json"
  render "$F/scripts/check-arch.sh"           "$TARGET/scripts/check-arch.sh"
  render "$F/scripts/clean-state-check.sh"    "$TARGET/scripts/clean-state-check.sh"
  render "$F/scripts/session-trace.sh"        "$TARGET/scripts/session-trace.sh"
  render "$KIT_DIR/bin/harness-audit.sh"      "$TARGET/scripts/harness-audit.sh"
  render "$F/.harness/arch-rules.json"        "$TARGET/.harness/arch-rules.json"

  # Stamp which kit built this. Without it there is no way to answer "which of my
  # repositories still lack the fix?" across a fleet.
  if [[ $DRYRUN -eq 0 ]]; then
    mkdir -p "$TARGET/.harness"
    tr -d '[:space:]' < "$KIT_DIR/VERSION" > "$TARGET/.harness/kit-version" 2>/dev/null || true
    printf '\n' >> "$TARGET/.harness/kit-version"
  fi
  render "$F/templates/sprint-contract.md"    "$TARGET/templates/sprint-contract.md"
  render "$F/templates/evaluator-rubric.md"   "$TARGET/templates/evaluator-rubric.md"
  render "$F/docs/quality-document.md"        "$TARGET/docs/quality-document.md"

  if [[ $DRYRUN -eq 0 ]]; then
    mkdir -p "$TARGET/.harness/traces"
    [[ -f "$TARGET/.harness/traces/.gitkeep" ]] || touch "$TARGET/.harness/traces/.gitkeep"
    echo "  write   .harness/traces/.gitkeep"
    if [[ -f "$TARGET/.gitignore" ]]; then
      grep -q '.harness/traces/traces.jsonl' "$TARGET/.gitignore" 2>/dev/null || {
        printf '\n# harness runtime artifacts\n.harness/traces/traces.jsonl\n' >> "$TARGET/.gitignore"
        echo "  append  .gitignore (traces.jsonl)"
      }
    else
      printf '# harness runtime artifacts\n.harness/traces/traces.jsonl\n' > "$TARGET/.gitignore"
      echo "  write   .gitignore"
    fi
  fi
fi

# ── Make scripts executable ──────────────────────────────────────────────────
if [[ $DRYRUN -eq 0 ]]; then
  chmod +x "$TARGET/init.sh" 2>/dev/null || true
  if [[ "$LEVEL" == "full" ]]; then
    chmod +x "$TARGET"/scripts/*.sh 2>/dev/null || true
  fi
fi

echo ""
if [[ $DRYRUN -eq 1 ]]; then
  echo "Dry run complete. Re-run without --dry-run to write."
  exit 0
fi

echo "Done. Next steps:"
echo "  1. Edit AGENTS.md — replace the purpose line with what this project actually does."
echo "  2. Replace the placeholder features in feature_list.json with the real backlog."
echo "  3. Confirm the verification command is right: $VERIFY_CMD"
echo "  4. Score the result:  $KIT_DIR/bin/harness-audit.sh $TARGET"
