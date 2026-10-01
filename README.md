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
├── scripts/                  联调流水线（setup/verify，make setup 入口）
├── .gitignore
└── docker-compose.yml
```

## 启动

### 一条流程（推荐）

```bash
make setup     # 清理 → 装依赖 → 灌示例数据 → 配代理 → 自检
make backend   # 终端 1：起后端 http://127.0.0.1:8000
make frontend  # 终端 2：起前端 http://127.0.0.1:5173
```

`make setup` 每一步都会打印成功还是失败，失败时指出卡在哪一步；
重跑会先清掉上次生成的中间产物（`.venv`、数据快照、代理配置），可以反复执行。
也可以只跑某一步：`make install`（只装依赖）、`make seed`（只灌数据）、
`make verify`（只做自检）、`make clean`（只清理）。

健康检查：`curl http://127.0.0.1:8000/api/health`

### 老办法（仍然可用）

```bash
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
./run.sh
```

```bash
cd frontend
npm install
npm run dev
```

前端默认监听 `http://127.0.0.1:5173/`，dev server 不会自动打开浏览器，
需要自己访问。`/api` 由 vite 代理到后端，代理目标按优先级取：
命令行导出的 `VITE_PROXY_TARGET` > `make setup` 生成的
`frontend/.env.development.local` > 默认 `http://127.0.0.1:8000`。

## 依赖版本

版本只认锁文件这一处，各环节（Makefile / run.sh / Dockerfile / CI）统一从这里取：

- 后端：`backend/requirements.txt`（全量锁定，含传递依赖），安装一律 `pip install -r requirements.txt`。
- 前端：`frontend/package-lock.json`，安装一律 `npm ci`。
- 升级依赖：装好后重新生成锁文件（后端回填 `pip freeze` 结果，前端 `npm install` 刷新 lock），连同锁文件一起提交。

## 示例数据

- `make setup` 会执行 `python -m app.seed`，把归档版快照写到 `backend/data/seed.json`
  （生成物，不入 git），并打印各模块记录数。
- 后端启动时优先从这份快照回填记录，运营概览的存量数据即按这一版生成；
  快照缺失时退回内置示例数据，老启动方式不受影响。
- 自检环节会临时起服务核对：概览「业务模块」卡片的数值与初始化出来的模块数一致。

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
