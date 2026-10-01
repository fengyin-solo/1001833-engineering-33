"""内存数据仓库：启动时把已初始化的记录读进内存，运行期在内存里筛选、流转。

数据来源优先级：
1. 初始化脚本（python -m app.init_data）建好的 SQLite 库；
2. 库不存在时回退到内置示例数据，保证直接 `./run.sh` 的老启动方式仍然开箱即用。
"""
from __future__ import annotations

from typing import Any

from app import db
from app.modules import MODULE_KEYS, label_of
from app.seed import SEED_ROWS


def _initial_tables() -> dict[str, list[dict[str, Any]]]:
    tables = db.load_all()
    if tables:
        return tables
    # 未执行过初始化：回退内置示例数据，克隆下来直接起服务也有内容
    return {name: [dict(row) for row in rows] for name, rows in SEED_ROWS.items()}


class Store:
    def __init__(self) -> None:
        self._tables: dict[str, list[dict[str, Any]]] = _initial_tables()

    def module_names(self) -> list[str]:
        # 按登记表顺序返回，概览顺序与归档版一致；登记表外的模块排到末尾
        known = [name for name in MODULE_KEYS if name in self._tables]
        known += sorted(name for name in self._tables if name not in MODULE_KEYS)
        return known

    def rows(self, module: str) -> list[dict[str, Any]]:
        return self._tables.setdefault(module, [])

    def find(self, module: str, entry_id: int) -> dict[str, Any] | None:
        for row in self.rows(module):
            if int(row.get("id", 0)) == entry_id:
                return row
        return None

    def overview(self) -> dict[str, object]:
        modules: list[dict[str, object]] = []
        for name in self.module_names():
            rows = self.rows(name)
            modules.append({
                "name": label_of(name),
                "key": name,
                "created": len(rows),
                "pending": sum(1 for row in rows if row.get("pending")),
                "abnormal": sum(1 for row in rows if row.get("abnormal")),
            })
        cards = [
            {"label": "业务模块", "value": len(modules)},
            {"label": "今日新增", "value": sum(int(item["created"]) for item in modules)},
            {"label": "待处理", "value": sum(int(item["pending"]) for item in modules)},
            {"label": "异常量", "value": sum(int(item["abnormal"]) for item in modules)},
        ]
        return {"cards": cards, "modules": modules}


store = Store()
