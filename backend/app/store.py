"""内存数据仓库：给每个业务模块准备一份可筛选、可流转的示例数据。

数据来源按优先级：
1. `settings.data_path` 指向的快照文件（`python -m app.seed` 生成的归档版），
   运营概览的存量数据就按这一版回填成记录；
2. 快照不存在时退回 `app.seed.SEED_ROWS` 内置数据，保证老的启动方式直接可用。
"""
from __future__ import annotations

import json
from typing import Any

from app.config import settings
from app.seed import BUILTIN_VERSION, SEED_ROWS


def _load_snapshot() -> tuple[dict[str, list[dict[str, Any]]], str] | None:
    path = settings.data_path
    if not path.exists():
        return None
    try:
        snapshot = json.loads(path.read_text(encoding="utf-8"))
        modules = snapshot["modules"]
        version = str(snapshot["version"])
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"示例数据快照 {path} 已损坏，请重跑 make setup 重新初始化：{exc}") from exc
    return (
        {name: [dict(row) for row in rows] for name, rows in modules.items()},
        version,
    )


class Store:
    def __init__(self) -> None:
        snapshot = _load_snapshot()
        if snapshot is None:
            self._tables = {name: [dict(row) for row in rows] for name, rows in SEED_ROWS.items()}
            self.data_version = BUILTIN_VERSION
        else:
            self._tables, self.data_version = snapshot

    def module_names(self) -> list[str]:
        return sorted(self._tables)

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
                "name": name,
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
        return {"cards": cards, "modules": modules, "data_version": self.data_version}


store = Store()
