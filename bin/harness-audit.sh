#!/usr/bin/env bash
# harness-audit.sh — Zero-dependency harness audit for AI coding agents.
#
# Usage:
#   harness-audit.sh [path/to/repo] [--json] [--strict] [--quiet]
#   curl -fsSL <raw-url>/bin/harness-audit.sh | bash -s -- /path/to/repo
#
# Exit codes:
#   0  all CRITICAL checks pass
#   1  at least one CRITICAL check fails
#   2  --strict and any check fails
#
# Design notes:
#   - Stable denominator: every check is always recorded, so scores from two
#     different repos are directly comparable. (The upstream script skipped
#     checks when a file was missing, which made totals drift 65..70.)
#   - Bilingual patterns: instruction files written in Spanish are recognised
#     as well as English ones.
#   - Every fix points at this kit, not at a third-party repository.
#
# Derived from learn-harness-engineering (MIT (c) 2025 WalkingLab),
# tools/audit-harness.sh by Stephen Kimoi. See CREDITS.md.
# Requires bash 3.2+ (stock macOS bash works).

set -euo pipefail

# Single source of truth. A constant here drifts from the VERSION file the moment
# one of the two is bumped, and then the score reports a version nobody shipped.
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "$KIT_ROOT/VERSION" 2>/dev/null || echo "unknown")"

# The rubric version travels with the score. v1 was 74 checks; v2 adds the
# Enforcement group (L13). Scores are only comparable within the same rubric, so
# an older "71/74" stays readable instead of silently competing with a new total.
RUBRIC_VERSION="v2"
REPO="."
FORMAT="text"
STRICT=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)    FORMAT="json"; shift ;;
    --strict)  STRICT=1; shift ;;
    --quiet)   QUIET=1; shift ;;
    --version) echo "harness-audit ${VERSION}"; exit 0 ;;
    -h|--help)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 64 ;;
    *)  REPO="$1"; shift ;;
  esac
done

REPO="${REPO%/}"
[[ -z "$REPO" ]] && REPO="/"
if [[ ! -d "$REPO" ]]; then
  echo "harness-audit: not a directory: $REPO" >&2
  exit 66
fi

# ── Colours: honour NO_COLOR and non-TTY output ───────────────────────────────
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]] || [[ "$FORMAT" == "json" ]]; then
  RED=""; GREEN=""; YELLOW=""; CYAN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

# ── Check registry (parallel arrays: bash 3.2 has no associative arrays) ──────
CHK_ID=(); CHK_SEV=(); CHK_GROUP=(); CHK_DESC=(); CHK_RES=(); CHK_FIX=()

record() {
  # record <id> <severity> <group> <description> <result> [fix]
  CHK_ID+=("$1"); CHK_SEV+=("$2"); CHK_GROUP+=("$3")
  CHK_DESC+=("$4"); CHK_RES+=("$5"); CHK_FIX+=("${6:-}")
}

critical()    { record "$1" critical "$CURRENT_GROUP" "$2" "$3" "${4:-}"; }
recommended() { record "$1" recommended "$CURRENT_GROUP" "$2" "$3" "${4:-}"; }

CURRENT_GROUP=""
group() { CURRENT_GROUP="$1"; }

# ── Predicates (always echo pass|fail, never fail the script) ─────────────────
file_exists() { [[ -f "$REPO/$1" ]] && echo "pass" || echo "fail"; }
dir_exists()  { [[ -d "$REPO/$1" ]] && echo "pass" || echo "fail"; }

any_file_match() {
  local pattern
  for pattern in "$@"; do
    if compgen -G "$REPO/$pattern" > /dev/null 2>&1; then
      echo "pass"; return 0
    fi
  done
  echo "fail"
}

contains_pattern() {
  # contains_pattern <relative-file> <extended-regex>
  local file="$REPO/$1" pattern="$2"
  if [[ -f "$file" ]] && grep -qiE "$pattern" "$file" 2>/dev/null; then
    echo "pass"
  else
    echo "fail"
  fi
}

instructions_path() {
  if [[ -f "$REPO/AGENTS.md" ]]; then echo "AGENTS.md"
  elif [[ -f "$REPO/CLAUDE.md" ]]; then echo "CLAUDE.md"
  else echo "AGENTS.md"; fi
}

# Search instructions plus any file it routes to under docs/. Keeps the entry
# file short (L04) without losing credit for rules documented in linked topics.
routed_contains() {
  local pattern="$1" ipath
  ipath="$(instructions_path)"
  if [[ -f "$REPO/$ipath" ]] && grep -qiE "$pattern" "$REPO/$ipath" 2>/dev/null; then
    echo "pass"; return 0
  fi
  if [[ -d "$REPO/docs" ]]; then
    if grep -rqiE "$pattern" "$REPO/docs" --include='*.md' 2>/dev/null; then
      echo "pass"; return 0
    fi
  fi
  echo "fail"
}

makefile_has_target() {
  local target="$1" f
  for f in "$REPO/Makefile" "$REPO/makefile" "$REPO/GNUmakefile"; do
    if [[ -f "$f" ]] && grep -qE "^${target}[[:space:]]*:" "$f" 2>/dev/null; then
      echo "pass"; return 0
    fi
  done
  # A package.json script of the same name counts as an equivalent task runner.
  if [[ -f "$REPO/package.json" ]] && grep -qE "\"${target}\"[[:space:]]*:" "$REPO/package.json" 2>/dev/null; then
    echo "pass"; return 0
  fi
  echo "fail"
}

