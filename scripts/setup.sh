#!/usr/bin/env bash
# 本地联调一条龙：清理 → 装依赖 → 灌示例数据 → 配代理 → 自检。
#
# 用法：
#   scripts/setup.sh              跑完整流程（等价 make setup）
#   scripts/setup.sh --only 步骤  只跑某一步：clean / deps / seed / proxy / verify
#
# 每一步都会打印成功还是失败；任何一步失败都会停下并指出卡在哪。
# 完整流程先清掉上次生成的中间产物（.venv、数据快照、代理配置），可反复执行。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"
DATA_FILE="$BACKEND/data/seed.json"
PROXY_FILE="$FRONTEND/.env.development.local"
BACKEND_PORT="${BACKEND_PORT:-8000}"
PROXY_TARGET="${VITE_PROXY_TARGET:-http://127.0.0.1:${BACKEND_PORT}}"

source "$ROOT/scripts/lib.sh"

step_clean() {
  step "1/5" "清理上次中间产物"
  local removed=0
  for path in "$BACKEND/.venv" "$BACKEND/data" "$PROXY_FILE"; do
    if [ -e "$path" ]; then
      rm -rf "$path"
      info "已删除 ${path#"$ROOT"/}"
      removed=1
    fi
  done
  # 上次运行留下的 Python 字节码缓存
  if find "$BACKEND/app" -type d -name __pycache__ | grep -q .; then
    find "$BACKEND/app" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    info "已删除 backend/app 下的 __pycache__"
    removed=1
  fi
  [ "$removed" -eq 0 ] && info "没有需要清理的产物"
  ok "清理完成"
}

step_deps() {
  step "2/5" "安装依赖（版本只认锁文件）"
  if [ ! -x "$BACKEND/.venv/bin/python" ]; then
    info "创建后端虚拟环境 backend/.venv"
    ensure_venv "$BACKEND/.venv"
  fi
  (cd "$BACKEND" && .venv/bin/pip install -q -r requirements.txt)
  (cd "$BACKEND" && .venv/bin/python -c "import fastapi, uvicorn, pydantic" 2>/dev/null) \
    || { fail "后端依赖装完但导入失败，检查 backend/requirements.txt"; return 1; }
  ok "后端依赖就绪（backend/requirements.txt 锁文件）"

  [ -f "$FRONTEND/package-lock.json" ] || { fail "缺 frontend/package-lock.json，锁文件必须提交入库"; return 1; }
  (cd "$FRONTEND" && npm ci --no-audit --no-fund)
  [ -x "$FRONTEND/node_modules/.bin/vite" ] || { fail "前端依赖装完但缺 vite，检查 package-lock.json"; return 1; }
  ok "前端依赖就绪（package-lock.json 锁文件，npm ci）"
}

step_seed() {
  step "3/5" "初始化示例数据（生成归档版快照）"
  [ -x "$BACKEND/.venv/bin/python" ] || { fail "缺后端虚拟环境，先跑 --only deps"; return 1; }
  (cd "$BACKEND" && .venv/bin/python -m app.seed)
  [ -f "$DATA_FILE" ] || { fail "快照未生成：${DATA_FILE#"$ROOT"/}"; return 1; }
  ok "示例数据已初始化：${DATA_FILE#"$ROOT"/}"
}

step_proxy() {
  step "4/5" "生成前端代理配置"
  cat > "$PROXY_FILE" <<EOF
# 由 scripts/setup.sh 生成，重跑会被覆盖；临时改代理请导出 VITE_PROXY_TARGET 后再 npm run dev。
VITE_PROXY_TARGET=$PROXY_TARGET
EOF
  ok "代理配置已写入 ${PROXY_FILE#"$ROOT"/}（/api → $PROXY_TARGET）"
}

step_verify() {
  step "5/5" "联调自检"
  "$ROOT/scripts/verify.sh"
}

ALL_STEPS=(clean deps seed proxy verify)
CURRENT_STEP=""
trap 'rc=$?; if [ "$rc" -ne 0 ] && [ -n "$CURRENT_STEP" ]; then fail "卡在步骤 [$CURRENT_STEP]，处理后直接重跑同一条命令即可"; fi' EXIT

run_step() {
  CURRENT_STEP="$1"
  case "$1" in
    clean)  step_clean ;;
    deps)   step_deps ;;
    seed)   step_seed ;;
    proxy)  step_proxy ;;
    verify) step_verify ;;
    *) fail "未知步骤：$1（可选：${ALL_STEPS[*]}）"; exit 2 ;;
  esac
  CURRENT_STEP=""
}

ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only)   ONLY="${2:?--only 需要步骤名}"; shift 2 ;;
    --only=*) ONLY="${1#*=}"; shift ;;
    -h|--help) grep '^#' "$0" | head -9; exit 0 ;;
    *) fail "未知参数：$1"; exit 2 ;;
  esac
done

if [ -n "$ONLY" ]; then
  IFS=',' read -ra picked <<< "$ONLY"
  for name in "${picked[@]}"; do run_step "$name"; done
else
  for name in "${ALL_STEPS[@]}"; do run_step "$name"; done
fi

ok "全部完成：make backend 起后端，make frontend 起前端"
