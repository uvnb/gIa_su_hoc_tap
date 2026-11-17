"""② CHECKER – chấm câu trả lời của bạn nhỏ.

Đường nhanh (không gọi AI) cho đáp án dạng số: bạn nhỏ nói đúng MỘT số và số đó bằng đáp án → correct_final.
Còn lại hỏi AI (model nhỏ, rẻ).
"""
from __future__ import annotations

import logging
import re

from ..config import settings
from ..providers import router
from ..providers.base import ProviderError
from . import schemas, vn_numbers as vn
from .jsonutil import parse_json, render

log = logging.getLogger("cutomo.checker")

_DONT_KNOW = re.compile(r"^(con |em |tớ |mình )?(không biết|ko biết|hông biết|chịu|chịu thôi|khó quá|không hiểu)[\s.!?]*$")


def fast_check(problem: dict, child_input: str) -> dict | None:
    c = vn.norm(child_input)
    if not c:
        return {"verdict": "dont_know", "detected_value": "", "mistake_hint": ""}
    if _DONT_KNOW.match(c):
        return {"verdict": "dont_know", "detected_value": "", "mistake_hint": ""}
    if problem.get("mode") != "exercise":
        return None
    target = vn.numeric_value(str(problem.get("answer", "")))
    if target is None:
        return None
    nums = vn.extract_numbers(c)
    # Câu hỏi dò ("có phải 12 không", "11 hay 13") → để AI phân loại
    if re.search(r"(có phải|phải không|hay là|\bhay\b|đúng không|\?)", c):
        return None
    if len(nums) == 1 and vn.same_number(nums[0], target):
        return {"verdict": "correct_final", "detected_value": nums[0], "mistake_hint": ""}
    return None


def check(problem: dict, child_input: str, last_owl: str, prompts: dict[str, str],
          provider_name: str | None, tier: str | None) -> dict:
    fast = fast_check(problem, child_input)
    if fast:
        return fast
    user = render(prompts["checker"], problem_text=problem["text"], mode=problem.get("mode", "exercise"),
                  steps=problem.get("steps", []), answer=problem["answer"],
                  answer_variants=problem.get("answer_variants", []), last_owl=last_owl.replace('"', "'"),
                  child_input=child_input.replace('"', "'"))
    try:
        provider, model = router.get("CHECKER", provider_name, tier)
        out = parse_json(provider.complete("Bạn chỉ trả lời bằng JSON.", user, model=model, role="CHECKER",
                                           max_tokens=600, temperature=0, json_schema=schemas.CHECKER,
                                           effort=settings.effort_for("CHECKER")))
    except (ProviderError, ValueError) as e:
        log.warning("checker lỗi: %s", e)
        return {"verdict": "error", "detected_value": "", "mistake_hint": ""}
    verdict = out.get("verdict")
    if verdict not in schemas.VERDICTS:
        verdict = "incorrect"
    if verdict == "correct_final" and problem.get("mode") == "open_ended":
        verdict = "correct_step"
    # Chặn chấm nhầm "correct_final" khi bạn nhỏ KHÔNG nói ra số đáp án (đáp án dạng số).
    target = vn.numeric_value(str(problem.get("answer", "")))
    if verdict == "correct_final" and target is not None and problem.get("mode") == "exercise":
        if not any(vn.same_number(n, target) for n in vn.extract_numbers(child_input)):
            verdict = "correct_step"
    return {"verdict": verdict, "detected_value": str(out.get("detected_value", ""))[:80],
            "mistake_hint": str(out.get("mistake_hint", ""))[:200]}