feature_list_path() {
  local f
  for f in "feature_list.json" "features.json"; do
    [[ -f "$REPO/$f" ]] && { echo "$REPO/$f"; return 0; }
  done
  echo ""
}

progress_path() {
  local f
  for f in "PROGRESS.md" "progress.md" "claude-progress.md"; do
    [[ -f "$REPO/$f" ]] && { echo "$f"; return 0; }
  done
  echo "PROGRESS.md"
}

module_doc_exists() {
  # An ARCHITECTURE.md / CONSTRAINTS.md that lives NEXT TO CODE, not only at root.
  local hits
  hits="$(find "$REPO" -not -path '*/.git/*' -not -path '*/node_modules/*' \
            \( -name 'ARCHITECTURE.md' -o -name 'CONSTRAINTS.md' \) 2>/dev/null \
          | grep -v "^${REPO}/ARCHITECTURE.md$" \
          | grep -v "^${REPO}/CONSTRAINTS.md$" || true)"
  [[ -n "$hits" ]] && echo "pass" || echo "fail"
}

# ── Bilingual pattern library (ES + EN) ──────────────────────────────────────
P_WHATIS='(project|system|service|app|what|overview|this (is|repo|tool)|proyecto|sistema|servicio|aplicaci[oó]n|resumen|este (es|repo))'
P_VERIFY='(make check|npm test|pnpm test|yarn test|bun test|mix test|pytest|cargo test|go test|make test|verification|verify|verificaci[oó]n|verificar|comprobaci[oó]n)'
P_MUST='(MUST|MUST NOT|must not|must never|constraint|forbidden|never|DEBE|NO DEBE|nunca|prohibido|restricci[oó]n|obligatorio)'
P_STATEFILES='(PROGRESS|feature_list|DECISIONS|progreso|decisiones)'
P_STALE='(stale|staleness|same commit|doc.*update|update.*doc|outdated|desactualizad|mismo commit|actualiza.*doc|doc.*actualiz)'
P_ATOMIC='(atomic|one commit|same commit|partial commit|consistent.*commit|commit.*consistent|at[oó]mic|un commit|commit.*consistente)'
P_DOCLINK='(docs/[a-z])'
P_ANNOT='(source:|remove when:|why:|added because|fuente:|por qu[eé]:|motivo:|eliminar cuando:)'
P_TOOLS='(MCP|tool|permission|capability|herramienta|permiso|capacidad)'
P_PROGRESS_BODY='(in.progress|current|task|next step|blocker|completed|en curso|actual|tarea|pr[oó]ximo paso|bloqueo|completad)'
P_CURRENT_STATE='(last commit|current state|commit.*hash|test.*pass|passing.*fail|[uú]ltimo commit|estado actual|tests?.*pasan)'
P_CLOCKIN='(clock.in|session start|before touching|inicio de sesi[oó]n|antes de tocar|al empezar)'
P_CLOCKOUT='(clock.out|session end|before closing|fin de sesi[oó]n|antes de cerrar|al terminar)'
P_ANXIETY='(context.*anxi|rushed|running low|skip verif|do not rush|sin contexto|no te apresures|apresur|quedando sin)'
P_COMMITWHY='(commit.*why|why.*commit|explain why|not just what|commit.*por qu[eé]|explica.*por qu[eé]|no solo qu[eé])'
P_NEXTSTEP='(next step|next action|pr[oó]xim[oa] (paso|acci[oó]n)|siguiente paso)'
P_CONSISTENT='(make check|consistent state|exits 0|all tests pass|verification pipeline|estado consistente|sale 0|todos los tests)'
P_WIP1='(WIP.?1|one.*active|active.*at.*time|single.*active|only.*one.*active|activate.*new.*feature|new.*feature.*while.*active|una.*activa|solo una|[uú]nica.*activa)'
P_PASSGATE='(verify.feature|verification script|don.t.*state|state.*automatically|harness.*updat|pass.state|never.*set.*state.*passing|never.*edit.*state|nunca.*estado|no.*edites.*state)'
P_GRANULARITY='(one session|completable.*session|session.*complet|one feature.*session|single session|una sesi[oó]n|completable en una)'
P_STATEMACHINE='(not_started|state machine|no skipping|active.*passing|m[aá]quina de estados|sin saltar)'
P_DOD='(definition of done|feature complete|runtime evidence|code is written|all layers pass|definici[oó]n de (completado|terminado)|evidencia.*ejecuci[oó]n|evidencia ejecutable)'
P_LAYERS='(layer 1|layer 2|layer 3|syntax.*static|runtime.*behav|system.*confirm|end.to.end.*verif|capa 1|capa 2|capa 3|sint[aá]xis|comportamiento.*ejecuci[oó]n)'
P_LAYERORDER='(do not proceed|don.t proceed|layer.*fail|skip.*layer|must pass in order|in order|no avances|no contin[uú]es|en orden|saltar.*capa)'
P_RUNTIMESIG='(ready state|app.*start|startup|side effect|database write|file operation|cleanup|debug artifact|efecto.*lateral|artefacto.*depuraci[oó]n|arranque)'
P_ARCHBOUND='(architecture.*boundar|arch.*boundar|layer.*depend|enforce.*invariant|check-arch|arch.rules|l[ií]mites.*arquitect|dependencia.*capa)'
P_E2ECROSS='(cross.component|cross.domain|layer 3.*required|e2e.*required|end.to.end.*required|required.*cross|cruza.*componente|cruza.*dominio|e2e.*obligatori)'
P_PROMOTION='(code review.*automat|review.*promot|promot.*check|new.*error.*rule|catch.*review.*rule|arch.rules|revisi[oó]n.*regla|promover.*regla)'
P_OBSERV='(sprint contract|observabilit|session.trace|session-trace|runtime signal|signal collect|contrato de sprint|observabilidad|traza de sesi[oó]n)'
P_RUBRIC='(rubric|evaluator.*score|scoring.*dimension|dimension.*score|A or B|passing.*threshold|r[uú]brica|evaluador.*punt|umbral)'
P_CLEANSTATE='(clean.state|clean-state|clean_state|session exit|exit checklist|debug artifact|no.*debug|remove.*debug|estado limpio|salida de sesi[oó]n|artefacto.*debug)'
P_QUALITYDOC='(quality.doc|quality doc|quality-doc|quality score|module.*grade|module.*quality|A.*B.*C.*D|grade.*module|documento de calidad|calificaci[oó]n.*m[oó]dulo)'
P_DUALMODE='(periodic|weekly|monthly|dual.mode|immediate.*cleanup|cleanup.*periodic|regular.*sweep|periodic.*sweep|peri[oó]dic|semanal|mensual|barrido)'

