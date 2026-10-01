"""SQLite 持久层：初始化脚本写库、运行时仓库读库都走这里。

只用标准库 sqlite3，不增加第三方依赖。库文件路径由环境变量 APP_DB_PATH 覆盖，
默认放在 backend/data/app.db；同目录下还可能有 -wal/-shm 两个 WAL 伴随文件。
"""
from __future__ import annotations

import os
import sqlite3
from pathlib import Path
from typing import Any

DEFAULT_DB_PATH = Path(__file__).resolve().parent.parent / "data" / "app.db"

WAL_SUFFIXES = ("", "-wal", "-shm")


def db_path() -> Path:
    return Path(os.environ.get("APP_DB_PATH") or DEFAULT_DB_PATH)


def exists() -> bool:
    """库文件是否已经初始化过。"""
    return db_path().is_file()


def reset_database(path: Path | None = None) -> Path:
    """删掉旧库及其 WAL 伴随文件，再建一个空库。

    保证重跑初始化不会残留上一次的表结构或脏数据；不删 backend/data 目录本身。
    """
    target = path or db_path()
    for suffix in WAL_SUFFIXES:
        stale = Path(str(target) + suffix)
        if stale.exists():
            stale.unlink()
    target.parent.mkdir(parents=True, exist_ok=True)
    with connect(target) as conn:
        conn.execute(
            """
            CREATE TABLE records (
                module     TEXT NOT NULL,
                entry_id   INTEGER NOT NULL,
                data       TEXT NOT NULL,
                PRIMARY KEY (module, entry_id)
            )
            """
        )
        conn.execute("CREATE INDEX idx_records_module ON records (module)")
        conn.commit()
    return target


def connect(path: Path | None = None) -> sqlite3.Connection:
    target = path or db_path()
    conn = sqlite3.connect(str(target))
    # 外键打开、读出来的字段名按建表定义返回，避免大小写折叠带来的意外
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def insert_rows(conn: sqlite3.Connection, module: str, rows: list[dict[str, Any]]) -> None:
    """整模块批量写入；data 列存 JSON，ensure_ascii=False 保留中文原文。"""
    import json

    conn.executemany(
        "INSERT INTO records (module, entry_id, data) VALUES (?, ?, ?)",
        [
            (module, int(row["id"]), json.dumps(row, ensure_ascii=False, sort_keys=True))
            for row in rows
        ],
    )


def load_all() -> dict[str, list[dict[str, Any]]]:
    """把库里的记录按模块全部读回内存。

    运行时仍是进程内内存仓库（状态流转不改库），与原有行为保持一致；
    库不存在时返回空字典，由 store 决定是否回退到内置示例数据。
    """
    import json

    if not exists():
        return {}
    tables: dict[str, list[dict[str, Any]]] = {}
    with connect() as conn:
        for module, payload in conn.execute(
            "SELECT module, data FROM records ORDER BY module, entry_id"
        ):
            tables.setdefault(module, []).append(json.loads(payload))
    return tables
