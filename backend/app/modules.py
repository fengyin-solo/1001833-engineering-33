"""业务模块登记表：初始化灌库、运营概览、健康检查统一从这里取模块清单。

顺序与名称按归档版运营概览固化，初始化出来的业务模块数必须与概览卡片对齐，
任何模块增删都只改这一处。
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Module:
    key: str
    label: str


# 归档版运营概览顺序（与前端导航、README 业务模块表一致）
MODULES: tuple[Module, ...] = (
    Module("pipe", "管段档案"),
    Module("manhole", "检查井"),
    Module("valve", "阀门井室"),
    Module("pumpstation", "泵站设施"),
    Module("patrol", "巡查任务"),
    Module("defect", "缺陷登记"),
    Module("cctv", "内窥检测"),
    Module("repair", "修复施工"),
    Module("pressure", "压力监测"),
    Module("flow", "流量监测"),
    Module("leak", "泄漏排查"),
    Module("dredge", "清淤疏浚"),
    Module("material", "养护材料"),
    Module("equip", "养护机械"),
    Module("traffic", "占道许可"),
    Module("complaint", "公众诉求"),
    Module("fund", "养护资金"),
    Module("archive", "管网档案"),
)

MODULE_KEYS: tuple[str, ...] = tuple(item.key for item in MODULES)
MODULE_LABELS: dict[str, str] = {item.key: item.label for item in MODULES}


def label_of(key: str) -> str:
    """模块中文名称；未知模块回退为键本身，避免概览出现空白。"""
    return MODULE_LABELS.get(key, key)
