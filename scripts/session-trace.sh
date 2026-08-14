#!/usr/bin/env bash
# session-trace.sh — structured runtime signal for agent sessions.
#
# Usage:
#   scripts/session-trace.sh start
#   scripts/session-trace.sh event <name> [detail]
#   scripts/session-trace.sh end
#   scripts/session-trace.sh report
#
# Appends JSONL to .harness/traces/traces.jsonl. That file is a runtime artifact:
# gitignore it. Without traces you are debugging agent behaviour from memory,
# which is exactly the failure mode the harness exists to remove.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || { echo "cannot cd to $ROOT_DIR" >&2; exit 66; }

TRACE_DIR=".harness/traces"
TRACE_FILE="$TRACE_DIR/traces.jsonl"
mkdir -p "$TRACE_DIR"

stamp()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
commit() { git rev-parse --short HEAD 2>/dev/null || echo "no-git"; }

esc() { printf '%s' "${1:-}" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }

emit() {
  local kind="$1" name="${2:-}" detail="${3:-}"
  printf '{"ts":"%s","kind":"%s","name":"%s","detail":"%s","commit":"%s"}\n' \
    "$(stamp)" "$(esc "$kind")" "$(esc "$name")" "$(esc "$detail")" "$(commit)" \
    >> "$TRACE_FILE"
}

case "${1:-}" in
  start)
    emit session_start "" "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') dirty files"
    echo "Session trace opened -> $TRACE_FILE"
    ;;
  event)
    [[ -n "${2:-}" ]] || { echo "usage: $0 event <name> [detail]" >&2; exit 64; }
    emit event "$2" "${3:-}"
    ;;
  end)
    emit session_end "" "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') dirty files"
    echo "Session trace closed."
    ;;
  report)
    [[ -f "$TRACE_FILE" ]] || { echo "No traces recorded yet."; exit 0; }
    echo "Events: $(wc -l < "$TRACE_FILE" | tr -d ' ')"
    echo "Last 10:"
    tail -10 "$TRACE_FILE" | sed 's/^/  /'
    ;;
  *)
    echo "usage: $0 {start|event <name> [detail]|end|report}" >&2
    exit 64
    ;;
esac
