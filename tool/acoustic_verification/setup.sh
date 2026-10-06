#!/usr/bin/env bash
# Creates tool/acoustic_verification/.venv with everything the acoustic
# model server and the prototype need. First run downloads ~1 GB of
# packages; the model itself (~2.4 GB) downloads on the server's first start.
set -euo pipefail
cd "$(dirname "$0")"
if [ ! -x .venv/bin/python ]; then
  if python3 -c 'import ensurepip' 2>/dev/null; then
    python3 -m venv .venv
  else
    # Debian/Ubuntu without python3-venv: create it without pip, then bootstrap pip.
    python3 -m venv --without-pip .venv
    curl -sSL https://bootstrap.pypa.io/get-pip.py -o .venv/get-pip.py
    .venv/bin/python .venv/get-pip.py -q
  fi
fi
.venv/bin/python -m pip install -q --upgrade pip
.venv/bin/python -m pip install -q -r requirements.txt
echo "Ready. Start the server with:"
echo "  $(pwd)/.venv/bin/python $(pwd)/server.py --port 8790"
