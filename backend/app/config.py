"""运行配置：端口、跨域、运行环境、示例数据快照位置。"""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent.parent


@dataclass(frozen=True)
class Settings:
    app_name: str = "城市地下管网巡检养护平台"
    env: str = "local"
    port: int = 8000
    allowed_origins: list[str] = field(
        default_factory=lambda: [
            "http://127.0.0.1:5173",
            "http://localhost:5173",
        ]
    )
    page_size_default: int = 20
    page_size_max: int = 200
    # 示例数据快照（归档版）的位置：make setup 灌数据时写到这，启动时优先从这里回填。
    data_file: str = field(default_factory=lambda: os.environ.get("APP_DATA_FILE", "data/seed.json"))

    @property
    def data_path(self) -> Path:
        path = Path(self.data_file)
        return path if path.is_absolute() else BACKEND_ROOT / path


settings = Settings()
