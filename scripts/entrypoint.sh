#!/usr/bin/env bash
set -euo pipefail

# Paperspace persistent storage.
if [ -d /notebooks ]; then
  chmod 777 /notebooks 2>/dev/null || true
fi

# The image PATH already points at the micromamba environment, but initializing
# the shell also makes interactive terminals behave as expected.
eval "$(micromamba shell hook --shell bash)"
micromamba activate pyenv

# Forward-compat libraries are useful on Paperspace hosts whose kernel driver is
# older than the CUDA 13.x user-space stack. Do not fail if the package is absent.
if [ -d /usr/local/cuda-13.1/compat ]; then
  export LD_LIBRARY_PATH="/usr/local/cuda-13.1/compat:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
fi

exec "$@"
