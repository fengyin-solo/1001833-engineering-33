#!/usr/bin/env bash
# 联调自检：用初始化出来的快照临时起后端，核对运营概览的业务模块卡片与初始化结果一致，
# 再确认前端代理配置已生成。自检服务用完即杀，不留进程。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
DATA_FILE="$BACKEND/data/seed.json"
PROXY_FILE="$ROOT/frontend/.env.development.local"
PORT="${VERIFY_PORT:-8765}"
BASE="http://127.0.0.1:${PORT}"

source "$ROOT/scripts/lib.sh"

PY="$BACKEND/.venv/bin/python"
[ -x "$PY" ] || { fail "缺后端虚拟环境，先跑 scripts/setup.sh --only deps"; exit 1; }
[ -f "$DATA_FILE" ] || { fail "缺示例数据快照，先跑 scripts/setup.sh --only seed"; exit 1; }

expected="$("$PY" -c "import json; print(len(json.load(open('$DATA_FILE'))['modules']))")"
info "初始化出来的业务模块数：$expected"

if curl -fsS "$BASE/api/health" --max-time 2 >/dev/null 2>&1; then
  fail "端口 $PORT 已被占用（可能是上次自检的残留进程），先杀掉再重跑"
  exit 1
fi

log="$(mktemp)"
server_pid=""
cleanup() {
  if [ -n "$server_pid" ]; then
    kill "$server_pid" 2>/dev/null || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -f "$log"
}
trap cleanup EXIT

# 直接起 uvicorn（不套子 shell），保证 $! 就是服务进程本身，退出时能杀干净
"$BACKEND/.venv/bin/uvicorn" --app-dir "$BACKEND" app.main:app \
  --host 127.0.0.1 --port "$PORT" >"$log" 2>&1 &
server_pid=$!

ready=""
for _ in $(seq 1 40); do
  if curl -fsS "$BASE/api/health" >/dev/null 2>&1; then ready=1; break; fi
  kill -0 "$server_pid" 2>/dev/null || break
  sleep 0.5
done
if [ -z "$ready" ]; then
  fail "自检服务没起来（127.0.0.1:$PORT），最近日志："
  tail -n 5 "$log" >&2 || true
  exit 1
fi
ok "后端自检服务已监听 $BASE"

overview="$(curl -fsS "$BASE/api/overview")" || { fail "/api/overview 请求失败"; exit 1; }
read -r actual version <<<"$("$PY" - "$overview" <<'PYEOF'
import json, sys
data = json.loads(sys.argv[1])
card = next(c for c in data["cards"] if c["label"] == "业务模块")
print(card["value"], data.get("data_version", "?"))
PYEOF
)"

if [ "$actual" != "$expected" ]; then
  fail "概览卡片业务模块=$actual，与初始化结果 $expected 不一致"
  exit 1
fi
ok "运营概览业务模块卡片=$actual，与初始化结果对齐（存量数据版本：$version）"

if [ -f "$PROXY_FILE" ] && grep -q '^VITE_PROXY_TARGET=' "$PROXY_FILE"; then
  ok "前端代理配置已生成：${PROXY_FILE#"$ROOT"/}"
else
  fail "缺前端代理配置，先跑 scripts/setup.sh --only proxy"
  exit 1
fi
