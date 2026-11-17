"""Answer Guard – lớp bảo vệ "chống lộ đáp án" (mục 11).

candidate ──► (A) kiểm tra quy tắc (nhanh, miễn phí)
          ──► (B) AI giám khảo nếu (A) không phát hiện
Không chắc chắn → coi như LỘ (an toàn trước).
"""
from __future__ import annotations

import logging
import re

from ..config import settings
from ..providers import router
from ..providers.base import ProviderError
from . import schemas, vn_numbers as vn
from .jsonutil import parse_json, render

log = logging.getLogger("cutomo.guard")

# Mẫu "đánh vần" số: 1 rồi 2, 1-2, 1, 2
_SPELL_SEP = re.compile(r"^\s*(?:,|-|–|\.|rồi|và|tiếp theo là|sau đó là|tiếp đến)?\s*$")


def rule_variants(problem: dict) -> tuple[list[str], list[str]]:
    """Trả về (các số đáp án cần chặn, các chuỗi chữ đáp án cần chặn).

    Bỏ qua những giá trị có sẵn trong đề (key_numbers / text) để tránh báo động giả –
    khi đó chỉ dựa vào AI giám khảo (ghi chú mục 13.6).
    """
    if problem.get("mode") in ("open_ended", "discovery"):
        return [], []
    text_norm = vn.norm(problem.get("text", ""))
    in_problem = set(vn.extract_numbers(problem.get("text", "")))
    in_problem |= {n for k in problem.get("key_numbers", []) for n in vn.extract_numbers(str(k))}

    nums: list[str] = []
    words: list[str] = []
    for v in [problem.get("answer", "")] + list(problem.get("answer_variants", [])):
        v = str(v)
        if not v or v == "open_ended":
            continue
        n = vn.numeric_value(v)
        if n is not None:
            if not any(vn.same_number(n, k) for k in in_problem) and n not in nums:
                nums.append(n)
            continue
        w = vn.norm(v)
        # Chuỗi chữ quá ngắn (1 ký tự) hoặc có sẵn trong đề → để AI giám khảo xử lý.
        if len(w) >= 2 and w not in text_norm and w not in words:
            words.append(w)
    return nums, words


def rule_leak(candidate: str, nums: list[str], words: list[str]) -> bool:
    c = vn.norm(candidate)
    if words:
        for w in words:
            if re.search(rf"(?<!\w){re.escape(w)}(?!\w)", c):
                return True
    if not nums:
        return False
    converted = vn.words_to_digits(c)
    found = vn.extract_numbers(converted, convert_words=False)
    for n in found:
        if any(vn.same_number(n, t) for t in nums):
            return True
    # "đánh vần" từng chữ số: "số đó là 1 rồi 2" → 12
    matches = list(re.finditer(r"(?<![\d/])(?<!\d[.,])\d(?![\d/])(?![.,]\d)", converted))
    for t in nums:
        if not t.isdigit() or len(t) < 2:
            continue
        for i in range(len(matches) - len(t) + 1):
            seq = matches[i:i + len(t)]
            if "".join(m.group(0) for m in seq) != t:
                continue
            gaps_ok = all(_SPELL_SEP.match(converted[a.end():b.start()]) for a, b in zip(seq, seq[1:]))
            if gaps_ok:
                return True
    return False


def needs_llm_check(candidate: str, problem: dict) -> bool:
    """GUARD_MODE=smart: với đáp án là số, câu không chứa số nào thì khó lộ → bỏ qua AI giám khảo (tiết kiệm)."""
    if settings.guard_mode == "always":
        return True
    if problem.get("mode") == "discovery":
        return False
    if problem.get("mode") == "open_ended":
        return True
    if vn.numeric_value(str(problem.get("answer", ""))) is None:
        return True  # đáp án dạng chữ → luôn hỏi AI giám khảo
    c = vn.words_to_digits(candidate)
    if vn.extract_numbers(c, convert_words=False):
        return True
    # có các từ gợi ý nguy hiểm dù không có số
    return bool(re.search(r"(đáp án|kết quả|bằng|chính là|đúng là|answer)", vn.norm(candidate)))


def llm_leak(candidate: str, problem: dict, prompts: dict[str, str], provider_name: str | None,
             tier: str | None) -> bool:
    if problem.get("mode") == "open_ended":
        tpl = prompts["guard_writing"]
    else:
        tpl = prompts["guard"]
    user = render(tpl, problem_text=problem.get("text", ""), answer=problem.get("answer", ""),
                  answer_variants=problem.get("answer_variants", []), candidate=candidate.replace('"', "'"))
    try:
        provider, model = router.get("GUARD", provider_name, tier)
        out = provider.complete("Bạn chỉ trả lời bằng JSON.", user, model=model, role="GUARD",
                                max_tokens=400, temperature=0, json_schema=schemas.GUARD,
                                effort=settings.effort_for("GUARD"))
        return bool(parse_json(out).get("leak", True))
    except (ProviderError, ValueError) as e:
        log.warning("guard: không chắc chắn (%s) → coi như lộ", e)
        return True


def is_leak(candidate: str, problem: dict, prompts: dict[str, str], provider_name: str | None = None,
            tier: str | None = None) -> bool:
    nums, words = rule_variants(problem)
    if rule_leak(candidate, nums, words):
        return True
    if needs_llm_check(candidate, problem):
        return llm_leak(candidate, problem, prompts, provider_name, tier)
    return False
