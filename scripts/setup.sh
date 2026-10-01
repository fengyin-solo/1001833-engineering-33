#!/usr/bin/env bash
# 一键本地联调初始化：依赖安装 → 示例数据初始化 → 前端代理配置 → 冒烟验证。
# 每一步都打印成功/失败，失败立即停下并保留日志；成功跑完会清掉本次日志。
# 幂等：重跑先清理上次的虚拟环境、数据库、node_modules、代理配置等中间产物。
#
# 用法：bash scripts/setup.sh
# 可用环境变量：
#   BACKEND_URL  前端 /api 代理目标（默认 http://127.0.0.1:8000）
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
FRONTEND_DIR="$ROOT_DIR/frontend"
BACKEND_URL="${BACKEND_URL:-http://127.0.0.1:8000}"
# 统一去掉结尾斜杠，避免拼出 //api/health、端口号带斜杠等问题
BACKEND_URL="${BACKEND_URL%/}"
LOG_DIR="$ROOT_DIR/.setup-logs"

BACKEND_PORT="${BACKEND_URL##*:}"
BACKEND_PORT="${BACKEND_PORT%%/*}"
FRONTEND_PORT=5173

step_no=0
total_steps=7

c_red=$'\033[31m'; c_green=$'\033[32m'; c_blue=$'\033[34m'; c_reset=$'\033[0m'

step() {
  step_no=$((step_no + 1))
  printf '\n%s[%d/%d] %s%s\n' "$c_blue" "$step_no" "$total_steps" "$1" "$c_reset"
}

ok() {
  printf '%s  ✓ %s%s\n' "$c_green" "$1" "$c_reset"
}

die() {
  printf '%s  ✗ %s%s\n' "$c_red" "$1" "$c_reset"
  printf '%s初始化失败，卡在第 %d/%d 步。详细日志见：%s%s\n' \
    "$c_red" "$step_no" "$total_steps" "$LOG_DIR" "$c_reset"
  exit 1
}

trap 'die "脚本被中断或命令异常退出"' ERR

# ---------- 1. 预检：工具链、锁文件、端口占用，早失败、说清楚缺什么 ----------
step "预检运行环境"
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"

command -v python3 >/dev/null 2>&1 || die "找不到 python3，请先安装 Python 3.10+"
command -v node >/dev/null 2>&1 || die "找不到 node，请先安装 Node.js 18+"
command -v npm >/dev/null 2>&1 || die "找不到 npm，请先安装 Node.js（自带 npm）"
command -v curl >/dev/null 2>&1 || die "找不到 curl，请先安装 curl"

[ -f "$BACKEND_DIR/requirements.lock" ] || die "缺少 backend/requirements.lock，依赖版本无从确认"
[ -f "$FRONTEND_DIR/package-lock.json" ] || die "缺少 frontend/package-lock.json，依赖版本无从确认"

port_busy() {
  # 返回 0 表示端口已被占用；优先用系统自带工具探测，不引入额外依赖
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$1" >/dev/null 2>&1
  elif command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else
    # 兜底：让内核尝试连接，通了说明端口有人监听
    (exec 3<>"/dev/tcp/127.0.0.1/$1") >/dev/null 2>&1
  fi
}
port_busy "$BACKEND_PORT" && die "端口 $BACKEND_PORT 已被占用（后端需要监听），请先释放后重跑"
port_busy "$FRONTEND_PORT" && die "端口 $FRONTEND_PORT 已被占用（前端 dev server 需要监听），请先释放后重跑"

ok "python3 $(python3 --version 2>&1 | awk '{print $2}') / node $(node --version) / 锁文件与端口检查通过"

# ---------- 2. 清理上次的中间产物，保证重跑结果与首跑一致 ----------
step "清理上次的中间产物"
rm -rf "$BACKEND_DIR/.venv"
rm -rf "$FRONTEND_DIR/node_modules"
rm -rf "$BACKEND_DIR/data"
rm -rf "$FRONTEND_DIR/.vite" "$FRONTEND_DIR/dist"
# .env.local 是本流程生成的代理配置（已被 .gitignore 忽略），重跑直接覆盖
rm -f "$FRONTEND_DIR/.env.local"
find "$BACKEND_DIR" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
ok "已清理 .venv / node_modules / 数据库 / 构建缓存 / 旧代理配置"

