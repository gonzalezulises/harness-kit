#!/usr/bin/env bash
# harness-activate.sh — one command between "new repo" and "governed repo".
#
# Usage:
#   bin/harness-activate.sh [--target DIR] [--with gherkin] [--yes] [--dry-run]
#
# Scaffolding, wiring the remote, and installing rulesets were eight manual steps.
# The step people skipped was replacing the placeholder features, and a harness
# with placeholder features is decoration — so this ends by telling you exactly
# what is still yours to do, instead of printing "done".
#
# It asks once, before touching anything, and then proceeds without further
# questions. It never overwrites an existing file: re-running it on a configured
# repository is safe and only fills gaps.

set -uo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="."
WITH_GHERKIN=0
ASSUME_YES=0
DRYRUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)  TARGET="$2"; shift 2 ;;
    # Un pack mal escrito instalaba nada y no decía nada: quien pedía --with sentry
    # se iba creyendo que el pack estaba puesto. Un flag que se descarta en silencio
    # es peor que uno que no existe.
    --with)
      case "${2:-}" in
        gherkin) WITH_GHERKIN=1 ;;
        "") echo "harness-activate: --with necesita el nombre de un pack" >&2; exit 64 ;;
        *) echo "harness-activate: pack desconocido '$2'" >&2
           echo "  Sólo 'gherkin' se instala con --with." >&2
           echo "  Los demás (sentry, load-testing, openai-advanced) se copian a mano" >&2
           echo "  desde packs/<nombre>/repo-template/ y se verifican con su verify-pack.sh." >&2
           exit 64 ;;
      esac
      shift 2 ;;
    --yes|-y)  ASSUME_YES=1; shift ;;
    --dry-run) DRYRUN=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *)         TARGET="$1"; shift ;;
  esac
done

TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || { echo "harness-activate: no such directory" >&2; exit 64; }

if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; YELLOW=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
  BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

# ── What is this, and where does it live? ────────────────────────────────────
NAME="$(basename "$TARGET")"

STACK="proyecto genérico"
VERIFY="make check"
if [[ -f "$TARGET/package.json" ]]; then
  PM="npm"
  [[ -f "$TARGET/pnpm-lock.yaml" ]] && PM="pnpm"
  [[ -f "$TARGET/yarn.lock" ]] && PM="yarn"
  { [[ -f "$TARGET/bun.lockb" ]] || [[ -f "$TARGET/bun.lock" ]]; } && PM="bun"
  STACK="JavaScript/TypeScript + $PM"
  [[ -f "$TARGET/next.config.js" || -f "$TARGET/next.config.ts" || -f "$TARGET/next.config.mjs" ]] \
    && STACK="Next.js + $PM"
  VERIFY="$PM run check"
elif [[ -f "$TARGET/pyproject.toml" || -f "$TARGET/requirements.txt" ]]; then
  STACK="Python"; VERIFY="pytest"
elif [[ -f "$TARGET/go.mod" ]]; then
  STACK="Go"; VERIFY="go test ./..."
fi

SLUG=""
if git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  URL="$(git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  [[ -n "$URL" ]] && SLUG="$(printf '%s' "$URL" \
    | sed -e 's#^git@[^:]*:##' -e 's#^https\{0,1\}://[^/]*/##' -e 's#\.git$##')"
fi

# ── One confirmation, before anything is written ─────────────────────────────
echo "${BOLD}Activar el harness en $NAME${RESET}"
echo ""
echo "  Detectado:    $STACK"
echo "  Verificación: $VERIFY"
if [[ -n "$SLUG" ]]; then
  echo "  Remoto:       $SLUG"
else
  echo "  Remoto:       ninguno (sólo control local)"
fi
[[ $WITH_GHERKIN -eq 1 ]] && echo "  Extra:        pack de Gherkin (specs ejecutables)"
echo ""
echo "Instalaré el contrato para agentes, estado durable, presupuestos anti-loop,"
echo "la compuerta local y el control de GitHub cuando el plan lo permita."
echo "No se sobrescribe ningún archivo existente."

