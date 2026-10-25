#!/usr/bin/env bash
# post-commit-eval.sh — eval agente-agnóstico: registra pass/false_claim por commit.
#
# Todo agente (Codex, Claude, Grok, DeepSeek, Cursor, un humano) commitea. Este
# hook, instalado por install-githooks.sh, puntúa el repo tras cada commit y lo
# registra: ¿pasó el verify? ¿hay claims falsos? Best-effort — nunca bloquea el
# commit (ya ocurrió) y usa check-fast cuando existe.
#
# Destino: $EVAL_RESULTS_DIR si está definido; si no, ~/.agents/evals/results/
# si existe; si no, .harness/evals.jsonl (repo-local, portable).
set -uo pipefail

ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT_DIR" || exit 0

VERIFY=""
if [ -f Makefile ]; then
  grep -q '^check-fast:' Makefile && VERIFY="make check-fast"
  [ -z "$VERIFY" ] && grep -q '^check:' Makefile && VERIFY="make check"
elif [ -f package.json ] && grep -q '"test"' package.json; then
  VERIFY="npm test"
fi
[ -z "$VERIFY" ] && exit 0

PASS="false"
if ( eval "$VERIFY" ) >/dev/null 2>&1; then PASS="true"; fi

FALSE_CLAIM=0
if [ -f feature_list.json ] && command -v python3 >/dev/null 2>&1; then
  FALSE_CLAIM="$(python3 -c "import json;d=json.load(open('feature_list.json'));print(sum(1 for f in d.get('features',[]) if f.get('state')=='passing' and not f.get('evidence')))" 2>/dev/null || echo 0)"
fi

COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
if [ -n "${EVAL_RESULTS_DIR:-}" ]; then
  OUT="$EVAL_RESULTS_DIR/$(date +%Y-%m-%d).jsonl"
  mkdir -p "$EVAL_RESULTS_DIR"
elif [ -d "$HOME/.agents/evals/results" ]; then
  OUT="$HOME/.agents/evals/results/$(date +%Y-%m-%d).jsonl"
else
  OUT=".harness/evals.jsonl"
  mkdir -p .harness
fi
printf '%s\tcommit\t%s\t{"pass":%s,"false_claim":%s,"verify":"%s"}\n' \
  "$(date -u +%H:%M:%SZ)" "$COMMIT" "$PASS" "$FALSE_CLAIM" "$VERIFY" >> "$OUT"
exit 0
