#!/usr/bin/env bash
# harness-sync.sh — Synchronize workspace branch, upstream state, git author
# identity, and harness level coherence before starting agent work.
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${HARNESS_PROFILES_DIR:-$HOME/.config/harness-kit/profiles}"

TARGET="."
CHECK_ONLY=0
NO_FETCH=0
QUIET=0

usage() {
  cat <<'EOF'
Usage: harness-sync.sh [--target /path/to/repo] [--check] [--no-fetch] [--quiet]

Ensures the repository is synchronized before an agent starts work:
  1. Verifies/aligns local `git config user.email` with the owner's profile.
  2. Verifies coherence between `.harness/level` and `feature_list.json`.
  3. Fetches `origin` (unless --check or --no-fetch).
  4. If on a non-default branch already merged into `origin/<default>` and the
     working tree is clean, switches back to `<default>` and fast-forwards.
  5. If on `<default>` and behind `origin/<default>`, fast-forwards when clean
     or fails with CONFLICT_RISK / DIRTY_BEHIND_ORIGIN when dirty.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --check)
      CHECK_ONLY=1
      shift
      ;;
    --no-fetch)
      NO_FETCH=1
      shift
      ;;
    --quiet)
      QUIET=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$TARGET" ]]; then
  echo "ERROR: target directory does not exist: $TARGET" >&2
  exit 2
fi

TARGET="$(cd "$TARGET" && pwd)"

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: $TARGET is not a git repository" >&2
  exit 2
fi

ACTIONS=()
WARNINGS=()
ERRORS=()

log_action() { ACTIONS+=("$1"); }
log_warn()   { WARNINGS+=("$1"); }
log_error()  { ERRORS+=("$1"); }

