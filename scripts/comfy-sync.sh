#!/usr/bin/env bash
set -euo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/notebooks/comfyui}"
CONSTRAINTS="${COMFY_CONSTRAINTS:-/opt/comfy-runtime/constraints.txt}"

if [ ! -d "$COMFYUI_DIR" ]; then
  echo "ComfyUI directory not found: $COMFYUI_DIR" >&2
  exit 1
fi

if [ ! -f "$COMFYUI_DIR/requirements.txt" ]; then
  echo "requirements.txt not found: $COMFYUI_DIR/requirements.txt" >&2
  exit 1
fi

cd "$COMFYUI_DIR"

echo "ComfyUI:      $COMFYUI_DIR"
echo "Python:       $(command -v python)"
echo "uv:           $(command -v uv)"
echo "Constraints:  $CONSTRAINTS"
echo

# Install current ComfyUI requirements without allowing them to replace the
# pinned PyTorch/SageAttention ABI. `--no-build-isolation` helps native custom
# packages see the installed torch when a requirements file builds extensions.
uv pip install \
  --python "$(command -v python)" \
  --no-cache \
  --constraint "$CONSTRAINTS" \
  -r requirements.txt

echo
echo "ComfyUI requirements synced."
echo "Run 'runtime-check' before starting ComfyUI after a major update."
