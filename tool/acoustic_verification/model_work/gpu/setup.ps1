# Sets up a Windows PC with an NVIDIA GPU for Tahfeez student distillation.
# Run in PowerShell from the unzipped kit folder:  .\setup.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
if (-not (Test-Path .venv)) { py -3.12 -m venv .venv }
$py = ".\.venv\Scripts\python.exe"
& $py -m pip install --upgrade pip
& $py -m pip install torch --index-url https://download.pytorch.org/whl/cu124
& $py -m pip install "transformers==4.57.6" "quran-muaalem==0.2.2" "datasets<4" soundfile librosa
& $py -c "import torch; assert torch.cuda.is_available(), 'CUDA not available'; p = torch.cuda.get_device_properties(0); print(p.name, round(p.total_memory / 1e9), 'GB VRAM', '| bf16:', torch.cuda.is_bf16_supported()); assert torch.cuda.is_bf16_supported(), 'This GPU has no bf16 (needs RTX 30-series / Ampere or newer): distill_student.py must be switched to fp16 + GradScaler first'"
