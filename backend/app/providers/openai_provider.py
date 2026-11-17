"""Adapter ChatGPT (OpenAI) – dùng SDK chính thức `openai`.

⚠️ VERIFY: tên model đặt trong .env (OPENAI_VISION_MODEL, OPENAI_CHAT_MODEL); kiểm tra danh sách
model hiện hành trên trang tài liệu OpenAI. Adapter dùng `max_completion_tokens` (model mới không
nhận `max_tokens`) và chỉ gửi temperature khi OPENAI_TEMPERATURE được đặt.
"""
from __future__ import annotations

import base64
import os
from typing import Any, Optional

from ..config import settings
from .base import LLMProvider, ProviderError, ProviderRefusal


class OpenAIProvider(LLMProvider):
    name = "openai"

    def __init__(self) -> None:
        try:
            import openai  # noqa: F401 – nhập muộn để app vẫn chạy khi không dùng OpenAI
            from openai import OpenAI
        except ImportError as e:  # pragma: no cover
            raise ProviderError("Chưa cài thư viện openai (pip install openai)") from e
        if not os.getenv("OPENAI_API_KEY"):
            raise ProviderError("Thiếu OPENAI_API_KEY trong .env")
        self._openai = openai
        self.client = OpenAI(timeout=30.0, max_retries=2)

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
        if not model:
            raise ProviderError("openai: chưa đặt tên model (OPENAI_VISION_MODEL / OPENAI_CHAT_MODEL)")
        user_content: list[dict[str, Any]] = [{"type": "text", "text": user_text}]
        if image_bytes:
            b64 = base64.b64encode(image_bytes).decode("ascii")
            user_content.append({"type": "image_url",
                                 "image_url": {"url": f"data:{image_media_type};base64,{b64}"}})
        kwargs: dict[str, Any] = dict(
            model=model,
            max_completion_tokens=max_tokens,
            messages=[{"role": "system", "content": system},
                      {"role": "user", "content": user_content}],
        )
        if json_schema:
            kwargs["response_format"] = {
                "type": "json_schema",
                "json_schema": {"name": f"{role.lower()}_output", "schema": json_schema, "strict": True},
            }
        if settings.openai_temperature:
            try:
                kwargs["temperature"] = float(settings.openai_temperature)
            except ValueError:
                pass
        o = self._openai
        try:
            resp = self.client.chat.completions.create(**kwargs)
        except o.AuthenticationError as e:
            raise ProviderError("openai: khóa API không hợp lệ") from e
        except o.NotFoundError as e:
            raise ProviderError(f"openai: model '{model}' không tồn tại") from e
        except o.BadRequestError as e:
            raise ProviderError(f"openai: yêu cầu không hợp lệ ({e})") from e
        except o.RateLimitError as e:
            raise ProviderError("openai: vượt hạn mức gọi API") from e
        except o.APIStatusError as e:
            raise ProviderError(f"openai: lỗi máy chủ {e.status_code}") from e
        except o.APIConnectionError as e:
            raise ProviderError("openai: không kết nối được") from e

        choice = resp.choices[0]
        if getattr(choice.message, "refusal", None):
            raise ProviderRefusal("openai: model từ chối")
        if choice.finish_reason == "length" and json_schema:
            raise ProviderError("openai: câu trả lời bị cắt ngang")
        return choice.message.content or ""
