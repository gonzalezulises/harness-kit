#!/usr/bin/env bash
# Install a pinned parser only inside this repository's isolated tools directory.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 -I -c 'import sys; sys.exit(0 if sys.version_info >= (3,8) else "Full harness requires Python3.8+")'
python3 -I -m venv "$ROOT/.harness/tools/oracles-venv"
"$ROOT/.harness/tools/oracles-venv/bin/python3" -I -m pip install --disable-pip-version-check -r "$ROOT/requirements-harness.txt"
"$ROOT/.harness/tools/oracles-venv/bin/python3" -I -c 'import yaml; assert yaml.__version__ == "6.0.3"'
