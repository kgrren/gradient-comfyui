# ----------------------------------------------------------------------------
# Base Image: CUDA 12.4.1 for Paperspace (A4000 Optimized)
# ----------------------------------------------------------------------------
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

LABEL maintainer="kgrren"

# ------------------------------
# 1. Environment Variables
# ------------------------------
ENV DEBIAN_FRONTEND=noninteractive \
    SHELL=/bin/bash \
    MAMBA_ROOT_PREFIX=/opt/conda \
    PATH=/opt/conda/envs/pyenv/bin:/opt/conda/bin:$PATH \
    CUDA_HOME=/usr/local/cuda \
    TORCH_CUDA_ARCH_LIST="8.6" \
    FORCE_CUDA="1" \
    # Python 3.13でのビルドエラー回避のための設定
    SETUPTOOLS_SCM_PRETEND_VERSION_FOR_UV="0.0.1"

# ------------------------------
# 2. System Packages
# ------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git nano vim unzip zip \
    libgl1 libglib2.0-0 libgoogle-perftools4 \
    build-essential python3-dev \
    ffmpeg \
    bzip2 ca-certificates \
    # ComfyUIの映像・音声処理で必要になることが多いライブラリ
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------
# 3. Micromamba & uv Setup
# ------------------------------
RUN set -ex; \
    arch=$(uname -m); \
    if [ "$arch" = "x86_64" ]; then arch="linux-64"; fi; \
    curl -Ls "https://micro.mamba.pm/api/micromamba/${arch}/latest" -o /tmp/micromamba.tar.bz2; \
    tar -xj -C /usr/local/bin/ --strip-components=1 -f /tmp/micromamba.tar.bz2 bin/micromamba; \
    rm /tmp/micromamba.tar.bz2; \
    mkdir -p $MAMBA_ROOT_PREFIX; \
    micromamba shell init -s bash; \
    # uvのインストール
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv; \
    # Python 3.13 環境の作成
    micromamba create -y -n pyenv -c conda-forge python=3.13 pyyaml; \
    micromamba clean -a -y

# ------------------------------
# 4. Torch Stack (Fixed Versions)
# ------------------------------
# 要求仕様: Torch 2.6.0 / CUDA 12.4
RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python \
    torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 \
    --index-url https://download.pytorch.org/whl/cu124

# ------------------------------
# 5. Core Libraries & Jupyter
# ------------------------------
# Python 3.13 に対応するため、JupyterLabのバージョン固定(3.6.5)を解除し、最新版(v4系)を入れます。
# これにより互換性のない古い y-py が除外され、ビルドが通るようになります。
RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python \
    jupyterlab notebook jupyter-server-proxy \
    ninja packaging wheel setuptools

# ------------------------------
# 6. ComfyUI Dependencies (Pre-install)
# ------------------------------
# 本体をcloneしていなくても動くように、一般的なrequirementsを先に入れておく
RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python \
    transformers diffusers accelerate \
    numpy safetensors aiohttp pyyaml Pillow scipy tqdm psutil \
    kornia soundfile imageio imageio-ffmpeg \
    opencv-python einops

# ------------------------------
# 7. Specialized Libraries (Nunchaku, Optimization)
# ------------------------------
# Nunchaku (Fixed URL)
RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python \
    https://github.com/nunchaku-ai/nunchaku/releases/download/v1.0.1/nunchaku-1.0.1+torch2.6-cp313-cp313-linux_x86_64.whl

# Flash Attention & SageAttention
# ※ Flash-attnはビルド済みホイールがない場合、ビルドに時間がかかりますがuvが管理します
# RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python flash-attn --no-build-isolation
RUN uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python sageattention

# ------------------------------
# 8. Gradient Specifics
# ------------------------------
RUN uv pip install --no-cache --no-deps -p /opt/conda/envs/pyenv/bin/python gradient==2.0.6 && \
    uv pip install --no-cache -p /opt/conda/envs/pyenv/bin/python \
    "click<9.0" "requests<3.0" marshmallow attrs

# ------------------------------
# 9. Final Configuration
# ------------------------------
COPY jupyter_server_config.py /etc/jupyter/jupyter_server_config.py

WORKDIR /notebooks
COPY scripts/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
RUN mkdir -p /tmp/comfy_models

EXPOSE 8888 8188

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["jupyter", "lab", \
     "--allow-root", \
     "--ip=0.0.0.0", \
     "--port=8888", \
     "--no-browser", \
     "--ServerApp.trust_xheaders=True", \
     "--ServerApp.disable_check_xsrf=False", \
     "--ServerApp.allow_remote_access=True", \
     "--ServerApp.allow_origin='*'", \
     "--ServerApp.allow_credentials=True"]
