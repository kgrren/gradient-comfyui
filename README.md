# gradient-comfyui-cu13

Paperspace Gradient / RTX A4000向けのComfyUIランタイムです。

ComfyUI本体と`ComfyUI-Proxy-Patch`はDockerイメージに含めず、既存の`/notebooks/comfyui`をそのまま利用する前提です。

## 構成

- Ubuntu 22.04
- CUDA Toolkit 13.1.1 + cuDNN
- CUDA Forward Compatibility package (`cuda-compat-13-1`)
- Python 3.12
- `uv`
- PyTorch 2.10.0 + cu130
- torchvision 0.25.0
- torchaudio 2.10.0
- SageAttention 2.2.0 (RTX A4000 / sm_86向けビルド)
- JupyterLab
- jupyter-server-proxy

PyTorch 2.10公式のCUDA 13.0 wheelは`torch 2.10.0 / torchvision 0.25.0 / torchaudio 2.10.0`の組み合わせです。
システム側はCUDA Toolkit 13.1.1を使い、PyTorchはcu130 wheelを使います。CUDA 13.x内のminor差で、SageAttentionなどのnative extensionを13.1.1のnvccでビルドできる構成です。

## 1. Docker build

```bash
docker build -t YOUR_DOCKERHUB_USER/gradient-comfyui:torch210-cu130 .
```

GitHub Actionsを使う場合はRepository Secretsに以下を設定します。

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

Release作成時、またはActionsの手動実行でbuild/pushされます。

## 2. Paperspace起動後

まずGPU/CUDA/PyTorch/SageAttentionを確認します。

```bash
runtime-check
```

期待値の目安:

```text
Python              3.12.x
PyTorch             2.10.0+cu130
PyTorch CUDA        13.0
GPU                  NVIDIA RTX A4000
Compute Capability  (8, 6)
SageAttention        import OK
```

`nvidia-smi`が表示する`CUDA Version`と`nvcc --version`、`torch.version.cuda`は同じ値である必要はありません。

## 3. ComfyUIを更新する

既存運用と同じです。

```bash
cd /notebooks/comfyui
git pull
```

その後、Dockerに含まれる同期スクリプトで最新requirementsを入れます。

```bash
comfy-sync
```

`comfy-sync`は`/opt/comfy-runtime/constraints.txt`を使い、以下を固定したままComfyUI requirementsを更新します。

```text
torch==2.10.0
torchvision==0.25.0
torchaudio==2.10.0
sageattention==2.2.0
```

これにより、ComfyUIやcustom nodeのrequirementsからtorchを意図せずdowngrade/upgradeされる事故を減らします。

もし最新ComfyUIが将来torch 2.10より新しい版を必須にした場合は、Docker側のARGを更新してイメージを作り直してください。

## 4. ComfyUI起動

```bash
start-comfyui
```

オプションもそのまま渡せます。

```bash
start-comfyui --preview-method auto
```

通常のJupyter Server Proxyなら以下でアクセスできます。

```text
/proxy/8188/
```

`jupyter_server_config.py`には追加で`/comfyui/`のnamed proxy launcherも設定しています。
既存の`ComfyUI-Proxy-Patch`は`/notebooks/comfyui/custom_nodes/`に置いたままで構いません。

## 5. custom nodeのrequirements

custom nodeが通常のPython依存だけなら、基本はそのノードのrequirementsを`uv`で入れられます。

例:

```bash
cd /notebooks/comfyui/custom_nodes/SOME_NODE
uv pip install --constraint /opt/comfy-runtime/constraints.txt -r requirements.txt
```

native CUDA extensionを含むノードでは、PyTorchをbuild environmentから見せる必要があることがあります。

```bash
uv pip install \
  --constraint /opt/comfy-runtime/constraints.txt \
  --no-build-isolation \
  -r requirements.txt
```

ただし、ノード作者が特定のtorch/CUDA ABI向けwheelだけを配布している場合は、そのwheelの対応版が必要です。

## 6. SageAttention

SageAttentionは削除せず、Docker build時にA4000のCompute Capability 8.6向けにsource buildします。

Dockerfileでは以下を固定しています。

```text
TORCH_CUDA_ARCH_LIST=8.6
MAX_JOBS=4
sageattention==2.2.0
```

動画生成でSageAttentionを使う場合、このまま利用できます。

## 7. CUDA Forward Compatibility

CUDA 13.xは通常r580系ドライバーが基準ですが、Paperspaceのようにホストドライバーを利用者が更新できない環境向けに、NVIDIAのForward Compatibility packageを入れています。

Dockerfileでは:

```text
cuda-compat-13-1
/usr/local/cuda-13.1/compat
```

を利用します。

Paperspace側の実GPU/driverとの組み合わせがForward Compatibility非対応の場合、`runtime-check`のCUDA smoke testで失敗します。その場合はまず`nvidia-smi`全文を確認してください。

## 8. 重要: custom nodeにtorchを変更させない

特に`xformers`や独自wheelを含むcustom nodeでは、通常の依存解決でtorchが別版へ交換されることがあります。

先にrequirementsを確認し、必要ならconstraintsを付けます。

```bash
uv pip install --constraint /opt/comfy-runtime/constraints.txt -r requirements.txt
```

特定packageだけを入れたい場合は、依存が既に揃っていることを確認したうえで`--no-deps`を利用できます。

```bash
uv pip install --no-deps PACKAGE
```

`--no-deps`は依存チェックを完全に止めるため、闇雲には使わないでください。

## 9. ビルド引数

主要バージョンはDocker build argsとして切り出しています。

```bash
docker build \
  --build-arg PYTHON_VERSION=3.12 \
  --build-arg TORCH_VERSION=2.10.0 \
  --build-arg TORCHVISION_VERSION=0.25.0 \
  --build-arg TORCHAUDIO_VERSION=2.10.0 \
  --build-arg SAGEATTENTION_VERSION=2.2.0 \
  -t YOUR_IMAGE .
```

将来torchを更新する際は、PyTorch公式の対応表に合わせてtorch/torchvision/torchaudioとindex URLをセットで変更してください。

## 10. トラブル時に貼る情報

以下をまとめて取得できます。

```bash
runtime-check 2>&1 | tee /notebooks/runtime-check.txt
```

加えてComfyUI起動エラーの場合は:

```bash
cd /notebooks/comfyui
git rev-parse HEAD
uv pip freeze > /notebooks/pip-freeze.txt
```

この3点があれば、CUDA/torch問題なのかComfyUI/custom node問題なのかをかなり早く切り分けできます。