# 1. Profile & git author email alignment
ORIGIN_URL="$(git -C "$TARGET" config --get remote.origin.url 2>/dev/null || git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
REPO_SLUG=""
OWNER=""
if [[ -n "$ORIGIN_URL" ]]; then
  REPO_SLUG="$(echo "$ORIGIN_URL" | sed -E 's#(git@|https://)([^/:]+)[/:]##; s#\.git$##')"
  if [[ "$REPO_SLUG" == */* ]]; then
    OWNER="${REPO_SLUG%%/*}"
  fi
fi

ACCOUNT_ID="${OWNER:-local}"
GIT_EMAIL=""
PROFILE_FILE=""

if [[ -n "$OWNER" && -f "$PROFILES_DIR/$OWNER.profile" ]]; then
  PROFILE_FILE="$PROFILES_DIR/$OWNER.profile"
  # shellcheck disable=SC1090
  source "$PROFILE_FILE"
fi

if [[ -n "$GIT_EMAIL" ]]; then
  CURRENT_EMAIL="$(git -C "$TARGET" config user.email || true)"
  if [[ "$CURRENT_EMAIL" != "$GIT_EMAIL" ]]; then
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
      log_warn "MISMATCH_GIT_EMAIL: git user.email is '${CURRENT_EMAIL:-<unset>}', profile $ACCOUNT_ID expects '$GIT_EMAIL'"
    else
      git -C "$TARGET" config --local user.email "$GIT_EMAIL"
      log_action "FIXED_GIT_EMAIL: set local user.email to $GIT_EMAIL (profile $ACCOUNT_ID)"
    fi
  fi
fi

# 2. Harness level coherence (.harness/level vs feature_list.json)
DOT_LEVEL=""
if [[ -f "$TARGET/.harness/level" ]]; then
  DOT_LEVEL="$(tr -d '[:space:]' < "$TARGET/.harness/level")"
fi
JSON_LEVEL=""
if [[ -f "$TARGET/feature_list.json" ]] && command -v jq >/dev/null 2>&1; then
  JSON_LEVEL="$(jq -r '.level // empty' "$TARGET/feature_list.json" 2>/dev/null || true)"
fi

EFFECTIVE_LEVEL="${DOT_LEVEL:-${JSON_LEVEL:-unknown}}"
if [[ -n "$DOT_LEVEL" && -n "$JSON_LEVEL" && "$DOT_LEVEL" != "$JSON_LEVEL" ]]; then
  log_warn "LEVEL_MISMATCH: .harness/level='$DOT_LEVEL' but feature_list.json .level='$JSON_LEVEL'"
elif [[ -z "$DOT_LEVEL" && -n "$JSON_LEVEL" && "$CHECK_ONLY" -eq 0 ]]; then
  mkdir -p "$TARGET/.harness"
  printf '%s\n' "$JSON_LEVEL" > "$TARGET/.harness/level"
  log_action "FIXED_LEVEL_FILE: wrote .harness/level=$JSON_LEVEL"
fi

# 3. Fetch origin and synchronize branch state
if [[ -n "$ORIGIN_URL" ]]; then
  if [[ "$CHECK_ONLY" -eq 0 && "$NO_FETCH" -eq 0 ]]; then
    if [[ -x "$SCRIPT_DIR/harness-gh.sh" ]]; then
      GH_TOKEN_VAL="$("$SCRIPT_DIR/harness-gh.sh" --target "$TARGET" --print-token 2>/dev/null || true)"
      if [[ -n "$GH_TOKEN_VAL" ]]; then
        export GH_TOKEN="$GH_TOKEN_VAL"
      fi
    fi
    if git -C "$TARGET" fetch --prune --quiet origin 2>/dev/null; then
      log_action "FETCHED_ORIGIN"
    else
      log_warn "FETCH_SKIPPED: could not reach origin (offline or auth required)"
    fi
  fi

  DEFAULT_BRANCH="$(git -C "$TARGET" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  if [[ -z "$DEFAULT_BRANCH" ]]; then
    if git -C "$TARGET" show-ref --verify --quiet refs/remotes/origin/main; then
      DEFAULT_BRANCH="main"
    elif git -C "$TARGET" show-ref --verify --quiet refs/remotes/origin/master; then
      DEFAULT_BRANCH="master"
    else
      DEFAULT_BRANCH="main"
    fi
  fi

  CURRENT_BRANCH="$(git -C "$TARGET" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "DETACHED")"
  DIRTY_STATUS="$(git -C "$TARGET" status --porcelain 2>/dev/null || true)"

  if git -C "$TARGET" show-ref --verify --quiet "refs/remotes/origin/$DEFAULT_BRANCH"; then
    # Case A: On a non-default branch that is already merged into origin/$DEFAULT_BRANCH
    if [[ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" && "$CURRENT_BRANCH" != "DETACHED" ]]; then
      if git -C "$TARGET" merge-base --is-ancestor HEAD "refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null; then
        if [[ -z "$DIRTY_STATUS" && "$CHECK_ONLY" -eq 0 ]]; then
          if git -C "$TARGET" show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
            git -C "$TARGET" checkout --quiet "$DEFAULT_BRANCH"
          else
            git -C "$TARGET" checkout --quiet -b "$DEFAULT_BRANCH" "refs/remotes/origin/$DEFAULT_BRANCH"
          fi
          git -C "$TARGET" merge --ff-only --quiet "refs/remotes/origin/$DEFAULT_BRANCH" || true
          log_action "SWITCHED_TO_DEFAULT: $CURRENT_BRANCH -> $DEFAULT_BRANCH (branch was already merged into origin/$DEFAULT_BRANCH)"
          CURRENT_BRANCH="$DEFAULT_BRANCH"
        else
          log_warn "STALE_MERGED_BRANCH: '$CURRENT_BRANCH' is already merged into origin/$DEFAULT_BRANCH"
          if [[ -n "$DIRTY_STATUS" ]]; then
            log_error "STALE_DIRTY_TREE: working tree has uncommitted changes on merged branch '$CURRENT_BRANCH'"
          fi
        fi
      fi
    fi

    # Case B: On the default branch — check ahead/behind against origin/$DEFAULT_BRANCH
    if [[ "$CURRENT_BRANCH" == "$DEFAULT_BRANCH" ]]; then
      BEHIND_COUNT="$(git -C "$TARGET" rev-list --count "HEAD..refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null || echo 0)"
      if [[ "$BEHIND_COUNT" -gt 0 ]]; then
        if [[ -z "$DIRTY_STATUS" ]]; then
          if [[ "$CHECK_ONLY" -eq 0 ]]; then
            if git -C "$TARGET" merge --ff-only --quiet "refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null; then
              NEW_SHA="$(git -C "$TARGET" rev-parse --short HEAD)"
              log_action "FAST_FORWARDED: $DEFAULT_BRANCH by $BEHIND_COUNT commit(s) to $NEW_SHA"
            else
              log_error "DIVERGED_DEFAULT_BRANCH: local $DEFAULT_BRANCH cannot fast-forward to origin/$DEFAULT_BRANCH"
            fi
          else
            log_warn "BEHIND_ORIGIN: $DEFAULT_BRANCH is behind origin/$DEFAULT_BRANCH by $BEHIND_COUNT commit(s)"
          fi
        else
          # Dirty tree while behind origin: check if dirty files overlap with upstream changes
          UPSTREAM_FILES="$(git -C "$TARGET" diff --name-only "HEAD..refs/remotes/origin/$DEFAULT_BRANCH" 2>/dev/null || true)"
          DIRTY_FILES="$(git -C "$TARGET" status --porcelain | awk '{print $NF}')"
          OVERLAP=""
          if [[ -n "$UPSTREAM_FILES" && -n "$DIRTY_FILES" ]]; then
            OVERLAP="$(comm -12 <(printf '%s\n' "$UPSTREAM_FILES" | sort -u) <(printf '%s\n' "$DIRTY_FILES" | sort -u) || true)"
          fi
          if [[ -n "$OVERLAP" ]]; then
            log_error "CONFLICT_RISK: uncommitted local changes overlap with $BEHIND_COUNT incoming commit(s) on origin/$DEFAULT_BRANCH: $(echo "$OVERLAP" | tr '\n' ' ')"
          else
            log_error "DIRTY_BEHIND_ORIGIN: working tree has uncommitted changes while $DEFAULT_BRANCH is behind origin/$DEFAULT_BRANCH by $BEHIND_COUNT commit(s)"
          fi
        fi
      fi
    fi
  fi
fi

FINAL_BRANCH="$(git -C "$TARGET" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "DETACHED")"
FINAL_SHA="$(git -C "$TARGET" rev-parse --short HEAD 2>/dev/null || echo "none")"

if [[ "$QUIET" -eq 0 ]]; then
  if [[ ${#ACTIONS[@]} -gt 0 ]]; then
    for a in "${ACTIONS[@]}"; do
      echo "  sync  $a"
    done
  fi
  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    for w in "${WARNINGS[@]}"; do
      echo "  warn  $w"
    done
  fi
  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    for e in "${ERRORS[@]}"; do
      echo "  FAIL  $e" >&2
    done
  fi
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "SYNC_FAIL: repo=${REPO_SLUG:-local} branch=$FINAL_BRANCH head=$FINAL_SHA level=$EFFECTIVE_LEVEL profile=$ACCOUNT_ID" >&2
  exit 2
fi

echo "SYNC_OK: repo=${REPO_SLUG:-local} branch=$FINAL_BRANCH head=$FINAL_SHA level=$EFFECTIVE_LEVEL profile=$ACCOUNT_ID"
exit 0
