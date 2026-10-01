# 城市地下管网巡检养护平台

面向城市给排水与燃气管网的管段建档、检查井阀门、巡查巡检、内窥检测、缺陷修复与压力流量监测的一体化养护后台。

这是一个前后端分离的管理平台：前端 Vue 3 + Vite + TypeScript，后端 FastAPI（Python）。
两边各自独立启动，前端 dev server 已关掉自动打开页面，启动后按终端打印的地址手工打开。

## 目录结构

```text
.
├── frontend/                 Vue 3 + Vite + TypeScript 前端
│   ├── src/views/            每个业务模块一个页面
│   ├── src/api/              统一请求封装
│   ├── src/stores/           会话与筛选状态
│   └── vite.config.ts        dev server 配置（open: false）
├── backend/                  FastAPI（Python） 后端
│   ├── app/routers/          每个业务模块一组接口
│   ├── app/services/         业务规则与状态流转
│   └── app/store.py          内存数据仓库与示例数据
├── .gitignore
└── docker-compose.yml
```

## 启动

### 一键初始化（推荐）

克隆后只跑一条命令，把「装依赖 → 建库灌示例数据 → 写前端代理 → 冒烟验证」串成一条可重复的流水线：

```bash
make setup        # 等价于 bash scripts/setup.sh
```

流程共 7 步，每一步都会打印 ✓ 成功或 ✗ 失败，失败立即停下并提示卡在第几步、日志在哪：

1. 预检 python3/node/npm、锁文件、8000/5173 端口占用
2. 清理上次的中间产物（`.venv`、`node_modules`、SQLite 库、构建缓存、`.env.local`）
3. 后端建虚拟环境并**只按 `backend/requirements.lock`** 安装依赖
4. `python -m app.init_data`：删旧库 → 建表 → 灌入 18 个模块共 54 条示例数据 → 回查校验
5. 前端 `npm ci` **只按 `frontend/package-lock.json`** 安装，并跑类型检查
6. 生成 `frontend/.env.local`，把 `/api` 代理到后端（不再手改配置；可用 `BACKEND_URL=` 覆盖）
7. 真实拉起前后端冒烟：直连后端查 `/api/health`、`/api/overview`（业务模块卡片必须为 18），
   再经 vite 代理访问 `/api/health`，验证通过后自动停掉冒烟进程

初始化是幂等的：重跑会先清理再重建，不留下上一次的中间产物。冒烟临时服务也只活在脚本执行期间。

初始化成功后，日常启动仍用下面的老命令（行为保持不变）：

```bash
make backend      # 或 cd backend && ./run.sh
make frontend     # 或 cd frontend && npm run dev
```

其他辅助命令：

```bash
make init-db      # 只重建示例数据库（删旧库 → 灌数 → 回查）
make clean        # 清掉所有本地中间产物，回到未初始化状态
```

### 手动启动（老方式，继续可用）

#### 后端

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.lock
.venv/bin/python -m app.init_data   # 可选：初始化 SQLite 示例库；不做也能用内置数据启动
./run.sh
```

健康检查：`curl http://127.0.0.1:8000/api/health`

#### 前端

```bash
cd frontend
npm ci            # 严格按 package-lock.json 安装
npm run dev
```

前端默认监听 `http://127.0.0.1:5173/`，dev server 不会自动打开浏览器，
需要自己访问。`/api` 由 vite 代理到后端 `http://127.0.0.1:8000`；
代理目标由 `VITE_PROXY_TARGET`（环境变量或 `.env.local`）覆盖。

### 依赖版本约定

依赖版本只认锁文件这一处，所有安装入口（`scripts/setup.sh`、`run.sh`、
两个 Dockerfile、`make install`）统一从锁文件取：

- 后端：`backend/requirements.lock`（精确 `==` 锁定，含传递依赖）；
  `requirements.txt` 只保留直接依赖声明，不作为安装依据。
- 前端：`frontend/package-lock.json`，安装统一用 `npm ci`。

示例数据存放在 SQLite（`backend/data/app.db`，已在 `.gitignore` 忽略），
模块清单以 `backend/app/modules.py` 为唯一登记表，初始化出来的业务模块数
与运营概览「业务模块」卡片一致（18 个）。


## 业务模块

| 模块 | 目录 | 业务对象 | 主要字段 |
| --- | --- | --- | --- |
| 管段档案 | `pipe` | 管段 | 管段编号、管道类别、起点井号 |
| 检查井 | `manhole` | 检查井 | 井编号、所在道路、井盖类别 |
| 阀门井室 | `valve` | 阀门 | 阀门编号、阀门类别、所在管段 |
| 泵站设施 | `pumpstation` | 泵站 | 泵站编号、泵站名称、服务区域 |
| 巡查任务 | `patrol` | 巡查单 | 巡查单号、巡查路线、巡查人员 |
| 缺陷登记 | `defect` | 缺陷记录 | 缺陷编号、所在管段、缺陷类别 |
| 内窥检测 | `cctv` | 检测报告 | 检测编号、检测管段、检测设备 |
| 修复施工 | `repair` | 修复单 | 修复单号、关联缺陷、修复方式 |
| 压力监测 | `pressure` | 压力记录 | 监测编号、监测点位、监测时段 |
| 流量监测 | `flow` | 流量记录 | 监测编号、监测断面、监测时段 |
| 泄漏排查 | `leak` | 排查记录 | 排查编号、排查区域、排查方式 |
| 清淤疏浚 | `dredge` | 清淤单 | 清淤单号、清淤管段、淤积厚度 |
| 养护材料 | `material` | 养护材料 | 材料编号、材料名称、规格型号 |
| 养护机械 | `equip` | 养护机械 | 机械编号、机械名称、机械型号 |
| 占道许可 | `traffic` | 占道许可 | 许可编号、申请单位、占道位置 |
| 公众诉求 | `complaint` | 诉求记录 | 诉求编号、诉求来源、诉求内容 |
| 养护资金 | `fund` | 资金记录 | 资金编号、费用类别、项目名称 |
| 管网档案 | `archive` | 档案记录 | 档案编号、关联管段、档案类别 |

## 约定

- 每个模块的前端页面在 `frontend/src/views/<模块>/index.vue`，后端接口在
  `backend/app/routers/<模块>.py`，业务规则在 `backend/app/services/<模块>.py`。
- 列表接口统一返回 `{ items, total, page, size }`，动作接口统一返回 `{ ok, message }`。
- 状态流转只允许在 `app/services` 里改，路由层不做业务判断。
