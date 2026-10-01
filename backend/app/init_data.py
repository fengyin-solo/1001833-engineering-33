"""示例数据初始化：删旧库 → 建表 → 灌示例数据 → 回查校验，全流程可重复执行。

用法：
    .venv/bin/python -m app.init_data

每一步都打印成功/失败：模块与登记表对不上、某个模块缺记录时直接非零退出，
不静默吞错，方便定位卡在灌库的哪一段。
"""
from __future__ import annotations

import sys

from app import db
from app.modules import MODULES, MODULE_KEYS
from app.seed import SEED_ROWS


def run() -> int:
    # 1. 前置校验：示例数据覆盖的模块必须与登记表完全一致，避免概览卡片与模块数对不齐
    seed_keys = tuple(sorted(SEED_ROWS))
    if seed_keys != tuple(sorted(MODULE_KEYS)):
        missing = sorted(set(MODULE_KEYS) - set(seed_keys))
        extra = sorted(set(seed_keys) - set(MODULE_KEYS))
        print("[失败] 示例数据与模块登记表不一致：")
        if missing:
            print(f"       缺少模块：{', '.join(missing)}")
        if extra:
            print(f"       多余模块：{', '.join(extra)}")
        return 1

    print("[1/4] 前置校验通过：示例数据覆盖 18 个业务模块")

    # 2. 删旧库、建空库，保证重跑不留下上次的中间产物
    target = db.reset_database()
    print(f"[2/4] 已重建数据库：{target}")

    # 3. 按登记表顺序灌库，逐模块打印条数，卡住时一眼能看到断在哪个模块
    total = 0
    with db.connect() as conn:
        for module in MODULES:
            rows = SEED_ROWS[module.key]
            if not rows:
                print(f"[失败] 模块「{module.label}」({module.key}) 没有可灌入的记录")
                return 1
            db.insert_rows(conn, module.key, rows)
            total += len(rows)
            print(f"       - {module.label:<6} {module.key:<12} {len(rows)} 条")
        conn.commit()
    print(f"[3/4] 示例数据灌入完成：共 {len(MODULES)} 个模块、{total} 条记录")

    # 4. 回查校验：重新开连接读回来，模块数、每模块条数必须与刚写入的一致
    loaded = db.load_all()
    if tuple(sorted(loaded)) != tuple(sorted(MODULE_KEYS)):
        print(f"[失败] 回查模块数不一致：期望 {len(MODULE_KEYS)}，实际 {len(loaded)}")
        return 1
    mismatched = [
        module.label
        for module in MODULES
        if len(loaded.get(module.key, [])) != len(SEED_ROWS[module.key])
    ]
    if mismatched:
        print(f"[失败] 以下模块回查条数不一致：{', '.join(mismatched)}")
        return 1

    print(
        f"[4/4] 回查校验通过：业务模块 {len(MODULES)} 个（与运营概览卡片一致），"
        f"记录 {total} 条"
    )
    print("[完成] 数据库初始化成功")
    return 0


if __name__ == "__main__":
    sys.exit(run())
