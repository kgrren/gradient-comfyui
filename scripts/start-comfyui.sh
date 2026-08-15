#!/usr/bin/env bash
set -euo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/notebooks/comfyui}"
COMFYUI_PORT="${COMFYUI_PORT:-8188}"

if [ ! -f "$COMFYUI_DIR/main.py" ]; then
  echo "ComfyUI main.py not found: $COMFYUI_DIR/main.py" >&2
  exit 1
fi

cd "$COMFYUI_DIR"

# Arguments supplied by the user are appended, so examples such as
# `start-comfyui --preview-method auto` remain possible.
exec python main.py --listen 0.0.0.0 --port "$COMFYUI_PORT" "$@"
