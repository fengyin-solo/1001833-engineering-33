# 共用小函数：分步日志、失败定位、虚拟环境创建。被 setup.sh / verify.sh source。
# 输出约定：==> 步骤标题、✓ 成功、✗ 失败（走 stderr）、! 提醒。

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_STEP=$'\033[1;34m'; C_OK=$'\033[1;32m'; C_ERR=$'\033[1;31m'; C_WARN=$'\033[1;33m'; C_OFF=$'\033[0m'
else
  C_STEP=''; C_OK=''; C_ERR=''; C_WARN=''; C_OFF=''
fi

step() { printf '%s==> [%s] %s%s\n' "$C_STEP" "$1" "$2" "$C_OFF"; }
info() { printf '    %s\n' "$1"; }
ok()   { printf '%s    ✓ %s%s\n' "$C_OK" "$1" "$C_OFF"; }
warn() { printf '%s    ! %s%s\n' "$C_WARN" "$1" "$C_OFF"; }
fail() { printf '%s    ✗ %s%s\n' "$C_ERR" "$1" "$C_OFF" >&2; }

ensure_venv() {
  # $1: venv 目录。Debian 这类缺 ensurepip 的系统上自动改用 get-pip 引导。
  local dir="$1"
  if ! python3 -m venv "$dir" >/dev/null 2>&1; then
    warn "python3 -m venv 自带 pip 失败（ensurepip 缺失），改用 get-pip 引导"
    rm -rf "$dir"
    python3 -m venv --without-pip "$dir"
  fi
  if [ ! -x "$dir/bin/pip" ]; then
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL https://bootstrap.pypa.io/get-pip.py -o "$tmp/get-pip.py"
    "$dir/bin/python" "$tmp/get-pip.py" -q
    rm -rf "$tmp"
  fi
}
