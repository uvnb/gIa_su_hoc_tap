"""Nhà cung cấp GIẢ LẬP – chạy không cần khóa API, không tốn tiền.

Dùng để:
- Phát triển app Flutter khi chưa có khóa API (đặt DEFAULT_PROVIDER=mock).
- Kiểm thử tự động (pytest): có thể thay hành vi từng vai trò qua `handlers`.

Mock đọc thông tin cần thiết từ chính prompt (ví dụ dòng "Đáp án (BÍ MẬT): ...").
Biến môi trường MOCK_TUTOR_LEAK=1 khiến Tutor CỐ TÌNH làm lộ đáp án – để chứng minh Guard chặn được.
"""
from __future__ import annotations

import json
import os
import re
from typing import Any, Callable, Optional

from ..pipeline import vn_numbers as vn
from .base import LLMProvider

Handler = Callable[[str, str, Optional[bytes]], dict]

DEMO_PROBLEM = "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?"


def _grab(pattern: str, text: str, default: str = "") -> str:
    m = re.search(pattern, text)
    return m.group(1).strip() if m else default


def _solve_text(text: str) -> dict:
    t = vn.norm(text)
    nums = [n for n in vn.extract_numbers(t) if "/" not in n]
    if re.search(r"\b(vì sao|tại sao|làm sao|vì đâu)\b", t):
        return {"mode": "discovery", "type": "kham_pha", "answer": "Vì hơi nước bốc lên cao, gặp lạnh thành mây rồi rơi xuống.",
                "variants": [], "steps": ["Đoán thử", "Nghĩ về nước và nhiệt độ"], "tool": "none"}
    if re.search(r"\b(viết|tả|kể lại|đặt câu)\b", t) and len(nums) < 2:
        return {"mode": "open_ended", "type": "tap_lam_van", "answer": "open_ended", "variants": [],
                "steps": ["Bạn định tả gì?", "Nó trông thế nào?", "Bạn thích nó vì sao?"], "tool": "none"}
    if len(nums) >= 2:
        a, b = float(nums[0]), float(nums[1])
        if re.search(r"(bớt|cho đi|ăn mất|còn lại|bay đi|trừ|-|cho bạn|bán)", t):
            op, val, typ = "-", a - b, "toan_loi_van_tru"
        elif re.search(r"(nhân|×|\bx\b|\*|mỗi .* có .* bao nhiêu)", t):
            op, val, typ = "×", a * b, "phep_nhan"
        elif re.search(r"(chia|:|÷)", t):
            op, val, typ = ":", a / b if b else 0, "phep_chia"
        else:
            op, val, typ = "+", a + b, "toan_loi_van_cong"
        ans = str(int(val)) if float(val).is_integer() else str(val)
        tool = "sticks" if max(a, b, val) <= 20 and op in "+-" else ("base10" if op in "+-" else "dots")
        return {"mode": "exercise", "type": typ, "answer": ans, "variants": [ans],
                "steps": [f"Tìm hai số: {nums[0]} và {nums[1]}", f"Làm phép tính {nums[0]} {op} {nums[1]}"],
                "tool": tool, "key": nums}
    return {"mode": "exercise", "type": "khac", "answer": "?", "variants": [], "steps": [], "tool": "none"}


def _problem_from(text: str, pid: int = 1) -> dict:
    s = _solve_text(text)
    ans = s["answer"]
    variants = list(dict.fromkeys(s["variants"] + ([f"{ans} cái"] if s["mode"] == "exercise" and ans != "?" else [])))
    return {
        "id": pid, "text": text.strip(), "type": s["type"], "mode": s["mode"], "answer": ans,
        "answer_variants": variants, "steps": s["steps"], "key_numbers": s.get("key", []),
        "common_mistakes": ["Nhầm phép cộng với phép trừ"], "suggested_tool": s["tool"],
    }


# ----------------------------- handler mặc định -----------------------------

def _solver(system: str, user: str, image: Optional[bytes]) -> dict:
    m = re.search(r"Đề bài dạng chữ:\s*(.*?)(?:\nẢnh trang vở|$)", user, re.S)
    q = m.group(1).strip() if m else ""
    if not q and image:
        q = DEMO_PROBLEM  # mock không đọc được ảnh → dùng bài mẫu
    if not q:
        return {"readable": False, "problems": []}
    parts = [p.strip() for p in re.split(r"\n+|(?=\bBài \d+[:.])", q) if p.strip()]
    probs = [_problem_from(p, i + 1) for i, p in enumerate(parts[:8])]
    probs = [p for p in probs if p["answer"] != "?"]
    for i, p in enumerate(probs):
        p["id"] = i + 1
    return {"readable": bool(probs), "problems": probs}


def _checker(system: str, user: str, image: Optional[bytes]) -> dict:
    child = _grab(r'Câu bạn nhỏ vừa nói[^"]*"(.*)"', user)
    answer = _grab(r"Đáp án đúng:\s*(.+?)\s*\(", user)
    mode = _grab(r"Kiểu bài:\s*(\S+)", user, "exercise")
    c = vn.norm(child)
    if re.search(r"(chết|giết|đánh nhau|tự tử)", c):
        return {"verdict": "unsafe", "detected_value": "", "mistake_hint": ""}
    if re.search(r"(đáp án|nói đi|cho con|đánh vần|answer|có phải|hay là|đóng vai|cho phép)", c):
        return {"verdict": "asks_for_answer", "detected_value": "", "mistake_hint": ""}
    if re.search(r"(không biết|khó quá|chịu|hông biết|ko biết)", c):
        return {"verdict": "dont_know", "detected_value": "", "mistake_hint": ""}
    nums = vn.extract_numbers(c)
    target = vn.numeric_value(answer)
    if mode == "exercise" and target and nums:
        if any(vn.same_number(n, target) for n in nums):
            return {"verdict": "correct_final", "detected_value": target, "mistake_hint": ""}
        return {"verdict": "incorrect", "detected_value": nums[-1], "mistake_hint": "Có thể nhầm phép tính"}
    if re.search(r"(cộng|thêm|trừ|bớt|nhân|chia)", c):
        return {"verdict": "correct_step", "detected_value": "", "mistake_hint": ""}
    if nums:
        return {"verdict": "correct_step", "detected_value": nums[-1], "mistake_hint": ""}
    return {"verdict": "off_topic", "detected_value": "", "mistake_hint": ""}


