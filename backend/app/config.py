"""Cấu hình đọc từ biến môi trường (.env). Không bao giờ gửi các giá trị này xuống app."""
from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

ROLES = ("SOLVER", "TUTOR", "CHECKER", "GUARD")
TIERS = ("tiet_kiem", "can_bang", "thong_minh")

# Model Claude mặc định theo vai trò × mức (FR-62). Mức "can_bang" khớp .env.example của spec.
ANTHROPIC_TIER_MODELS: dict[str, dict[str, str]] = {
    "SOLVER": {"tiet_kiem": "claude-haiku-5-5", "can_bang": "claude-sonnet-5-5", "thong_minh": "claude-opus-5-5"},
    "TUTOR": {"tiet_kiem": "claude-haiku-5-5", "can_bang": "claude-haiku-5-5", "thong_minh": "claude-sonnet-5-5"},
    "CHECKER": {"tiet_kiem": "claude-haiku-5-5", "can_bang": "claude-haiku-5-5", "thong_minh": "claude-haiku-5-5"},
    "GUARD": {"tiet_kiem": "claude-haiku-5-5", "can_bang": "claude-haiku-5-5", "thong_minh": "claude-haiku-5-5"},
}

# Mức "effort" cho Claude: Solver cần giải đúng, các vai trò còn lại cần nhanh (NFR-02 < 4 giây).
DEFAULT_EFFORT = {"SOLVER": "medium", "TUTOR": "low", "CHECKER": "low", "GUARD": "low"}


def _env(name: str, default: str = "") -> str:
    v = os.getenv(name)
    return v.strip() if v and v.strip() else default


def _int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except ValueError:
        return default


@dataclass
class Settings:
    # Có thể ghi nhiều chuỗi cách nhau bởi dấu phẩy (vd khi đổi secret: chấp nhận cả cũ lẫn mới một thời gian).
    app_shared_secret: str = field(default_factory=lambda: _env("APP_SHARED_SECRET", "change-me"))
    # Nơi lưu dữ liệu: sqlite (máy tính ở nhà – mặc định) | firestore (Google Cloud Run)
    store_backend: str = field(default_factory=lambda: _env("STORE_BACKEND", "sqlite").lower())
    firestore_database: str = field(default_factory=lambda: _env("FIRESTORE_DATABASE", "(default)"))
    db_path: str = field(default_factory=lambda: _env("DB_PATH", str(Path(__file__).resolve().parent.parent / "data" / "cutomo.sqlite3")))
    image_retention_hours: int = field(default_factory=lambda: _int("IMAGE_RETENTION_HOURS", 24))
    session_retention_days: int = field(default_factory=lambda: _int("SESSION_RETENTION_DAYS", 30))
    max_turns_per_problem: int = field(default_factory=lambda: _int("MAX_TURNS_PER_PROBLEM", 12))
    max_sessions_per_day: int = field(default_factory=lambda: _int("MAX_SESSIONS_PER_DEVICE_PER_DAY", 80))
    guard_mode: str = field(default_factory=lambda: _env("GUARD_MODE", "smart"))  # smart | always
    # OCR ảnh → chữ trên máy chủ: auto = chỉ khi AI không đọc được ảnh · always · off
    ocr_mode: str = field(default_factory=lambda: _env("OCR_MODE", "auto"))
    default_tier: str = field(default_factory=lambda: _env("DEFAULT_TIER", "can_bang"))
    anthropic_server_fallback: bool = field(default_factory=lambda: _env("ANTHROPIC_SERVER_FALLBACK", "1") == "1")
    openai_temperature: str = field(default_factory=lambda: _env("OPENAI_TEMPERATURE", ""))
    # Cho phép bản web (chạy thử trên trình duyệt máy tính) gọi API. Mặc định chỉ localhost.
    # Đặt CORS_ORIGIN_REGEX=off để tắt hẳn.
    cors_origin_regex: str = field(default_factory=lambda: _env(
        "CORS_ORIGIN_REGEX", r"https?://(localhost|127\.0\.0\.1)(:\d+)?"))
    # Thư mục bản web của app (flutter build web). Có thì backend phục vụ luôn giao diện ở "/".
    web_dir: str = field(default_factory=lambda: _env(
        "WEB_DIR", str(Path(__file__).resolve().parents[2] / "app" / "build" / "web")))

    def provider_for(self, role: str) -> str:
        return _env(f"{role}_PROVIDER", _env("DEFAULT_PROVIDER", "anthropic")).lower()

    def model_for(self, role: str, provider: str, tier: str | None) -> str:
        tier = tier if tier in TIERS else self.default_tier
        if provider == "anthropic":
            # Biến .env (SOLVER_MODEL...) là model cho mức "cân bằng" và chỉ áp dụng khi
            # vai trò đó đang chạy bằng Anthropic, để không lẫn tên model của nhà cung cấp khác.
            env_model = _env(f"{role}_MODEL") if self.provider_for(role) == "anthropic" else ""
            if tier == "can_bang" and env_model:
                return env_model
            return ANTHROPIC_TIER_MODELS[role][tier]
        if provider == "openai":
            if role == "SOLVER":
                smart = _env("OPENAI_SMART_VISION_MODEL")
                if tier == "thong_minh" and smart:
                    return smart
                return _env("OPENAI_VISION_MODEL", _env("SOLVER_MODEL") if self.provider_for(role) == "openai" else "")
            smart = _env("OPENAI_SMART_CHAT_MODEL")
            if tier == "thong_minh" and smart and role == "TUTOR":
                return smart
            return _env("OPENAI_CHAT_MODEL", _env(f"{role}_MODEL") if self.provider_for(role) == "openai" else "")
        if provider == "mock":
            return "mock"
        if provider in ("deepseek", "gemini", "openrouter"):
            from .providers.compat_provider import model_for
            return model_for(provider, role)
        return _env(f"{role}_MODEL")

    def effort_for(self, role: str) -> str:
        return _env(f"{role}_EFFORT", DEFAULT_EFFORT.get(role, "low"))


settings = Settings()
