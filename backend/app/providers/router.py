"""Chọn nhà cung cấp + model cho từng vai trò. Đổi ChatGPT ↔ Claude bằng cấu hình, không cần sửa app."""
from __future__ import annotations

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


REGISTRY: dict[str, Callable[[], LLMProvider]] = {
    "anthropic": _anthropic,
    "openai": _openai,
    "mock": _mock,
}

_cache: dict[str, LLMProvider] = {}
_lock = threading.Lock()


def available() -> list[str]:
    return sorted(REGISTRY)


def instance(name: str) -> LLMProvider:
    if name not in REGISTRY:
        raise ProviderError(f"Nhà cung cấp AI không hỗ trợ: {name}")
    with _lock:
        if name not in _cache:
            _cache[name] = REGISTRY[name]()
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
