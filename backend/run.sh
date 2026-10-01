#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# 虚拟环境缺失或损坏（比如从别的机器拷过来的残留）时直接重建
if [ ! -x .venv/bin/python ]; then
  rm -rf .venv
  if ! python3 -m venv .venv >/dev/null 2>&1; then
    # 缺 ensurepip 的系统（Debian 未装 python3-venv）先建空壳再引导 pip
    python3 -m venv --without-pip .venv
  fi
fi
if [ ! -x .venv/bin/pip ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$tmp/get-pip.py"
  .venv/bin/python "$tmp/get-pip.py" -q
fi
# requirements.txt 即锁文件，版本只认这一处
.venv/bin/pip install -q -r requirements.txt
exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
