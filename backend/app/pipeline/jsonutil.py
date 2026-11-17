"""Tiện ích: parse JSON từ model và điền biến vào prompt mà không vỡ dấu ngoặc nhọn của JSON mẫu."""
from __future__ import annotations

import json
import re
from typing import Any

_VAR = re.compile(r"\{([a-z_][a-z0-9_]*)\}")


def render(template: str, **values: Any) -> str:
    """Thay {ten_bien} bằng giá trị; giữ nguyên mọi dấu { } khác (ví dụ JSON mẫu trong prompt).

    Khác str.format(): không lỗi khi prompt có JSON như {"leak": true}.
    """
    def sub(m: re.Match) -> str:
        key = m.group(1)
        if key not in values:
            return m.group(0)
        v = values[key]
        if isinstance(v, (list, dict)):
            return json.dumps(v, ensure_ascii=False)
        return str(v)
    return _VAR.sub(sub, template)


def parse_json(text: str) -> dict[str, Any]:
    """Parse JSON kể cả khi model bọc trong ```json ... ``` hoặc có chữ thừa xung quanh."""
    t = (text or "").strip()
    t = re.sub(r"^```(?:json)?\s*", "", t)
    t = re.sub(r"\s*```$", "", t)
    try:
        v = json.loads(t)
        if isinstance(v, dict):
            return v
    except json.JSONDecodeError:
        pass
    start, end = t.find("{"), t.rfind("}")
    if start != -1 and end > start:
        v = json.loads(t[start:end + 1])
        if isinstance(v, dict):
            return v
    raise ValueError("Không đọc được JSON từ model")
