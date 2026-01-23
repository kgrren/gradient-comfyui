#!/bin/bash
set -e

# Paperspace /notebooks 権限修正
if [ -d "/notebooks" ]; then
    chmod 777 /notebooks
fi

# Micromamba環境 (Python 3.13) の有効化
eval "$(micromamba shell hook --shell bash)"
micromamba activate pyenv

# コマンド実行
exec "$@"
