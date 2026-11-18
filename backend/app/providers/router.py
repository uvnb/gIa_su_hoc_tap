"""Chọn nhà cung cấp + model cho từng vai trò. Đổi ChatGPT ↔ Claude bằng cấu hình, không cần sửa app."""
from __future__ import annotations

import os
import threading
from typing import Callable

from ..config import settings
from . import request_keys
from .base import LLMProvider, ProviderError

# Thêm nhà cung cấp mới (ví dụ Gemini): viết file adapter rồi đăng ký vào đây (NFR-12).
def _anthropic(api_key: str | None = None) -> LLMProvider:
    from .anthropic_provider import AnthropicProvider
    return AnthropicProvider(api_key)


def _openai(api_key: str | None = None) -> LLMProvider:
    from .openai_provider import OpenAIProvider
    return OpenAIProvider(api_key)


def _mock(api_key: str | None = None) -> LLMProvider:
    from .mock_provider import MockProvider
    return MockProvider()


def _compat(name: str) -> Callable[..., LLMProvider]:
    def make(api_key: str | None = None) -> LLMProvider:
        from .compat_provider import CompatProvider
        return CompatProvider(name, api_key)
    return make


REGISTRY: dict[str, Callable[..., LLMProvider]] = {
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
    if request_keys.key_for(name):  # phụ huynh gửi kèm khóa riêng
        return True
    keys = _KEY_ENV.get(name)
    if keys:
        return any(os.getenv(k, "").strip() and not os.getenv(k, "").strip().endswith("...") for k in keys)
    return True


_byok: dict[str, LLMProvider] = {}  # bộ nhớ đệm theo dấu vết khóa (không lưu khóa ra ngoài RAM)


def instance(name: str) -> LLMProvider:
    if name not in REGISTRY:
        raise ProviderError(f"Nhà cung cấp AI không hỗ trợ: {name}")
    own = request_keys.key_for(name)
    if own:
        cache_key = f"{name}:{own.fingerprint}"
        with _lock:
            if cache_key not in _byok:
                if len(_byok) >= 16:
                    _byok.pop(next(iter(_byok)))
                try:
                    _byok[cache_key] = REGISTRY[name](own.key)
                except ProviderError:
                    raise
                except Exception as e:
                    raise ProviderError(f"Không khởi tạo được {name} với khóa của phụ huynh: {type(e).__name__}") from e
            return _byok[cache_key]
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
    if override and not configured(name):
        # phiên học chọn AI của phụ huynh nhưng lượt này không kèm khóa → dùng AI mặc định của máy chủ
        name = settings.provider_for(role).lower()
    provider = instance(name)
    own = request_keys.key_for(name)
    model = own.model if own and own.model else settings.model_for(role, name, tier)
    if not model and name == "openai":
        model = DEFAULT_OPENAI_MODEL
    return provider, model


# Model ChatGPT mặc định khi khóa của phụ huynh chưa báo model (app gửi model đã kiểm tra trong x-ai-model).
DEFAULT_OPENAI_MODEL = "gpt-4o-mini"
OPENAI_PREFERENCE = ("gpt-5-mini", "gpt-4.1-mini", "gpt-4o-mini", "gpt-5", "gpt-4.1", "gpt-4o")


def reset() -> None:
    """Dùng trong test."""
    with _lock:
        _cache.clear()
        _byok.clear()
