"""JSON Schema cho từng vai trò (structured outputs) – model buộc phải trả đúng khuôn.

Lưu ý: chỉ dùng tính năng schema phổ biến (object/array/string/integer/number/boolean/enum,
required đầy đủ, additionalProperties=false) để chạy được cả Claude lẫn OpenAI strict mode.
"""
from __future__ import annotations

TOOLS = ["sticks", "dots", "base10", "clock", "ruler", "fraction", "none"]
MOODS = ["asking", "encouraging", "thinking", "celebrating"]
VERDICTS = ["correct_final", "correct_step", "partially_correct", "incorrect", "off_topic",
            "asks_for_answer", "dont_know", "unsafe"]
MODES = ["exercise", "open_ended", "discovery"]


def _obj(props: dict, required: list[str] | None = None) -> dict:
    return {"type": "object", "properties": props,
            "required": required if required is not None else list(props.keys()),
            "additionalProperties": False}


_STR = {"type": "string"}
_STR_LIST = {"type": "array", "items": {"type": "string"}}

PROBLEM = _obj({
    "id": {"type": "integer"},
    "text": _STR,
    "type": _STR,
    "mode": {"type": "string", "enum": MODES},
    "answer": _STR,
    "answer_variants": _STR_LIST,
    "steps": _STR_LIST,
    "key_numbers": _STR_LIST,
    "common_mistakes": _STR_LIST,
    "suggested_tool": {"type": "string", "enum": TOOLS},
})

SOLVER = _obj({
    "readable": {"type": "boolean"},
    "problems": {"type": "array", "items": PROBLEM},
})

CHALLENGE = _obj({"problem": PROBLEM})

UI_ACTION = _obj({
    "type": {"type": "string", "enum": ["show_manipulative", "open_number_pad", "open_scratch_pad",
                                         "suggest_break", "offer_choices"]},
    "tool": {"type": "string", "enum": TOOLS},
    "a": {"type": "number"},
    "b": {"type": "number"},
    "choices": _STR_LIST,
})

TUTOR = _obj({
    "say": _STR,
    "mood": {"type": "string", "enum": MOODS},
    "next_hint_level": {"type": "integer"},
    "ui_actions": {"type": "array", "items": UI_ACTION},
})

CHECKER = _obj({
    "verdict": {"type": "string", "enum": VERDICTS},
    "detected_value": _STR,
    "mistake_hint": _STR,
})

GUARD = _obj({
    "leak": {"type": "boolean"},
    "reason": _STR,
})

EXPLAIN = _obj({
    "say": _STR,
    "mood": {"type": "string", "enum": MOODS},
    "explanation_quality": {"type": "string", "enum": ["good", "partial", "none"]},
    "fun_question": _STR,
})

SCRATCH = _obj({
    "say": _STR,
    "mood": {"type": "string", "enum": MOODS},
    "child_wrote_final": {"type": "boolean"},
})
