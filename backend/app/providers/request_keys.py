"""Khóa API "mang theo" của phụ huynh (nhập trong Góc phụ huynh trên máy tính bảng).

App gửi kèm mỗi yêu cầu các header:
    x-ai-provider: openai | gemini | anthropic | deepseek
    x-ai-key:      khóa API của phụ huynh
    x-ai-model:    (tuỳ chọn) model đã kiểm tra được với khóa đó – dùng cho ChatGPT
Khóa chỉ sống trong yêu cầu hiện tại (ContextVar): KHÔNG lưu vào database, KHÔNG ghi log.
"""
from __future__ import annotations

import contextvars
import hashlib
from dataclasses import dataclass


@dataclass(frozen=True)
class RequestAI:
    provider: str
    key: str
    model: str = ""

    @property
    def fingerprint(self) -> str:
        """Dấu vết ngắn của khóa (để đặt tên bộ nhớ đệm) – không thể suy ngược ra khóa."""
        return hashlib.sha256(self.key.encode("utf-8")).hexdigest()[:16]


_current: contextvars.ContextVar[RequestAI | None] = contextvars.ContextVar("request_ai", default=None)

SUPPORTED = ("openai", "gemini", "anthropic", "deepseek")


def set_from_headers(provider: str | None, key: str | None, model: str | None) -> contextvars.Token:
    p = (provider or "").strip().lower()
    k = (key or "").strip()
    if p in SUPPORTED and 10 <= len(k) <= 400:
        return _current.set(RequestAI(p, k, (model or "").strip()[:80]))
    return _current.set(None)


def reset(token: contextvars.Token) -> None:
    _current.reset(token)


def current() -> RequestAI | None:
    return _current.get()


def key_for(name: str | None) -> RequestAI | None:
    r = _current.get()
    return r if r and name and r.provider == name.lower() else None