if [[ $DRYRUN -eq 1 ]]; then
  echo ""
  echo "${YELLOW}Simulación: no se escribió nada.${RESET}"
  exit 0
fi

if [[ $ASSUME_YES -eq 0 ]]; then
  echo ""
  printf '¿Continuar? [s/N] '
  read -r reply
  case "$reply" in
    s|S|si|Si|SI|y|Y|yes) ;;
    *) echo "Cancelado. No se escribió nada."; exit 0 ;;
  esac
fi

echo ""
echo "${BOLD}────────────────────────────────────────${RESET}"

# ── 1. The harness itself ────────────────────────────────────────────────────
if ! bash "$KIT_DIR/bin/harness-init.sh" --target "$TARGET" --level full >/dev/null 2>&1; then
  echo "${RED}BLOCKED_TOOL${RESET} — el scaffold falló. Revisa permisos de escritura en $TARGET."
  exit 1
fi
echo "  ${GREEN}ok${RESET}   harness instalado"

# ── 2. Optional pack ─────────────────────────────────────────────────────────
if [[ $WITH_GHERKIN -eq 1 ]]; then
  mkdir -p "$TARGET/bin" "$TARGET/features/steps"
  for f in gherkin-check gherkin-validate.mjs; do
    [[ -e "$TARGET/bin/$f" ]] || cp "$KIT_DIR/packs/gherkin/repo-template/bin/$f" "$TARGET/bin/$f"
    chmod +x "$TARGET/bin/$f" 2>/dev/null || true
  done
  [[ -e "$TARGET/features/cart.feature" ]] || \
    cp -R "$KIT_DIR/packs/gherkin/repo-template/features/." "$TARGET/features/" 2>/dev/null || true
  echo "  ${GREEN}ok${RESET}   pack de Gherkin instalado (bin/gherkin-check)"
fi

# ── 3. Make the gate binding, as far as this repo's plan allows ──────────────
if [[ -n "$SLUG" ]] && command -v gh >/dev/null 2>&1; then
  PROTECT_OUT="$(NO_COLOR=1 bash "$KIT_DIR/bin/harness-protect.sh" "$SLUG" --repo-dir "$TARGET" 2>&1)"
  if printf '%s' "$PROTECT_OUT" | grep -q "required-quality-check.*\n.*verified" ||
     printf '%s' "$PROTECT_OUT" | grep -A2 "required-quality-check" | grep -q "verified"; then
    echo "  ${GREEN}ok${RESET}   compuerta requerida activa en $SLUG"
  else
    echo "  ${YELLOW}--${RESET}   no se pudo activar la compuerta requerida"
  fi
  if printf '%s' "$PROTECT_OUT" | grep -A2 "workflow-integrity" | grep -q "verified"; then
    echo "  ${GREEN}ok${RESET}   workflow protegido contra ediciones"
  else
    echo "  ${YELLOW}--${RESET}   workflow NO protegido (los push rules requieren repo de organización)"
  fi
elif [[ -n "$SLUG" ]]; then
  echo "  ${YELLOW}--${RESET}   gh no está disponible: no se instalaron reglas en $SLUG"
else
  echo "  ${YELLOW}--${RESET}   sin remoto: no hay nada que bloquee una fusión todavía"
fi

# ── 4. The honest closing ────────────────────────────────────────────────────
echo ""
NO_COLOR="${NO_COLOR:-}" bash "$KIT_DIR/bin/harness-status.sh" --target "$TARGET"

echo ""
echo "${BOLD}Lo que queda en tus manos${RESET}"
echo "  1. AGENTS.md — reemplaza la línea de propósito por lo que hace este proyecto."
echo "  2. feature_list.json — reemplaza las features de ejemplo por el backlog real."
echo "     Un harness con features de ejemplo es decoración: este es el paso que"
echo "     decide si el sistema sirve o sólo aparenta."
echo "  3. Confirma que la verificación es correcta: $VERIFY"
exit 0
