#!/usr/bin/env bash
# run.sh — run every consumer-contract probe and report the board.
#
# Until F22 lands this is NOT part of `make check`: the probes are acceptance tests
# for features that are not built yet, and they are red on purpose. Run it to see
# what is left; each feature turns one line green.
#
# Usage: bash tests/contract/run.sh

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
green=0; red=0; RED_LIST=""
for probe in "$HERE"/F[0-9][0-9]-*.sh; do
  [[ -f "$probe" ]] || continue
  name="$(basename "$probe" .sh)"
  if bash "$probe" >/dev/null 2>&1; then
    printf '  green  %s\n' "$name"; green=$((green+1))
  else
    printf '  RED    %s\n' "$name"; red=$((red+1)); RED_LIST="$RED_LIST $name"
  fi
done
echo ""
echo "contract: $green green, $red red"
if [[ $((green + red)) -eq 0 ]]; then
  echo "contract: no probes were found — nothing was verified" >&2
  exit 4
fi
[[ "$red" -eq 0 ]] || exit 1
exit 0