# ---------- 3. 后端依赖：建虚拟环境，只从 requirements.lock 安装 ----------
step "安装后端依赖（只认 backend/requirements.lock）"
# 部分系统的 venv 不带 ensurepip：第一次尝试失败时改用 --without-pip，再引导 pip
if ! python3 -m venv "$BACKEND_DIR/.venv" >/dev/null 2>&1; then
  rm -rf "$BACKEND_DIR/.venv"
  python3 -m venv --without-pip "$BACKEND_DIR/.venv" >/dev/null 2>&1
fi
if [ ! -x "$BACKEND_DIR/.venv/bin/pip" ]; then
  echo "venv 未自带 pip，使用 get-pip.py 引导" >>"$LOG_DIR/01-backend-venv.log"
  curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py \
    2>>"$LOG_DIR/01-backend-venv.log"
  "$BACKEND_DIR/.venv/bin/python" /tmp/get-pip.py >>"$LOG_DIR/01-backend-venv.log" 2>&1
fi
"$BACKEND_DIR/.venv/bin/python" -m pip install --disable-pip-version-check \
  -r "$BACKEND_DIR/requirements.lock" >"$LOG_DIR/02-backend-pip.log" 2>&1 \
  || die "后端依赖安装失败，日志：$LOG_DIR/02-backend-pip.log"
"$BACKEND_DIR/.venv/bin/python" -c "import fastapi, uvicorn, pydantic" \
  || die "后端关键依赖无法导入，日志：$LOG_DIR/02-backend-pip.log"
ok "后端依赖安装完成（fastapi / uvicorn / pydantic 已锁定版本）"

# ---------- 4. 建库灌示例数据：删旧库 → 建表 → 灌入 → 回查校验 ----------
step "初始化示例数据库"
(
  cd "$BACKEND_DIR"
  .venv/bin/python -m app.init_data
) 2>&1 | tee "$LOG_DIR/03-init-data.log"
[ "$(tail -n1 "$LOG_DIR/03-init-data.log")" = "[完成] 数据库初始化成功" ] \
  || die "示例数据初始化未通过回查校验，日志：$LOG_DIR/03-init-data.log"
ok "数据库已重建并通过回查：18 个业务模块、54 条记录，与概览卡片对齐"

# ---------- 5. 前端依赖：npm ci 严格按 package-lock.json 安装 ----------
step "安装前端依赖（只认 frontend/package-lock.json）"
(
  cd "$FRONTEND_DIR"
  npm ci --no-audit --no-fund
) >"$LOG_DIR/04-frontend-npm.log" 2>&1 || die "前端依赖安装失败，日志：$LOG_DIR/04-frontend-npm.log"
(
  cd "$FRONTEND_DIR"
  npm run typecheck
) >"$LOG_DIR/05-frontend-typecheck.log" 2>&1 || die "前端类型检查失败，日志：$LOG_DIR/05-frontend-typecheck.log"
ok "前端依赖安装完成并通过 vue-tsc 类型检查"

# ---------- 6. 代理配置：写入 .env.local，不手改任何已跟踪文件，重跑幂等覆盖 ----------
step "写入前端代理配置"
cat >"$FRONTEND_DIR/.env.local" <<EOF
# 由 scripts/setup.sh 生成，请勿手工修改或提交；重跑初始化会覆盖本文件。
VITE_PROXY_TARGET=$BACKEND_URL
EOF
ok "frontend/.env.local -> /api 代理到 $BACKEND_URL"

# ---------- 7. 冒烟：真实拉起前后端，验证健康接口与代理链路，随后自动停掉 ----------
step "冒烟验证（拉起后端 + 前端 dev server）"
# setsid 让每个服务自成进程组，清理时按组杀掉，避免 npm 退出后 vite 子进程残留占端口
if command -v setsid >/dev/null 2>&1; then
  GROUP="setsid"
else
  GROUP=""
fi
$GROUP bash -c 'cd "$1" && exec .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "$2"' \
  _ "$BACKEND_DIR" "$BACKEND_PORT" >"$LOG_DIR/06-backend-run.log" 2>&1 &
BACKEND_PID=$!