IPATH="$(instructions_path)"
PPATH="$(progress_path)"
FLPATH="$(feature_list_path)"

# ═════════════════════════════════════════════════════════════════════════════
# Subsystem 1: Instructions
# ═════════════════════════════════════════════════════════════════════════════
group "Instructions"

_inst="$([[ -f "$REPO/AGENTS.md" || -f "$REPO/CLAUDE.md" ]] && echo pass || echo fail)"
critical inst.exists "AGENTS.md or CLAUDE.md exists at repo root" "$_inst" \
  "Run: harness-init.sh --target $REPO --level minimal"

critical inst.whatis "Instructions answer 'what is this system?' in the first 10 lines" \
  "$([[ -f "$REPO/$IPATH" ]] && head -10 "$REPO/$IPATH" 2>/dev/null | grep -qiE "$P_WHATIS" && echo pass || echo fail)" \
  "Add a one-line description of the system at the top of $IPATH."

critical inst.verify "Verification command is listed in the instructions file" \
  "$(routed_contains "$P_VERIFY")" \
  "Add a Verification section to $IPATH naming the exact command (e.g. 'make check')."

recommended inst.must "Hard constraints (MUST / MUST NOT) are stated" \
  "$(routed_contains "$P_MUST")" \
  "Add a Constraints section to $IPATH with explicit MUST / MUST NOT rules."

recommended inst.statefiles "State files are enumerated (PROGRESS, feature_list, DECISIONS)" \
  "$(routed_contains "$P_STATEFILES")" \
  "Reference PROGRESS.md, DECISIONS.md and feature_list.json in $IPATH so agents know where state lives."

recommended inst.stale "Documentation staleness rule present" \
  "$(routed_contains "$P_STALE")" \
  "Add to $IPATH: 'Update docs in the same commit as the code change — no stale documentation.'"

recommended inst.atomic "Commit atomicity rule present" \
  "$(routed_contains "$P_ATOMIC")" \
  "Add to $IPATH: 'One logical operation per commit; the repo stays consistent after every commit.'"

_ilines=999
[[ -f "$REPO/$IPATH" ]] && _ilines="$(wc -l < "$REPO/$IPATH" | tr -d ' ')"
recommended inst.short "Entry file is <= 200 lines (router, not encyclopedia)" \
  "$([[ "$_ilines" -le 200 ]] && echo pass || echo fail)" \
  "$IPATH is $_ilines lines — move detail into docs/ topic files and link to them."

recommended inst.links "Entry file links to topic documents in docs/" \
  "$(contains_pattern "$IPATH" "$P_DOCLINK")" \
  "Link topic docs from $IPATH, e.g. 'See [Architecture](docs/architecture.md)'."

recommended inst.annot "Constraints carry source/why annotations" \
  "$(routed_contains "$P_ANNOT")" \
  "Annotate each constraint with 'why:' or 'source:' so agents know the reason it exists."

recommended inst.moduledoc "Module-level doc (ARCHITECTURE.md / CONSTRAINTS.md) co-located with code" \
  "$(module_doc_exists)" \
  "Create src/ARCHITECTURE.md (or equivalent) describing that module's design near the code it governs."

# ═════════════════════════════════════════════════════════════════════════════
# Subsystem 2: Tools
# ═════════════════════════════════════════════════════════════════════════════
group "Tools"

recommended tools.scoped "Tool access is scoped (settings.json / .claude/ / MCP config)" \
  "$(any_file_match ".claude/settings.json" ".claude/settings.local.json" "mcp.json" ".mcp.json" ".cursor/mcp.json" ".codex/config.toml")" \
  "Create .claude/settings.json (or .mcp.json) to scope which tools the agent may use."

recommended tools.documented "Tool / MCP integrations documented in the instructions" \
  "$(routed_contains "$P_TOOLS")" \
  "Add a Tools section to $IPATH listing available integrations and their permitted capabilities."

# ═════════════════════════════════════════════════════════════════════════════
# Subsystem 3: Environment
# ═════════════════════════════════════════════════════════════════════════════
group "Environment"

