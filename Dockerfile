# syntax=docker/dockerfile:1.7

# Paperspace / RTX A4000 runtime for ComfyUI
# PyTorch 2.10 uses the official cu130 wheels, while the system CUDA toolkit is
# 13.1.1 so native extensions such as SageAttention can be built with a newer
# 13.x nvcc. This mirrors the working Paperspace pattern discussed in the
# referenced note article.
ARG CUDA_IMAGE=nvidia/cuda:13.1.1-cudnn-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

LABEL maintainer="kgrren"
LABEL org.opencontainers.image.description="Paperspace ComfyUI runtime: CUDA 13.1.1, PyTorch 2.10 cu130, Python 3.12, uv, SageAttention, JupyterLab"

ARG PYTHON_VERSION=3.12
ARG TORCH_VERSION=2.10.0
ARG TORCHVISION_VERSION=0.25.0
ARG TORCHAUDIO_VERSION=2.10.0
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cu130
ARG SAGEATTENTION_VERSION=2.2.0
ARG SAGEATTENTION_REF=main
ARG CUDA_COMPAT_PACKAGE=cuda-compat-13-1
ARG INSTALL_CUDA_COMPAT=1

ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
    VIRTUAL_ENV=/opt/conda/envs/pyenv \
    PATH=/opt/conda/envs/pyenv/bin:/opt/conda/bin:/usr/local/bin:$PATH \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST=8.6 \
    FORCE_CUDA=1 \
    MAX_JOBS=4 \
    EXT_PARALLEL=4 \
    NVCC_APPEND_FLAGS="--threads 8" \
    UV_LINK_MODE=copy \
    UV_HTTP_TIMEOUT=300 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    COMFYUI_DIR=/notebooks/comfyui \
    PYTHONUNBUFFERED=1

# CUDA Forward Compatibility libraries are placed here by cuda-compat-13-1.
# Keeping the normal CUDA library path after it lets the compatibility libcuda
# take precedence without hiding toolkit libraries.
ENV LD_LIBRARY_PATH=/usr/local/cuda-13.1/compat:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

RUN apt-get update && apt-get install -y --no-install-recommends \
      aria2 \
      build-essential \
      bzip2 \
      ca-certificates \
      cmake \
      curl \
      ffmpeg \
      git \
      git-lfs \
      libgl1 \
      libglib2.0-0 \
      libgoogle-perftools4 \
      libsndfile1 \
      nano \
      ninja-build \
      pkg-config \
      unzip \
      vim \
      wget \
      zip \
    && if [ "${INSTALL_CUDA_COMPAT}" = "1" ]; then \
         apt-get install -y --no-install-recommends "${CUDA_COMPAT_PACKAGE}"; \
       fi \
    && rm -rf /var/lib/apt/lists/*

# Micromamba + Python. Python 3.12 is intentional: it is current enough for
# ComfyUI while still offering broader custom-node wheel coverage than 3.13/3.14.
RUN set -eux; \
    arch="$(uname -m)"; \
    case "$arch" in \
      x86_64) mamba_arch=linux-64 ;; \
      aarch64|arm64) mamba_arch=linux-aarch64 ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${mamba_arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    mkdir -p "${MAMBA_ROOT_PREFIX}"; \
    micromamba create -y -n pyenv -c conda-forge "python=${PYTHON_VERSION}" pip pyyaml; \
    micromamba clean -a -y

# Install uv into the active Python environment so `uv pip` and `python -m uv`
# always refer to the same environment.
RUN python -m pip install --no-cache-dir --upgrade pip uv

# Pin the CUDA/PyTorch ABI first. Official pairing for PyTorch 2.10 is:
# torch 2.10.0 / torchvision 0.25.0 / torchaudio 2.10.0 with cu130.
RUN uv pip install --python "${VIRTUAL_ENV}/bin/python" --no-cache \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
      "torchaudio==${TORCHAUDIO_VERSION}" \
      --index-url "${TORCH_INDEX_URL}"

# Jupyter / Paperspace utilities and common build/runtime helpers.
RUN uv pip install --python "${VIRTUAL_ENV}/bin/python" --no-cache \
      jupyterlab \
      notebook \
      jupyter-server-proxy \
      hf_transfer \
      "huggingface_hub[cli]" \
      ninja \
      packaging \
      setuptools \
      wheel

# SageAttention 2.2.0 is currently not reliably available from PyPI.
# Build it from the official source tree against the pinned PyTorch/CUDA stack.
# SAGEATTENTION_REF defaults to main and can be overridden with a commit/tag.
RUN set -eux; \
    git clone --depth 1 --branch "${SAGEATTENTION_REF}" \
      https://github.com/thu-ml/SageAttention.git /tmp/SageAttention 2>/dev/null \
    || { \
      git clone https://github.com/thu-ml/SageAttention.git /tmp/SageAttention; \
      git -C /tmp/SageAttention checkout "${SAGEATTENTION_REF}"; \
    }; \
    cd /tmp/SageAttention; \
    "${VIRTUAL_ENV}/bin/python" setup.py install; \
    "${VIRTUAL_ENV}/bin/python" -c 'import sageattention; print("SageAttention import OK")'; \
    rm -rf /tmp/SageAttention

# Paperspace Gradient helper. Keep it isolated from the runtime dependency
# resolver so it cannot replace the pinned torch stack.
RUN uv pip install --python "${VIRTUAL_ENV}/bin/python" --no-cache --no-deps "gradient==2.0.6" \
    && uv pip install --python "${VIRTUAL_ENV}/bin/python" --no-cache \
      "click<9.0" "requests<3.0" marshmallow attrs

# Constraints are also used by /usr/local/bin/comfy-sync so a ComfyUI update or
# custom-node requirements file cannot silently downgrade/replace the ABI stack.
RUN mkdir -p /opt/comfy-runtime \
    && printf '%s\n' \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
      "torchaudio==${TORCHAUDIO_VERSION}" \
      > /opt/comfy-runtime/constraints.txt

COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/runtime-check.sh /usr/local/bin/runtime-check
COPY scripts/comfy-sync.sh /usr/local/bin/comfy-sync
COPY scripts/start-comfyui.sh /usr/local/bin/start-comfyui
RUN chmod +x \
      /usr/local/bin/entrypoint.sh \
      /usr/local/bin/runtime-check \
      /usr/local/bin/comfy-sync \
      /usr/local/bin/start-comfyui

WORKDIR /notebooks
EXPOSE 8888 8188

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.trust_xheaders=True", "--ServerApp.disable_check_xsrf=False", "--ServerApp.allow_remote_access=True", "--ServerApp.allow_origin=*", "--ServerApp.allow_credentials=True"]