$GROUP bash -c 'cd "$1" && exec npm run dev' \
  _ "$FRONTEND_DIR" >"$LOG_DIR/07-frontend-run.log" 2>&1 &
FRONTEND_PID=$!

# setsid 下 $! 是子进程组组长，取负 PID 即可整组终止；否则退回逐 PID 终止
if [ -n "$GROUP" ]; then
  BACKEND_TERM="-$BACKEND_PID"
  FRONTEND_TERM="-$FRONTEND_PID"
else
  BACKEND_TERM="$BACKEND_PID"
  FRONTEND_TERM="$FRONTEND_PID"
fi

cleanup_servers() {
  # 注意：负 PID 表示整个进程组，必须用「-s 信号 -- -PGID」写法，
  # 否则 bash 会把 -1035 当成信号名而不是进程组
  kill -TERM -- $FRONTEND_TERM $BACKEND_TERM >/dev/null 2>&1 || true
  sleep 1
  kill -KILL -- $FRONTEND_TERM $BACKEND_TERM >/dev/null 2>&1 || true
  wait "$FRONTEND_PID" "$BACKEND_PID" 2>/dev/null || true
}

wait_for_url() {
  # $1=URL $2=最多重试次数；每 0.5 秒探一次
  local url="$1" tries="$2" n=1
  while [ "$n" -le "$tries" ]; do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    n=$((n + 1))
    sleep 0.5
  done
  return 1
}

# 兜底：确保整个脚本以任何方式退出时都不会留下冒烟进程
SMOKE_OK=0
on_exit() {
  # 早期步骤失败时冒烟进程还没启动，进程组变量为空，直接跳过清理
  if [ -n "${FRONTEND_TERM:-}" ]; then
    cleanup_servers
  fi
  [ "${SMOKE_OK:-0}" = "1" ] || exit 1
}
trap on_exit EXIT
trap 'die "脚本被中断或命令异常退出"' INT TERM

wait_for_url "$BACKEND_URL/api/health" 60 \
  || die "后端健康检查未通过，日志：$LOG_DIR/06-backend-run.log"
ok "后端健康接口就绪：$BACKEND_URL/api/health"

wait_for_url "http://127.0.0.1:$FRONTEND_PORT/" 60 \
  || die "前端 dev server 未就绪，日志：$LOG_DIR/07-frontend-run.log"
ok "前端 dev server 就绪：http://127.0.0.1:$FRONTEND_PORT/"

# 直接打后端：确认初始化的模块数与运营概览卡片一致（18）
"$BACKEND_DIR/.venv/bin/python" - "$BACKEND_URL" <<'PY' \
  || die "后端模块数与概览卡片不一致，见 $LOG_DIR/06-backend-run.log"
import json
import sys
import urllib.request

health = json.load(urllib.request.urlopen(sys.argv[1] + "/api/health"))
overview = json.load(urllib.request.urlopen(sys.argv[1] + "/api/overview"))
assert health["modules"] == 18, f"health modules={health['modules']}"
card = next(item["value"] for item in overview["cards"] if item["label"] == "业务模块")
assert card == 18, f"overview card={card}"
assert len(overview["modules"]) == 18, f"overview rows={len(overview['modules'])}"
print(f"       后端 /api/overview：业务模块卡片={card}，模块明细={len(overview['modules'])} 行")
PY
ok "后端概览模块数 = 18，与「业务模块」卡片对齐"

# 经 vite 代理再打一次：证明第 6 步的代理配置真正生效
curl -fsS "http://127.0.0.1:$FRONTEND_PORT/api/health" \
  | "$BACKEND_DIR/.venv/bin/python" -c "import json,sys; d=json.load(sys.stdin); assert d['ok'] and d['modules']==18, d" \
  || die "经 vite 代理访问 /api/health 失败，见 $LOG_DIR/07-frontend-run.log"
ok "经 vite 代理访问 /api/health 成功，代理链路通畅"

trap - INT TERM
SMOKE_OK=1

rm -rf "$LOG_DIR"
printf '\n%s全部完成：依赖、示例数据、代理配置已就绪，冒烟验证通过。%s\n' "$c_green" "$c_reset"
printf '启动方式（老方式保持可用）：\n'
printf '  后端  make backend   或  cd backend && ./run.sh\n'
printf '  前端  make frontend  或  cd frontend && npm run dev\n'