# A repo with no dependency manifest has nothing to lock — installs are already
# trivially reproducible, so the check passes rather than penalising shell-only tools.
_has_manifest="$(any_file_match "package.json" "pyproject.toml" "requirements.txt" "Cargo.toml" "go.mod" "Gemfile" "mix.exs" "composer.json")"
_has_lock="$(any_file_match "package-lock.json" "yarn.lock" "pnpm-lock.yaml" "bun.lock" "bun.lockb" "mix.lock" "Pipfile.lock" "poetry.lock" "uv.lock" "requirements.txt" "Cargo.lock" "go.sum" "Gemfile.lock" "composer.lock")"
if [[ "$_has_manifest" == "fail" ]]; then
  critical env.lockfile "Dependency lockfile present (no manifest — nothing to lock)" "pass" ""
else
  critical env.lockfile "Dependency lockfile present" "$_has_lock" \
    "Commit a dependency lockfile so installs are reproducible from any checkout."
fi

recommended env.runtime "Runtime version pinned (.nvmrc / .tool-versions / .python-version)" \
  "$(any_file_match ".tool-versions" ".nvmrc" ".node-version" ".python-version" ".ruby-version" ".java-version" "rust-toolchain.toml")" \
  "Pin the runtime: echo '22' > $REPO/.nvmrc (or .python-version / .tool-versions)."

recommended env.taskrunner "Task runner present (Makefile / package.json / justfile)" \
  "$(any_file_match "Makefile" "makefile" "package.json" "mix.exs" "justfile" "Taskfile.yml")" \
  "Add a Makefile so every repo operation is a single command."

recommended env.setup "Single-command setup target exists" \
  "$(makefile_has_target "setup")" \
  "Add a 'setup:' target that installs all dependencies from a clean checkout."

recommended env.dev "Single-command dev target exists" \
  "$(makefile_has_target "dev")" \
  "Add a 'dev:' target that starts the local dev server."

recommended env.init "Standard startup script (init.sh) present" \
  "$(any_file_match "init.sh" "bin/init.sh" "scripts/init.sh")" \
  "Add init.sh — install, verify, print the start command. Provided by harness-init.sh."

# ═════════════════════════════════════════════════════════════════════════════
# Subsystem 4: State
# ═════════════════════════════════════════════════════════════════════════════
group "State"

critical state.progress "PROGRESS.md exists at repo root" \
  "$(file_exists "$PPATH")" \
  "Create PROGRESS.md with sections: Current State, In Progress, Next Steps, Blockers."

recommended state.progress_body "PROGRESS.md references current task / in-progress work" \
  "$(contains_pattern "$PPATH" "$P_PROGRESS_BODY")" \
  "Add an '## In Progress' section to $PPATH describing the current task."

recommended state.decisions "DECISIONS.md or docs/decisions/ exists" \
  "$(any_file_match "DECISIONS.md" "docs/decisions" "docs/adr")" \
  "Create DECISIONS.md to log architectural decisions and their rationale."

recommended state.featurelist "feature_list.json (or equivalent) exists" \
  "$(any_file_match "feature_list.json" "features.json")" \
  "Create feature_list.json — one entry per feature with id, behavior, verification, state."

recommended state.fl_fields "feature_list entries have id / behavior / verification / state" \
  "$([[ -n "$FLPATH" ]] \
      && grep -qE '"id"' "$FLPATH" 2>/dev/null \
      && grep -qE '"behavior"' "$FLPATH" 2>/dev/null \
      && grep -qE '"verification"' "$FLPATH" 2>/dev/null \
      && grep -qE '"state"' "$FLPATH" 2>/dev/null \
      && echo pass || echo fail)" \
  "Each feature_list entry needs the fields: id, behavior, verification, state."

# ═════════════════════════════════════════════════════════════════════════════
# Subsystem 5: Feedback
# ═════════════════════════════════════════════════════════════════════════════
group "Feedback"

recommended fb.check "Task runner has a 'check' target (full verification pipeline)" \
  "$(makefile_has_target "check")" \
  "Add a 'check:' target running lint + tests. This is the single command agents use to prove the repo is green."

recommended fb.test "Task runner has a 'test' target" \
  "$(makefile_has_target "test")" \
  "Add a 'test:' target (e.g. 'test: npm test')."

critical fb.documented "Verification command documented in the instructions file" \
  "$(routed_contains "$P_VERIFY")" \
  "Add to $IPATH: 'Run \`make check\` — it must exit 0 before every commit.'"

# ═════════════════════════════════════════════════════════════════════════════
# L05: Cross-session continuity
# ═════════════════════════════════════════════════════════════════════════════
group "Continuity (L05)"

critical cont.currentstate "PROGRESS.md has a Current State block (commit + test status)" \
  "$(contains_pattern "$PPATH" "$P_CURRENT_STATE")" \
  "Add to $PPATH: '## Current State — Last commit: abc1234 | make check: passing'. Update it at every clock-out."

recommended cont.clockin "Clock-in routine documented (read PROGRESS, run check)" \
  "$(routed_contains "$P_CLOCKIN")" \
  "Add a Clock-in section to $IPATH: 'Before touching code: read PROGRESS.md, then run make check.'"

recommended cont.clockout "Clock-out routine documented (update PROGRESS, commit)" \
  "$(routed_contains "$P_CLOCKOUT")" \
  "Add a Clock-out section to $IPATH: 'Before closing: update PROGRESS.md, run make check, commit.'"

