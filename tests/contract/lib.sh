#!/usr/bin/env bash
# lib.sh — shared helpers for the consumer-contract probes.
#
# A probe is an acceptance test written BEFORE the implementation it judges. Each
# one was run against the commit that introduced it and watched failing, for the
# reason its feature names. That is the same rule the oracles carry: a test only
# ever seen passing has not been shown to test anything.
#
# Probes are deliberately NOT wired into `make check` yet. They are the `layers`
# of features F15+ in feature_list.json, and they go red-to-green one feature at a
# time. F22 wires the whole directory into `make check` once they are green.
#
# Conventions match tests/run-tests.sh: no mocks, throwaway repos, real scripts,
# assertions on observable behaviour. bash 3.2 compatible (no mapfile, no
# associative arrays, no ${var,,}).

# shellcheck disable=SC2034  # colours are consumed by the probes that source this
if [[ ! -t 1 ]] || [[ -n "${NO_COLOR:-}" ]]; then
  RED=""; GREEN=""; BOLD=""; RESET=""
else
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

PASS=0; FAIL=0
ok()  { echo "  ${GREEN}ok${RESET}   $1"; PASS=$((PASS+1)); }
bad() { echo "  ${RED}FAIL${RESET} $1"; FAIL=$((FAIL+1)); }

# expect_zero <label> <exit-code>
expect_zero()    { if [[ "$2" -eq 0 ]]; then ok "$1"; else bad "$1 (exit $2, expected 0)"; fi; }
# expect_nonzero <label> <exit-code>
expect_nonzero() { if [[ "$2" -ne 0 ]]; then ok "$1 (exit $2)"; else bad "$1 (exit 0 — it let this through)"; fi; }

# commit_all <message> — commit everything in the current repo as a fixed identity.
commit_all() {
  git add -A >/dev/null 2>&1
  git -c user.email=probe@harness-kit -c user.name=probe \
      -c commit.gpgsign=false commit -qm "$1" >/dev/null 2>&1
}

# new_repo <dir> — an empty git repo on a branch called main, with a README.
new_repo() {
  mkdir -p "$1" && cd "$1" || exit 70
  git init -q >/dev/null 2>&1
  git checkout -q -b main 2>/dev/null || git symbolic-ref HEAD refs/heads/main
  echo "# $(basename "$1")" > README.md
}

# snapshot_kit <src> <dest> — copy a kit WORKING TREE (uncommitted work included,
# .git left behind) into <dest> as a fresh repository: one commit tagged with the
# release in VERSION, then one untagged commit on top. The result behaves like a
# developer's checkout sitting between two releases, which is where every real
# installation has come from so far.
snapshot_kit() {
  mkdir -p "$2" || exit 70
  ( cd "$1" && tar --exclude=.git -cf - . ) | ( cd "$2" && tar -xf - ) || exit 70
  git -C "$2" init -q >/dev/null 2>&1
  git -C "$2" add -A >/dev/null 2>&1
  git -C "$2" -c user.email=probe@harness-kit -c user.name=probe -c commit.gpgsign=false \
      commit -qm "release" >/dev/null 2>&1
  git -C "$2" tag "v$(tr -d '[:space:]' < "$2/VERSION")" >/dev/null 2>&1
  git -C "$2" -c user.email=probe@harness-kit -c user.name=probe -c commit.gpgsign=false \
      commit -q --allow-empty -m "probe: one commit past the release" >/dev/null 2>&1
}

# finish <probe-name> — print the tally and exit 0 only when nothing failed.
finish() {
  echo ""
  echo "────────────────────────────────────────"
  echo "$1: $PASS passed, $FAIL failed"
  [[ "$FAIL" -eq 0 ]] || exit 1
  exit 0
}
