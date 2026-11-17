"""Adapter Claude (Anthropic) – dùng SDK chính thức `anthropic`.

Ghi chú API hiện hành (11/2026):
- Không gửi temperature/top_p/top_k: Claude Sonnet 5.5 / Haiku 5.5 (và API version 2026-10-21)
  trả lỗi 400 nếu có.
- Độ sâu suy nghĩ điều khiển bằng output_config.effort (low | medium | high | xhigh | max).
- JSON chắc chắn hợp lệ nhờ structured outputs: output_config.format = json_schema.
- Kiểm tra stop_reason == "refusal" trước khi đọc nội dung.
- Với Sonnet 5.5 / Opus 5.5 bật server-side fallback (`fallbacks: "default"`) – Haiku 5.5 không hỗ trợ.
"""
from __future__ import annotations

import base64
import os
from typing import Any, Optional

import anthropic

from ..config import settings
from .base import LLMProvider, ProviderError, ProviderRefusal

# Model chấp nhận tham số fallbacks phía server (Haiku 5.5 thì không – sẽ trả 400 nếu gửi danh sách).
_FALLBACK_MODELS = ("claude-sonnet-5-5", "claude-opus-5-5", "claude-opus-5", "claude-fable-5-2", "claude-fable-5-1")
_FALLBACK_BETA = "server-side-fallback-2026-07-01"
_CACHE_MIN_CHARS = 1500  # system prompt đủ dài mới đánh dấu cache (tối thiểu ~512 token)


class AnthropicProvider(LLMProvider):
    name = "anthropic"

    def __init__(self) -> None:
        if not os.getenv("ANTHROPIC_API_KEY") and not os.getenv("ANTHROPIC_AUTH_TOKEN"):
            # SDK cũng đọc được hồ sơ `ant auth login`, nên chỉ cảnh báo nhẹ.
            pass
        self.client = anthropic.Anthropic(timeout=30.0, max_retries=2)

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
        temperature: float | None = None,  # cố ý bỏ qua – xem docstring module
        json_schema: dict[str, Any] | None = None,
        effort: str | None = None,
    ) -> str:
        content: list[dict[str, Any]] = []
        if image_bytes:
            content.append({
                "type": "image",
                "source": {"type": "base64", "media_type": image_media_type,
                           "data": base64.standard_b64encode(image_bytes).decode("ascii")},
            })
        content.append({"type": "text", "text": user_text})

        system_block: list[dict[str, Any]] = [{"type": "text", "text": system}]
        if len(system) >= _CACHE_MIN_CHARS:
            # Phần system (luật + đề bài bí mật) giữ nguyên suốt phiên → đọc lại từ cache, rẻ & nhanh hơn.
            system_block[0]["cache_control"] = {"type": "ephemeral"}

        output_config: dict[str, Any] = {}
        if effort:
            output_config["effort"] = effort
        if json_schema:
            output_config["format"] = {"type": "json_schema", "schema": json_schema}

        kwargs: dict[str, Any] = dict(
            model=model,
            max_tokens=max_tokens,
            system=system_block,
            messages=[{"role": "user", "content": content}],
        )
        if output_config:
            kwargs["output_config"] = output_config

        try:
            if settings.anthropic_server_fallback and model in _FALLBACK_MODELS:
                msg = self.client.beta.messages.create(
                    betas=[_FALLBACK_BETA], fallbacks="default", **kwargs)
            else:
                msg = self.client.messages.create(**kwargs)
        except anthropic.AuthenticationError as e:
            raise ProviderError(f"anthropic: khóa API không hợp lệ ({e.message})") from e
        except anthropic.NotFoundError as e:
            raise ProviderError(f"anthropic: model '{model}' không tồn tại ({e.message})") from e
        except anthropic.BadRequestError as e:
            raise ProviderError(f"anthropic: yêu cầu không hợp lệ ({e.message})") from e
        except anthropic.RateLimitError as e:
            raise ProviderError("anthropic: vượt hạn mức gọi API, thử lại sau") from e
        except anthropic.APIStatusError as e:
            raise ProviderError(f"anthropic: lỗi máy chủ {e.status_code}") from e
        except anthropic.APIConnectionError as e:
            raise ProviderError("anthropic: không kết nối được") from e

        if msg.stop_reason == "refusal":
            category = getattr(getattr(msg, "stop_details", None), "category", None)
            raise ProviderRefusal(f"anthropic: model từ chối (category={category})")
        text = "".join(b.text for b in msg.content if b.type == "text")
        if msg.stop_reason == "max_tokens" and json_schema:
            raise ProviderError("anthropic: câu trả lời bị cắt ngang (max_tokens)")
        return text