recommended cont.anxiety "Context-anxiety / rushed-finish warning present" \
  "$(routed_contains "$P_ANXIETY")" \
  "Add to $IPATH: 'If running low on context, do NOT rush — stop, update PROGRESS.md, commit a clean checkpoint.'"

recommended cont.commitwhy "Commit message guidance (explain why, not just what)" \
  "$(routed_contains "$P_COMMITWHY")" \
  "Add to $IPATH: 'Commit messages explain WHY the change was made, not just what changed.'"

recommended cont.nextstep "PROGRESS.md has a Next Steps section" \
  "$(contains_pattern "$PPATH" "$P_NEXTSTEP")" \
  "Add '## Next Steps' to $PPATH with specific actionable items."

recommended cont.handoff "session-handoff.md present for multi-session work" \
  "$(any_file_match "session-handoff.md" "SESSION-HANDOFF.md" "docs/session-handoff.md")" \
  "Add session-handoff.md so a fresh session can resume without reading chat history."

# ═════════════════════════════════════════════════════════════════════════════
# L03: Repository as system of record
# ═════════════════════════════════════════════════════════════════════════════
group "System of Record (L03)"

recommended sor.durability "Durability: PROGRESS + DECISIONS both tracked in the repo" \
  "$([[ -f "$REPO/$PPATH" ]] && { [[ -f "$REPO/DECISIONS.md" ]] || [[ -d "$REPO/docs/decisions" ]] || [[ -d "$REPO/docs/adr" ]]; } && echo pass || echo fail)" \
  "Both PROGRESS.md and DECISIONS.md must exist so cross-session knowledge outlives any context window."

recommended sor.consistency "Consistency: a verifiable consistent-state predicate is documented" \
  "$(routed_contains "$P_CONSISTENT")" \
  "Document the predicate in $IPATH: 'The repo is consistent when \`make check\` exits 0.'"

recommended sor.atomicity "Atomicity: commit atomicity rule stated" \
  "$(routed_contains "$P_ATOMIC")" \
  "State in $IPATH: 'Each commit is one complete logical change; no partial work.'"

# ═════════════════════════════════════════════════════════════════════════════
# L07: WIP=1 and verified completion ratio
# ═════════════════════════════════════════════════════════════════════════════
group "Scope Control (L07)"

recommended wip.rule "WIP=1 rule present (one active feature at a time)" \
  "$(routed_contains "$P_WIP1")" \
  "Add to $IPATH: 'Only one feature may be active at a time. Finish it before activating the next.'"

recommended wip.vcrtarget "'vcr' target exists (verified completion ratio)" \
  "$(makefile_has_target "vcr")" \
  "Add a 'vcr:' target printing passing features / activated features."

_vcr_res="fail"; _vcr_desc="VCR: no feature_list found, ratio cannot be computed"
if [[ -n "$FLPATH" ]]; then
  _va=0; _vp=0
  _va="$(grep -c '"state"[[:space:]]*:[[:space:]]*"active"' "$FLPATH" 2>/dev/null || echo 0)"
  _vp="$(grep -c '"state"[[:space:]]*:[[:space:]]*"passing"' "$FLPATH" 2>/dev/null || echo 0)"
  _va="$(echo "$_va" | tr -d ' \n')"; _vp="$(echo "$_vp" | tr -d ' \n')"
  _vtot=$(( _va + _vp ))
  if [[ "$_vtot" -eq 0 ]]; then
    _vcr_res="pass"; _vcr_desc="VCR: no activated features yet (clean slate)"
  elif [[ "$_va" -gt 0 ]]; then
    _vcr_res="fail"; _vcr_desc="VCR = ${_vp}/${_vtot} — ${_va} active feature(s) not yet passing"
  else
    _vcr_res="pass"; _vcr_desc="VCR = ${_vp}/${_vtot} = 1.0 — all activated features are passing"
  fi
fi
recommended wip.vcr "$_vcr_desc" "$_vcr_res" \
  "Drive every active feature to passing (with evidence) before activating another."

# ═════════════════════════════════════════════════════════════════════════════
# L08: Feature list as a harness primitive
# ═════════════════════════════════════════════════════════════════════════════
group "Feature List (L08)"

recommended fl.evidence "feature_list entries have an 'evidence' field" \
  "$([[ -n "$FLPATH" ]] && grep -q '"evidence"' "$FLPATH" 2>/dev/null && echo pass || echo fail)" \
  "Add 'evidence' to every entry, e.g. \"evidence\": \"commit abc1234, make check green 2026-08-05\"."

recommended fl.script "scripts/verify-feature.sh present" \
  "$(any_file_match "scripts/verify-feature.sh")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended fl.target "'verify-feature' target exists" \
  "$(makefile_has_target "verify-feature")" \
  "Add 'verify-feature:' running 'bash scripts/verify-feature.sh \$(F)'. Usage: make verify-feature F=F02"

recommended fl.gating "Pass-state gating documented (never hand-edit state to passing)" \
  "$(routed_contains "$P_PASSGATE")" \
  "Add to $IPATH: 'Never set state to passing by hand — run make verify-feature F=<id>.'"

recommended fl.granularity "Feature granularity rule documented (one session per feature)" \
  "$(routed_contains "$P_GRANULARITY")" \
  "Add to $IPATH: 'Each feature must be completable in one session. If it spans sessions, split it.'"

recommended fl.statemachine "State machine documented (not_started -> active -> passing)" \
  "$(routed_contains "$P_STATEMACHINE")" \
  "Document the state machine in $IPATH and note that skipping states is not allowed."

