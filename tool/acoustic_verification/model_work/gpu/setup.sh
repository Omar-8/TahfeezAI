#!/usr/bin/env bash
# Sets up a rented NVIDIA GPU machine (Ubuntu, CUDA driver present) for
# student distillation. Run from the copied model_work directory.
set -euo pipefail
cd "$(dirname "$0")/.."
python3 -m venv .venv 2>/dev/null || { python3 -m venv --without-pip .venv && curl -sSL https://bootstrap.pypa.io/get-pip.py | .venv/bin/python; }
.venv/bin/pip install -q --upgrade pip
.venv/bin/pip install -q torch --index-url https://download.pytorch.org/whl/cu124
.venv/bin/pip install -q "transformers==4.57.6" "quran-muaalem==0.2.2" "datasets<4" soundfile librosa
.venv/bin/python -c "import torch; print(torch.cuda.get_device_name(0), round(torch.cuda.get_device_properties(0).total_memory/1e9), 'GB')"
