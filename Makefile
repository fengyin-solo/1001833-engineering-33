.PHONY: setup install seed verify clean backend frontend

# 一条流程跑通本地联调：清理 → 装依赖 → 灌示例数据 → 配代理 → 自检
setup:
	./scripts/setup.sh

# 只装依赖（后端按 requirements.txt 锁文件，前端按 package-lock.json 锁文件）
install:
	./scripts/setup.sh --only deps

# 只重灌示例数据（归档版快照）
seed:
	./scripts/setup.sh --only seed

# 只做联调自检（概览卡片与初始化结果对齐校验）
verify:
	./scripts/setup.sh --only verify

# 清掉本次生成的中间产物（.venv、数据快照、代理配置、__pycache__）
clean:
	./scripts/setup.sh --only clean

backend:
	cd backend && ./run.sh

frontend:
	cd frontend && npm run dev