# ═════════════════════════════════════════════════════════════════════════════
# L09: Preventing premature completion
# ═════════════════════════════════════════════════════════════════════════════
group "Completion Gates (L09)"

recommended done.dod "Definition of Done section present" \
  "$(routed_contains "$P_DOD")" \
  "Add a Definition of Done to $IPATH: 'Complete means runtime evidence passed — not that code was written.'"

recommended done.layers "Three-layer verification model documented" \
  "$(routed_contains "$P_LAYERS")" \
  "Document Layer 1 (static), Layer 2 (runtime behaviour), Layer 3 (end-to-end) in $IPATH."

recommended done.order "Layer ordering rule documented (do not skip layers)" \
  "$(routed_contains "$P_LAYERORDER")" \
  "Add to $IPATH: 'Do not proceed to Layer N+1 while Layer N fails.'"

recommended done.signals "Runtime signals documented (startup, side effects, debug artifacts)" \
  "$(routed_contains "$P_RUNTIMESIG")" \
  "List runtime signals in $IPATH: app reaches ready state, side effects correct, no debug artifacts left."

recommended done.fl_layers "feature_list uses layers with repair instructions" \
  "$([[ -n "$FLPATH" ]] && grep -q '"layers"' "$FLPATH" 2>/dev/null && grep -q '"repair"' "$FLPATH" 2>/dev/null && echo pass || echo fail)" \
  "Give each entry a 'layers' array; every layer needs label, cmd and repair."

recommended done.repair "verify-feature.sh runs layers and prints repair guidance" \
  "$(grep -qE 'repair|run_layer|How to fix' "$REPO/scripts/verify-feature.sh" 2>/dev/null && echo pass || echo fail)" \
  "Install the kit's verify-feature.sh: harness-init.sh --target $REPO --level full"

# ═════════════════════════════════════════════════════════════════════════════
# L10: E2E testing and architectural boundaries
# ═════════════════════════════════════════════════════════════════════════════
group "Architecture (L10)"

recommended arch.e2etarget "'e2e' target exists" \
  "$(makefile_has_target "e2e")" \
  "Add an 'e2e:' target running your end-to-end suite (playwright / pytest tests/e2e)."

recommended arch.checktarget "'check-arch' target exists" \
  "$(makefile_has_target "check-arch")" \
  "Add 'check-arch:' running 'bash scripts/check-arch.sh'."

recommended arch.script "scripts/check-arch.sh present" \
  "$(any_file_match "scripts/check-arch.sh")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended arch.rules ".harness/arch-rules.json present" \
  "$(any_file_match ".harness/arch-rules.json")" \
  "Create .harness/arch-rules.json. Every code-review finding becomes a rule here."

recommended arch.whatwhyfix "Arch rules use the WHAT / WHY / FIX error format" \
  "$([[ -f "$REPO/.harness/arch-rules.json" ]] \
      && grep -q '"what"' "$REPO/.harness/arch-rules.json" 2>/dev/null \
      && grep -q '"why"' "$REPO/.harness/arch-rules.json" 2>/dev/null \
      && grep -q '"fix"' "$REPO/.harness/arch-rules.json" 2>/dev/null \
      && echo pass || echo fail)" \
  "Each rule needs what / why / fix with agent-actionable text naming the file or symbol to change."

recommended arch.documented "Architecture Boundaries section present in the instructions" \
  "$(routed_contains "$P_ARCHBOUND")" \
  "Describe your layer model in $IPATH and note that 'make check-arch' enforces it."

recommended arch.e2ecross "E2E requirement for cross-component changes documented" \
  "$(routed_contains "$P_E2ECROSS")" \
  "Add to $IPATH: 'Layer 3 (e2e) is required when a change crosses component or domain boundaries.'"

recommended arch.promotion "Review-to-automation promotion principle documented" \
  "$(routed_contains "$P_PROMOTION")" \
  "Add to $IPATH: 'Every new error category caught in review becomes a rule in .harness/arch-rules.json.'"

# ═════════════════════════════════════════════════════════════════════════════
# L11: Observability inside the harness
# ═════════════════════════════════════════════════════════════════════════════
group "Observability (L11)"

recommended obs.sprint "templates/sprint-contract.md present" \
  "$(any_file_match "templates/sprint-contract.md" "docs/sprint-contract.md")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended obs.rubric "templates/evaluator-rubric.md present" \
  "$(any_file_match "templates/evaluator-rubric.md" "docs/evaluator-rubric.md")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended obs.trace "scripts/session-trace.sh present" \
  "$(any_file_match "scripts/session-trace.sh")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended obs.traces ".harness/traces/ directory present" \
  "$(dir_exists ".harness/traces")" \
  "Create .harness/traces/ with a .gitkeep, and gitignore traces.jsonl (runtime artifact, not source)."

recommended obs.documented "Observability / sprint-contract protocol documented" \
  "$(routed_contains "$P_OBSERV")" \
  "Add an Observability section to $IPATH: sprint contract before, session-trace during, rubric after."

recommended obs.rubricref "Evaluator rubric referenced in the instructions" \
  "$(routed_contains "$P_RUBRIC")" \
  "Reference the rubric in $IPATH: 'Score each sprint against templates/evaluator-rubric.md — every dimension B or above.'"

recommended obs.sessiontarget "'session-start' target present" \
  "$(makefile_has_target "session-start")" \
  "Add session-start and session-end targets wrapping scripts/session-trace.sh."

