#!/usr/bin/env bash
# Install a pinned parser only inside this repository's isolated tools directory.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -m venv "$ROOT/.harness/tools/oracles-venv"
"$ROOT/.harness/tools/oracles-venv/bin/python3" -m pip install --disable-pip-version-check -r "$ROOT/requirements-harness.txt"
"$ROOT/.harness/tools/oracles-venv/bin/python3" -c 'import yaml; assert yaml.__version__ == "6.0.3"'
