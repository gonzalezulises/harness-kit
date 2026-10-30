#!/usr/bin/env bash
# harness-gh.sh — Run gh (or print GH_TOKEN / profile metadata) using the
# account profile matching the target repository's GitHub owner.
# Never invokes `gh auth switch` (preserves global gh state).
# Compatible with bash 3.2 (macOS default).

set -euo pipefail

PROFILES_DIR="${HARNESS_PROFILES_DIR:-$HOME/.config/harness-kit/profiles}"
TARGET="."
REPO_OVERRIDE=""
MODE="exec"

usage() {
  cat <<'EOF'
Usage:
  harness-gh.sh [--target /path/to/repo] [--repo owner/name] --print-token
  harness-gh.sh [--target /path/to/repo] [--repo owner/name] --print-profile
  harness-gh.sh [--target /path/to/repo] [--repo owner/name] [--] <gh-args...>

Resolves the GitHub owner from --repo, or from the git `origin` remote of
--target (default: current directory), loads ~/.config/harness-kit/profiles/<owner>.profile,
obtains a scoped token via `gh auth token --user "$GH_USER"`, and runs `gh`
with `GH_TOKEN` exported — without ever calling `gh auth switch`.
EOF
}

ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --repo)
      REPO_OVERRIDE="$2"
      shift 2
      ;;
    --print-token)
      MODE="token"
      shift
      ;;
    --print-profile)
      MODE="profile"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        ARGS+=("$1")
        shift
      done
      ;;
    *)
      # Also detect -R / --repo passed directly to gh
      if [[ "$1" == "-R" && $# -ge 2 && -z "$REPO_OVERRIDE" ]]; then
        REPO_OVERRIDE="$2"
      fi
      ARGS+=("$1")
      shift
      ;;
  esac
done

resolve_repo() {
  if [[ -n "$REPO_OVERRIDE" ]]; then
    echo "$REPO_OVERRIDE"
    return 0
  fi
  local url
  url="$(git -C "$TARGET" config --get remote.origin.url 2>/dev/null || git -C "$TARGET" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$url" ]]; then
    return 0
  fi
  echo "$url" | sed -E 's#(git@|https://)([^/:]+)[/:]##; s#\.git$##'
}

REPO_SLUG="$(resolve_repo)"
OWNER=""
if [[ "$REPO_SLUG" == */* ]]; then
  OWNER="${REPO_SLUG%%/*}"
fi

ACCOUNT_ID=""
GH_USER=""
GIT_EMAIL=""
PROFILE_FILE=""

if [[ -n "$OWNER" && -f "$PROFILES_DIR/$OWNER.profile" ]]; then
  PROFILE_FILE="$PROFILES_DIR/$OWNER.profile"
  # shellcheck disable=SC1090
  source "$PROFILE_FILE"
fi

# Fallback: if no profile matched by owner, default GH_USER to OWNER when present
if [[ -z "$GH_USER" && -n "$OWNER" ]]; then
  GH_USER="$OWNER"
fi

RESOLVED_TOKEN="${GH_TOKEN:-}"
if [[ -z "$RESOLVED_TOKEN" && -n "$GH_USER" ]] && command -v gh >/dev/null 2>&1; then
  RESOLVED_TOKEN="$(gh auth token --user "$GH_USER" 2>/dev/null || true)"
fi

if [[ "$MODE" == "token" ]]; then
  printf '%s\n' "$RESOLVED_TOKEN"
  exit 0
fi

if [[ "$MODE" == "profile" ]]; then
  printf 'REPO_SLUG=%s\n' "$REPO_SLUG"
  printf 'OWNER=%s\n' "$OWNER"
  printf 'PROFILE_FILE=%s\n' "$PROFILE_FILE"
  printf 'ACCOUNT_ID=%s\n' "${ACCOUNT_ID:-$OWNER}"
  printf 'GH_USER=%s\n' "$GH_USER"
  printf 'GIT_EMAIL=%s\n' "$GIT_EMAIL"
  exit 0
fi

if [[ ${#ARGS[@]} -eq 0 ]]; then
  usage >&2
  exit 2
fi

if [[ -n "$RESOLVED_TOKEN" ]]; then
  export GH_TOKEN="$RESOLVED_TOKEN"
fi

exec gh "${ARGS[@]}"