# ═════════════════════════════════════════════════════════════════════════════
# L12: Clean state protocol
# ═════════════════════════════════════════════════════════════════════════════
group "Clean State (L12)"

recommended clean.checklist "clean-state-checklist.md present" \
  "$(any_file_match "templates/clean-state-checklist.md" "clean-state-checklist.md" "docs/clean-state-checklist.md")" \
  "Install it: harness-init.sh --target $REPO --level minimal"

recommended clean.script "scripts/clean-state-check.sh present" \
  "$(any_file_match "scripts/clean-state-check.sh")" \
  "Install it: harness-init.sh --target $REPO --level full"

recommended clean.target "'clean-check' target present" \
  "$(makefile_has_target "clean-check")" \
  "Add 'clean-check:' running 'bash scripts/clean-state-check.sh .' — agents run it at clock-out."

recommended clean.documented "Clean-state / session-exit checklist referenced in the instructions" \
  "$(routed_contains "$P_CLEANSTATE")" \
  "Reference it in the Clock-out section of $IPATH: 'Run make clean-check before committing.'"

recommended clean.qualitydoc "Quality document present (module health scores)" \
  "$(any_file_match "docs/quality-document.md" "templates/quality-document.md" "QUALITY.md" "docs/QUALITY_SCORE.md")" \
  "Create docs/quality-document.md scoring each module A/B/C/D so new sessions know where to prioritise."

recommended clean.qualityref "Quality document referenced in the instructions" \
  "$(routed_contains "$P_QUALITYDOC")" \
  "Reference it in $IPATH clock-out: 'Update docs/quality-document.md for the module you touched.'"

recommended clean.dualmode "Dual-mode cleanup documented (immediate + periodic sweep)" \
  "$(routed_contains "$P_DUALMODE")" \
  "Document both modes in $IPATH: cleanup at every session end + a periodic full-system sweep."

# ═════════════════════════════════════════════════════════════════════════════
# L13: Enforcement — is the verdict out of the agent's reach?
# Everything above measures what the repository *says*. This group measures what
# it can still *do* when an agent decides to write "passing" by hand.
# ═════════════════════════════════════════════════════════════════════════════
group "Enforcement (L13)"

WF_PATH=".github/workflows/required-quality.yml"

actions_pinned() {
  # Every `uses:` must end in a 40-hex SHA. A tag can be repointed at other code.
  local f="$REPO/$WF_PATH"
  [[ -f "$f" ]] || { echo "fail"; return; }
  if grep -E '^[[:space:]]*uses:' "$f" 2>/dev/null \
     | grep -qvE 'uses:[[:space:]]*[^[:space:]]+@[0-9a-f]{40}[[:space:]]*(#.*)?$'; then
    echo "fail"
  else
    echo "pass"
  fi
}

budgets_have_stop() {
  # Shell-only JSON heuristic: every "budgets" block needs its own
  # "stop_condition", plus one for the "budget_defaults" template if present.
  local fl b s d
  fl="$(feature_list_path)"
  [[ -n "$fl" ]] || { echo "fail"; return; }
  b="$(grep -c '"budgets"' "$fl" 2>/dev/null || echo 0)"
  [[ "$b" -eq 0 ]] && { echo "fail"; return; }
  s="$(grep -c '"stop_condition"' "$fl" 2>/dev/null || echo 0)"
  d="$(grep -c '"budget_defaults"' "$fl" 2>/dev/null || echo 0)"
  [[ "$s" -ge $((b + d)) ]] && echo "pass" || echo "fail"
}

recommended enf.claims "Claim re-verifier present (scripts/verify-claims.sh)" \
  "$(file_exists "scripts/verify-claims.sh")" \
  "Install it: harness-init.sh --target $REPO --level full. Without it, a hand-written 'passing' is never re-checked."

recommended enf.claimstarget "'verify-claims' target exists" \
  "$(makefile_has_target "verify-claims")" \
  "Add 'verify-claims:' running 'bash scripts/verify-claims.sh'."

recommended enf.workflow "Required-quality workflow present" \
  "$(file_exists "$WF_PATH")" \
  "Install it: harness-init.sh --target $REPO --level full, then make the check required."

recommended enf.pinned "Workflow actions pinned to 40-hex SHAs" \
  "$(actions_pinned)" \
  "Replace every 'uses: owner/action@vN' with its 40-hex commit SHA. A tag can be moved to other code."

recommended enf.ruleset "Workflow-integrity ruleset payload present" \
  "$(file_exists ".github/rulesets/required-quality-integrity.json")" \
  "GitHub counts a job skipped by its own condition as a PASSING required check. Ship the push ruleset and install it with bin/harness-protect.sh."

recommended enf.budgets "Features declare anti-loop budgets" \
  "$(contains_pattern "$(feature_list_path | sed "s|^$REPO/||")" '"budgets"')" \
  "Give each feature a 'budgets' block: review_rounds_max, repeated_blocker_max, stop_condition."

recommended enf.stopcond "Every budget declares its stop condition" \
  "$(budgets_have_stop)" \
  "A budget with no stop_condition just restarts the loop when it runs out. Add stop_condition to every budgets block."

recommended enf.decisions "Decision ledger verifier present (scripts/verify-decisions.sh)" \
  "$(file_exists "scripts/verify-decisions.sh")" \
  "Install it: harness-init.sh --target $REPO --level full. Without it, an agent can delete the decision that blocked its approach."

