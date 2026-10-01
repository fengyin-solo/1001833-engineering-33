#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# 依赖版本只认 requirements.lock 这一处；venv 损坏或缺 pip 时重建，不留半成品
if [ ! -x .venv/bin/python ] || [ ! -x .venv/bin/pip ]; then
  rm -rf .venv
  python3 -m venv .venv >/dev/null 2>&1 || python3 -m venv --without-pip .venv
  if [ ! -x .venv/bin/pip ]; then
    curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
    .venv/bin/python /tmp/get-pip.py
  fi
fi
.venv/bin/pip install -q --disable-pip-version-check -r requirements.lock
exec .venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
