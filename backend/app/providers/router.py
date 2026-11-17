"""Chọn nhà cung cấp + model cho từng vai trò. Đổi ChatGPT ↔ Claude bằng cấu hình, không cần sửa app."""
from __future__ import annotations

import os
import threading
from typing import Callable

from ..config import settings
from .base import LLMProvider, ProviderError

# Thêm nhà cung cấp mới (ví dụ Gemini): viết file adapter rồi đăng ký vào đây (NFR-12).
def _anthropic() -> LLMProvider:
    from .anthropic_provider import AnthropicProvider
    return AnthropicProvider()


def _openai() -> LLMProvider:
    from .openai_provider import OpenAIProvider
    return OpenAIProvider()


def _mock() -> LLMProvider:
    from .mock_provider import MockProvider
    return MockProvider()


def _compat(name: str) -> Callable[[], LLMProvider]:
    def make() -> LLMProvider:
        from .compat_provider import CompatProvider
        return CompatProvider(name)
    return make


REGISTRY: dict[str, Callable[[], LLMProvider]] = {
    "anthropic": _anthropic,
    "openai": _openai,
    "deepseek": _compat("deepseek"),
    "gemini": _compat("gemini"),
    "openrouter": _compat("openrouter"),
    "mock": _mock,
}
_KEY_ENV = {"deepseek": ("DEEPSEEK_API_KEY",), "gemini": ("GEMINI_API_KEY",), "openrouter": ("OPENROUTER_API_KEY",),
            "anthropic": ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN"), "openai": ("OPENAI_API_KEY",)}

_cache: dict[str, LLMProvider] = {}
_lock = threading.Lock()


def available() -> list[str]:
    return sorted(REGISTRY)


def configured(name: str | None) -> bool:
    """Nhà cung cấp đã có khóa API trên máy chủ chưa (phụ huynh chọn AI chưa có khóa → dùng mặc định)."""
    if not name or name not in REGISTRY:
        return False
    keys = _KEY_ENV.get(name)
    if keys:
        return any(os.getenv(k, "").strip() and not os.getenv(k, "").strip().endswith("...") for k in keys)
    return True


def instance(name: str) -> LLMProvider:
    if name not in REGISTRY:
        raise ProviderError(f"Nhà cung cấp AI không hỗ trợ: {name}")
    with _lock:
        if name not in _cache:
            try:
                _cache[name] = REGISTRY[name]()
            except ProviderError:
                raise
            except Exception as e:  # thiếu khóa, thiếu thư viện… → báo lỗi gọn, không làm sập máy chủ
                raise ProviderError(f"Không khởi tạo được nhà cung cấp {name}: {e}") from e
        return _cache[name]


def get(role: str, override: str | None = None, tier: str | None = None) -> tuple[LLMProvider, str]:
    """role: SOLVER | TUTOR | CHECKER | GUARD. Trả về (provider, model).

    override: nhà cung cấp phụ huynh chọn (FR-62); None = theo .env.
    tier: tiet_kiem | can_bang | thong_minh.
    """
    name = (override or settings.provider_for(role)).lower()
    provider = instance(name)
    model = settings.model_for(role, name, tier)
    return provider, model


def reset() -> None:
    """Dùng trong test."""
    with _lock:
        _cache.clear()