recommended enf.decdoc "Append-only decision rule documented" \
  "$(routed_contains '(append.only|DECISION_REWRITE|supersede|no editar.*decisi|never edit an earlier)')" \
  "Add to $IPATH: DECISIONS.md is append-only — supersede an entry by adding a new one, never by editing it."

recommended enf.wfdoc "Workflow-tampering rule documented" \
  "$(routed_contains '(required-quality\.yml|skipped by its own|skip.*the gate)')" \
  "Add to $IPATH: agents must never edit .github/workflows/required-quality.yml — a skipped job counts as a passing check."

# ═════════════════════════════════════════════════════════════════════════════
# Reporting
# ═════════════════════════════════════════════════════════════════════════════
CP=0; CF=0; RP=0; RF=0
for i in "${!CHK_ID[@]}"; do
  if [[ "${CHK_SEV[$i]}" == "critical" ]]; then
    [[ "${CHK_RES[$i]}" == "pass" ]] && CP=$((CP+1)) || CF=$((CF+1))
  else
    [[ "${CHK_RES[$i]}" == "pass" ]] && RP=$((RP+1)) || RF=$((RF+1))
  fi
done
TOTAL_PASS=$((CP + RP))
TOTAL=$((CP + CF + RP + RF))

json_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g'
}

if [[ "$FORMAT" == "json" ]]; then
  printf '{\n'
  printf '  "version": "%s",\n' "$VERSION"
  printf '  "rubric_version": "%s",\n' "$RUBRIC_VERSION"
  printf '  "repo": "%s",\n' "$(json_escape "$REPO")"
  printf '  "score": { "passed": %d, "total": %d, "critical_passed": %d, "critical_total": %d, "recommended_passed": %d, "recommended_total": %d },\n' \
    "$TOTAL_PASS" "$TOTAL" "$CP" "$((CP+CF))" "$RP" "$((RP+RF))"
  printf '  "checks": [\n'
  for i in "${!CHK_ID[@]}"; do
    printf '    { "id": "%s", "severity": "%s", "group": "%s", "description": "%s", "result": "%s", "fix": "%s" }' \
      "$(json_escape "${CHK_ID[$i]}")" "${CHK_SEV[$i]}" "$(json_escape "${CHK_GROUP[$i]}")" \
      "$(json_escape "${CHK_DESC[$i]}")" "${CHK_RES[$i]}" "$(json_escape "${CHK_FIX[$i]}")"
    [[ $i -lt $(( ${#CHK_ID[@]} - 1 )) ]] && printf ',\n' || printf '\n'
  done
  printf '  ]\n}\n'
else
  echo "${BOLD}Harness Audit${RESET} v${VERSION}"
  echo "Repo: ${REPO}"
  if [[ "$QUIET" -eq 0 ]]; then
    _last_group=""
    for i in "${!CHK_ID[@]}"; do
      if [[ "${CHK_GROUP[$i]}" != "$_last_group" ]]; then
        printf '\n%s%s%s\n' "$CYAN$BOLD" "${CHK_GROUP[$i]}" "$RESET"
        _last_group="${CHK_GROUP[$i]}"
      fi
      if [[ "${CHK_RES[$i]}" == "pass" ]]; then
        printf '  %s[PASS]%s %s\n' "$GREEN" "$RESET" "${CHK_DESC[$i]}"
      elif [[ "${CHK_SEV[$i]}" == "critical" ]]; then
        printf '  %s[FAIL]%s %s\n' "$RED" "$RESET" "${CHK_DESC[$i]}"
      else
        printf '  %s[WARN]%s %s\n' "$YELLOW" "$RESET" "${CHK_DESC[$i]}"
      fi
    done
  fi

  echo ""
  echo "${BOLD}────────────────────────────────────────${RESET}"
  printf '%sScore%s  %d / %d harness components present (rubric %s)\n' \
    "$BOLD" "$RESET" "$TOTAL_PASS" "$TOTAL" "$RUBRIC_VERSION"
  printf '  Critical:    %d / %d\n' "$CP" "$((CP+CF))"
  printf '  Recommended: %d / %d\n' "$RP" "$((RP+RF))"
  echo "${BOLD}────────────────────────────────────────${RESET}"

  if [[ $((CF + RF)) -gt 0 ]]; then
    echo ""
    echo "${BOLD}What to fix${RESET}"
    for i in "${!CHK_ID[@]}"; do
      [[ "${CHK_RES[$i]}" == "pass" ]] && continue
      [[ -z "${CHK_FIX[$i]}" ]] && continue
      if [[ "${CHK_SEV[$i]}" == "critical" ]]; then
        printf '  %s[CRITICAL]%s %s\n' "$RED" "$RESET" "${CHK_FIX[$i]}"
      else
        printf '  %s[recommended]%s %s\n' "$YELLOW" "$RESET" "${CHK_FIX[$i]}"
      fi
    done
  fi

  echo ""
  if [[ $CF -gt 0 ]]; then
    printf '%sCRITICAL items are missing. Fix these before running long agent sessions.%s\n' "$RED$BOLD" "$RESET"
  else
    printf '%sAll CRITICAL harness components are present.%s\n' "$GREEN$BOLD" "$RESET"
  fi
fi

if [[ $CF -gt 0 ]]; then exit 1; fi
if [[ $STRICT -eq 1 && $RF -gt 0 ]]; then exit 2; fi
exit 0
