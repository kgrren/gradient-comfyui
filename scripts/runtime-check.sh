#!/usr/bin/env bash
set -euo pipefail

echo "=== NVIDIA ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi || true
else
  echo "nvidia-smi: not found (normal while building the image)"
fi

echo
echo "=== CUDA toolkit ==="
if command -v nvcc >/dev/null 2>&1; then
  nvcc --version
else
  echo "nvcc: not found"
fi

echo
echo "=== Python / PyTorch ==="
python - <<'PY'
import sys
import torch

print("python:", sys.version.split()[0])
print("torch:", torch.__version__)
print("torch CUDA runtime:", torch.version.cuda)
print("CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
    print("capability:", torch.cuda.get_device_capability(0))
    x = torch.randn((1024, 1024), device="cuda", dtype=torch.float16)
    y = x @ x
    torch.cuda.synchronize()
    print("CUDA smoke test:", tuple(y.shape), y.dtype)
PY

echo
echo "=== SageAttention ==="
python - <<'PY'
try:
    import sageattention
    print("sageattention: import OK", getattr(sageattention, "__version__", "(version attribute unavailable)"))
except Exception as exc:
    print("sageattention: import FAILED")
    raise
PY
