"""Giao diện chung cho mọi nhà cung cấp AI (NFR-12: thêm nhà cung cấp = thêm 1 file adapter)."""
from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any, Optional


class ProviderError(RuntimeError):
    """Lỗi gọi AI (mạng, khóa API, hết hạn mức...). Pipeline sẽ trả câu an toàn thay vì crash."""


class ProviderRefusal(ProviderError):
    """Model từ chối trả lời (stop_reason = refusal)."""


class LLMProvider(ABC):
    name: str = "base"

    @abstractmethod
    def complete(
        self,
        system: str,
        user_text: str,
        *,
        model: str,
        role: str = "TUTOR",
        image_bytes: Optional[bytes] = None,
        image_media_type: str = "image/jpeg",
        max_tokens: int = 1024,
        temperature: float | None = None,
        json_schema: dict[str, Any] | None = None,
        effort: str | None = None,
    ) -> str:
        """Trả về văn bản model sinh ra (là JSON hợp lệ nếu có json_schema).

        - role: SOLVER | TUTOR | CHECKER | GUARD (adapter dùng để chọn tham số phù hợp).
        - temperature: gợi ý; adapter có thể bỏ qua nếu model không hỗ trợ.
        - effort: low | medium | high (độ "suy nghĩ" của model, nếu nhà cung cấp hỗ trợ).
        """
