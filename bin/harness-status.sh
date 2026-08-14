#!/usr/bin/env bash
# harness-status.sh — what is actually enforced here, right now.
#
# Usage:
#   bin/harness-status.sh [--target DIR]
#
# The audit score answers "how complete is the harness?". This answers the
# question you actually have before trusting it: does anything stop a bad change
# from merging, or is it all on the honour system?
#
# States:
#   READY_DUAL     local gate + required check + the workflow itself protected
#   READY_PARTIAL  local gate + required check, but the workflow can be edited
#   READY_LOCAL    the harness runs locally; nothing on GitHub blocks a merge
#   BLOCKED_TOOL   something required to verify is missing or broken
#   NOT_ACTIVATED  no harness here yet
#
# Exit codes: 0 when activated (any READY_*), 1 otherwise. So CI or a hook can
# branch on it without parsing text.

set -uo pipefail

TARGET="."
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) TARGET="$1"; shift ;;
  esac
done
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "harness-status: no such directory" >&2; exit 64; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

say()  { printf '%s\n' "$1"; }
line() { printf '  %-4s %s\n' "$1" "$2"; }

# ── Local layer ──────────────────────────────────────────────────────────────
if [[ ! -f "$TARGET/AGENTS.md" ]] || [[ ! -f "$TARGET/feature_list.json" ]]; then
  say "${BOLD}NOT_ACTIVATED${RESET} — no hay harness en $(basename "$TARGET")."
  say ""
  say "Actívalo con:  bin/harness-activate.sh --target $TARGET"
  exit 1
fi

HAS_CLAIMS=0;   [[ -f "$TARGET/scripts/verify-claims.sh" ]]    && HAS_CLAIMS=1
HAS_DEC=0;      [[ -f "$TARGET/scripts/verify-decisions.sh" ]] && HAS_DEC=1
HAS_WF=0;       [[ -f "$TARGET/.github/workflows/required-quality.yml" ]] && HAS_WF=1

# ── Remote ───────────────────────────────────────────────────────────────────
SLUG=""
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  URL="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  if [[ -n "$URL" ]]; then
    SLUG="$(printf '%s' "$URL" \
      | sed -e 's#^git@[^:]*:##' -e 's#^https\{0,1\}://[^/]*/##' -e 's#\.git$##')"
  fi
fi

# ── Hosted layer: ask GitHub rather than assume ──────────────────────────────
CHECK_RULE=""; INTEGRITY_RULE=""
GH_OK=0
if [[ -n "$SLUG" ]] && command -v gh >/dev/null 2>&1; then
  if RULESETS="$(gh api "repos/$SLUG/rulesets" --jq '.[] | "\(.name)|\(.enforcement)"' 2>/dev/null)"; then
    GH_OK=1
    CHECK_RULE="$(printf '%s\n' "$RULESETS" | grep '^required-quality-check|active' || true)"
    INTEGRITY_RULE="$(printf '%s\n' "$RULESETS" | grep '^required-quality-workflow-integrity|active' || true)"
  fi
fi

# ── Verdict ──────────────────────────────────────────────────────────────────
if [[ -n "$CHECK_RULE" && -n "$INTEGRITY_RULE" ]]; then
  STATE="READY_DUAL"
elif [[ -n "$CHECK_RULE" ]]; then
  STATE="READY_PARTIAL"
else
  STATE="READY_LOCAL"
fi

case "$STATE" in
  READY_DUAL)    say "${GREEN}${BOLD}READY_DUAL${RESET} — un cambio malo no puede fusionarse." ;;
  READY_PARTIAL) say "${YELLOW}${BOLD}READY_PARTIAL${RESET} — la compuerta bloquea, pero no se protege a sí misma." ;;
  READY_LOCAL)   say "${YELLOW}${BOLD}READY_LOCAL${RESET} — todavía nada en GitHub bloquea una fusión." ;;
esac

say ""
say "${BOLD}Local${RESET}"
line "ok" "contrato, estado y presupuestos"
[[ $HAS_CLAIMS -eq 1 ]] && line "ok" "re-verificador de afirmaciones (verify-claims.sh)" \
                        || line "--" "sin re-verificador: un 'passing' escrito a mano nunca se recomprueba"
[[ $HAS_DEC -eq 1 ]]    && line "ok" "ledger de decisiones (solo se agrega)" \
                        || line "--" "sin verificación del ledger de decisiones"

say ""
say "${BOLD}GitHub${RESET}"
if [[ -z "$SLUG" ]]; then
  line "--" "sin remoto — el veredicto queda por completo en confianza"
elif [[ $GH_OK -eq 0 ]]; then
  line "?" "$SLUG — no se pudieron leer los rulesets (gh sin auth, o sin acceso)"
else
  [[ $HAS_WF -eq 1 ]] && line "ok" "workflow presente" || line "--" "sin workflow de calidad requerida"
  [[ -n "$CHECK_RULE" ]] && line "ok" "compuerta requerida activa en $SLUG" \
                         || line "--" "sin ruleset de compuerta: CI reporta pero nada bloquea"
  [[ -n "$INTEGRITY_RULE" ]] && line "ok" "workflow protegido contra ediciones" \
                             || line "--" "workflow SIN proteger — un 'if: false' en el job se fusiona en verde"
fi

say ""
case "$STATE" in
  READY_DUAL)
    say "Siguiente: nada. Abre un PR que rompa un test si quieres verlo negarse." ;;
  READY_PARTIAL)
    say "${BOLD}Qué significa:${RESET} los tests rotos y los estados 'passing' escritos a mano"
    say "quedan bloqueados. Editar el workflow no: GitHub sólo permite push rules en"
    say "repositorios de organización. Revisa a mano cualquier PR que toque"
    say ".github/workflows/, o mueve el repo a una organización para cerrarlo." ;;
  READY_LOCAL)
    if [[ -z "$SLUG" ]]; then
      say "Siguiente: súbelo a GitHub y corre bin/harness-protect.sh para hacer vinculante la compuerta."
    else
      say "Siguiente: bin/harness-protect.sh $SLUG"
    fi ;;
esac

exit 0
