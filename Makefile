.PHONY: setup clean install init-db backend frontend

# 一条流水线：依赖安装（只认锁文件）→ 建库灌示例数据 → 代理配置 → 冒烟验证
setup:
	bash scripts/setup.sh

# 清理初始化产生的中间产物，回到未初始化状态
clean:
	rm -rf backend/.venv backend/data frontend/node_modules frontend/.vite frontend/dist frontend/.env.local .setup-logs
	find backend -type d -name __pycache__ -prune -exec rm -rf {} +

# 两边依赖统一按锁文件安装：后端 requirements.lock，前端 package-lock.json
install:
	cd backend && (python3 -m venv .venv >/dev/null 2>&1 || python3 -m venv --without-pip .venv)
	cd backend && ([ -x .venv/bin/pip ] || (curl -sS https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py && .venv/bin/python /tmp/get-pip.py))
	cd backend && .venv/bin/pip install -r requirements.lock
	cd frontend && npm ci

# 删旧库并重新灌入示例数据（需要先 install）
init-db:
	cd backend && .venv/bin/python -m app.init_data

backend:
	cd backend && ./run.sh

frontend:
	cd frontend && npm run dev
