"""Nhà cung cấp dùng giao thức kiểu OpenAI (chat completions): DeepSeek, Google Gemini, OpenRouter…

Mỗi nhà cung cấp chỉ khác địa chỉ, khóa và tên model – đặt trong .env:
  DEEPSEEK_API_KEY   (https://platform.deepseek.com – rất rẻ, KHÔNG đọc được ảnh → máy chủ tự OCR)
  GEMINI_API_KEY     (https://aistudio.google.com – có hạn mức MIỄN PHÍ, đọc được ảnh)
  OPENROUTER_API_KEY (https://openrouter.ai – có model ":free", đọc được ảnh tùy model)
Tên model đổi theo thời gian ⚠️ VERIFY: đặt DEEPSEEK_MODEL / GEMINI_MODEL / OPENROUTER_MODEL nếu cần.
"""
from __future__ import annotations

import base64
import json
import os
from dataclasses import dataclass
from typing import Any, Optional

from .base import LLMProvider, ProviderError, ProviderRefusal


@dataclass(frozen=True)
class Preset:
    base_url: str
    key_env: str
    model: str            # model cho Tutor / Checker / Guard (cần nhanh)
    vision: bool
    solver_model: str = ""  # model đọc đề + giải (cần chính xác); trống = dùng `model`
    solver_reasoning: str = ""  # reasoning_effort cho Solver (Gemini: "low")


PRESETS: dict[str, Preset] = {
    "deepseek": Preset("https://api.deepseek.com", "DEEPSEEK_API_KEY", "deepseek-chat", False),
    # Đo 11/2026 (gói miễn phí): 3.1-flash-lite ~1.5s/lượt, trả JSON gọn; 2.5-flash giải chính xác, đọc ảnh tốt.
    "gemini": Preset("https://generativelanguage.googleapis.com/v1beta/openai/", "GEMINI_API_KEY",
                     "gemini-3.1-flash-lite", True, solver_model="gemini-2.5-flash", solver_reasoning="low"),
    "openrouter": Preset("https://openrouter.ai/api/v1", "OPENROUTER_API_KEY", "google/gemma-4-31b-it:free", True),
}


def model_for(name: str, role: str = "TUTOR") -> str:
    """Thứ tự: {NAME}_{ROLE}_MODEL → {NAME}_MODEL → mặc định của preset theo vai trò."""
    p = PRESETS[name]
    env = os.getenv(f"{name.upper()}_{role.upper()}_MODEL", "").strip() or os.getenv(f"{name.upper()}_MODEL", "").strip()
    if env:
        return env
    return (p.solver_model or p.model) if role.upper() == "SOLVER" else p.model


class CompatProvider(LLMProvider):
    def __init__(self, name: str) -> None:
        from openai import OpenAI
        p = PRESETS[name]
        key = os.getenv(p.key_env, "").strip()
        if not key:
            raise ProviderError(f"Thiếu {p.key_env} trong .env")
        self.name = name
        self.preset = p
        self.supports_vision = os.getenv(f"{name.upper()}_VISION", "1" if p.vision else "0") == "1"
        base = os.getenv(f"{name.upper()}_BASE_URL", "").strip() or p.base_url
        # Gói miễn phí hay báo quá tải (503): thử lại 1 lần, chờ tối đa 25s – lỗi thì Cú dùng câu an toàn.
        self.client = OpenAI(api_key=key, base_url=base, timeout=25.0, max_retries=1)
        import openai
        self._openai = openai

    def complete(self, system, user_text, *, model, role="TUTOR", image_bytes: Optional[bytes] = None,
                 image_media_type="image/jpeg", max_tokens=1024, temperature=None,
                 json_schema: dict[str, Any] | None = None, effort=None) -> str:
        if json_schema:
            # Không phải nhà cung cấp nào cũng hỗ trợ json_schema chặt → mô tả khuôn trong system prompt.
            system = (system + "\n\nChỉ trả về MỘT đối tượng JSON hợp lệ, đúng khuôn JSON Schema sau, "
                      "không thêm chữ nào khác:\n" + json.dumps(json_schema, ensure_ascii=False))
        content: list[dict[str, Any]] = [{"type": "text", "text": user_text}]
        if image_bytes and self.supports_vision:
            b64 = base64.b64encode(image_bytes).decode("ascii")
            content.append({"type": "image_url", "image_url": {"url": f"data:{image_media_type};base64,{b64}"}})
        kwargs: dict[str, Any] = dict(
            model=model, max_tokens=max_tokens,
            messages=[{"role": "system", "content": system}, {"role": "user", "content": content}],
        )
        if json_schema:
            kwargs["response_format"] = {"type": "json_object"}
        if temperature is not None:
            kwargs["temperature"] = temperature
        if role in ("SOLVER", "CHALLENGE") and self.preset.solver_reasoning and model == self.preset.solver_model:
            # Model "có suy nghĩ": giới hạn mức suy nghĩ để không ăn hết token trước khi kịp trả lời.
            kwargs["reasoning_effort"] = self.preset.solver_reasoning
        o = self._openai
        try:
            resp = self.client.chat.completions.create(**kwargs)
        except o.AuthenticationError as e:
            raise ProviderError(f"{self.name}: khóa API không hợp lệ") from e
        except o.NotFoundError as e:
            raise ProviderError(f"{self.name}: model '{model}' không tồn tại") from e
        except o.BadRequestError as e:
            raise ProviderError(f"{self.name}: yêu cầu không hợp lệ ({e})") from e
        except o.RateLimitError as e:
            raise ProviderError(f"{self.name}: hết hạn mức (miễn phí) – thử lại sau") from e
        except o.APIStatusError as e:
            raise ProviderError(f"{self.name}: lỗi máy chủ {e.status_code}") from e
        except o.APIConnectionError as e:
            raise ProviderError(f"{self.name}: không kết nối được") from e
        if not resp.choices:
            raise ProviderError(f"{self.name}: không có câu trả lời")
        choice = resp.choices[0]
        if getattr(choice.message, "refusal", None):
            raise ProviderRefusal(f"{self.name}: model từ chối")
        return choice.message.content or ""