_TUTOR_LINES = {
    0: "Bạn kể lại cho Cú nghe nhé: đề bài nói gì nào?",
    1: "Lúc đầu có bao nhiêu? Rồi chuyện gì xảy ra tiếp theo?",
    2: "Được thêm vào thì nhiều lên hay ít đi nhỉ?",
    3: "Mình thử bài nhỏ hơn nhé: 2 thêm 1 là mấy?",
    4: "Mình cùng xếp que tính rồi đếm nhé! Bạn bắt đầu xếp đi?",
    5: "Mình làm từng bước nhỏ xíu nhé. Bước đầu tiên bạn làm gì?",
}


def _tutor(system: str, user: str, image: Optional[bytes]) -> dict:
    level = int(_grab(r"Bậc gợi ý hiện tại:\s*L(\d)", user, "0"))
    answer = _grab(r"Đáp án \(BÍ MẬT\):\s*(.+)", system)
    if os.getenv("MOCK_TUTOR_LEAK") == "1":
        return {"say": f"Đáp án là {answer} đó! Bạn nhớ nhé?", "mood": "asking", "next_hint_level": level, "ui_actions": []}
    if os.getenv("MOCK_TUTOR_LEAK") == "words":
        n = vn.numeric_value(answer) or "0"
        words = {"12": "mười hai", "2": "hai", "15": "mười lăm"}.get(n, n)
        return {"say": f"Gợi ý nè: kết quả là {words} đó. Bạn thử nói lại xem?", "mood": "asking",
                "next_hint_level": level, "ui_actions": []}
    actions: list[dict] = []
    if level >= 4:
        keys = json.loads(_grab(r"Số có trong đề \(được phép nhắc tới\):\s*(\[.*\])", system, "[]") or "[]")
        tool = _grab(r"Công cụ trực quan gợi ý:\s*(\w+)", system, "sticks")
        if len(keys) >= 2 and tool != "none":
            actions.append({"type": "show_manipulative", "tool": tool, "a": float(keys[0]), "b": float(keys[1]), "choices": []})
    return {"say": _TUTOR_LINES.get(level, _TUTOR_LINES[0]), "mood": "asking", "next_hint_level": level, "ui_actions": actions}


def _guard(system: str, user: str, image: Optional[bytes]) -> dict:
    answer = _grab(r"Đáp án BÍ MẬT:\s*(.+?)\s*\(", user)
    cand = _grab(r'Câu gia sư định nói:\s*"(.*)"', user)
    target = vn.numeric_value(answer)
    if target and any(vn.same_number(n, target) for n in vn.extract_numbers(cand)):
        return {"leak": True, "reason": "mock: có số đáp án"}
    if answer and not target and vn.norm(answer) in vn.norm(cand):
        return {"leak": True, "reason": "mock: có chữ đáp án"}
    return {"leak": False, "reason": "mock: an toàn"}


def _explain(system: str, user: str, image: Optional[bytes]) -> dict:
    return {"say": "Bạn giải thích rõ ràng quá! Bạn muốn làm câu tiếp hay thử thách khó hơn?", "mood": "celebrating",
            "explanation_quality": "good", "fun_question": "Bạn có biết vì sao con cú quay được đầu rất xa không?"}


def _challenge(system: str, user: str, image: Optional[bytes]) -> dict:
    src = _grab(r"Bài gốc:\s*(.+)", system)
    nums = vn.extract_numbers(src)
    text = src
    for n in dict.fromkeys(nums):
        if n.isdigit():
            text = re.sub(rf"(?<!\d){n}(?!\d)", str(int(n) + 3), text)
    text = text.replace("Lan", "Minh")
    p = _problem_from(text or DEMO_PROBLEM)
    return {"problem": p}


def _scratch(system: str, user: str, image: Optional[bytes]) -> dict:
    return {"say": "Bạn viết các số rất rõ ràng! Bước tiếp theo bạn định làm gì?", "mood": "encouraging",
            "child_wrote_final": False}


DEFAULT_HANDLERS: dict[str, Handler] = {
    "SOLVER": _solver, "CHECKER": _checker, "TUTOR": _tutor, "GUARD": _guard,
    "EXPLAIN": _explain, "CHALLENGE": _challenge, "SCRATCH": _scratch,
}


class MockProvider(LLMProvider):
    name = "mock"

    def __init__(self) -> None:
        self.handlers: dict[str, Handler] = dict(DEFAULT_HANDLERS)
        self.calls: list[dict[str, Any]] = []

    def complete(self, system, user_text, *, model, role="TUTOR", image_bytes=None,
                 image_media_type="image/jpeg", max_tokens=1024, temperature=None,
                 json_schema=None, effort=None) -> str:
        self.calls.append({"role": role, "system": system, "user": user_text})
        handler = self.handlers.get(role, _tutor)
        return json.dumps(handler(system, user_text, image_bytes), ensure_ascii=False)
