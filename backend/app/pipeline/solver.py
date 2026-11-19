"""① SOLVER – đọc đề (ảnh hoặc chữ) và giải. Kết quả BÍ MẬT, chỉ lưu trên server."""
from __future__ import annotations

import hashlib
import logging
from typing import Any

from .. import store
from ..config import settings
from ..providers import router
from ..providers.base import ProviderError
from . import ocr, schemas, vn_numbers as vn
from .jsonutil import parse_json, render

log = logging.getLogger("cutomo.solver")

SUBJECT_NAMES = {
    "math": "Toán",
    "vietnamese": "Tiếng Việt",
    "english": "Tiếng Anh",
    "science": "Tự nhiên và Xã hội / Khoa học",
    "vietnam": "Lịch sử, Địa lý và Văn hóa Việt Nam",
}
VALID_TOOLS = set(schemas.TOOLS)


def normalize_problem(p: dict[str, Any], pid: int) -> dict[str, Any] | None:
    """Kiểm tra & chuẩn hóa một bài do model trả về. Trả None nếu bài vô dụng."""
    text = str(p.get("text", "")).strip()
    if not text:
        return None
    mode = p.get("mode") if p.get("mode") in schemas.MODES else "exercise"
    answer = str(p.get("answer", "")).strip()
    if mode == "open_ended":
        answer = "open_ended"
    if not answer:
        return None
    variants = [str(v).strip() for v in (p.get("answer_variants") or []) if str(v).strip()]
    if mode == "exercise":
        if answer not in variants:
            variants.insert(0, answer)
        n = vn.numeric_value(answer)
        if n is not None and n not in variants:
            variants.append(n)
    keys: list[str] = []
    for k in p.get("key_numbers") or []:
        for n in vn.extract_numbers(str(k)):
            if n not in keys:
                keys.append(n)
    for n in vn.extract_numbers(text):  # bảo đảm mọi số trong đề đều có mặt
        if n not in keys:
            keys.append(n)
    tool = p.get("suggested_tool") if p.get("suggested_tool") in VALID_TOOLS else "none"
    return {
        "id": pid,
        "text": text,
        "type": str(p.get("type", "khac")).strip() or "khac",
        "mode": mode,
        "answer": answer,
        "answer_variants": variants,
        "steps": [str(s) for s in (p.get("steps") or [])][:8],
        "key_numbers": keys,
        "common_mistakes": [str(s) for s in (p.get("common_mistakes") or [])][:5],
        "suggested_tool": tool,
    }


def _cache_key(image: bytes | None, question_text: str, grade: int, subject: str, provider: str, tier: str) -> str:
    h = hashlib.sha256()
    h.update(image or b"")
    h.update(f"|{question_text.strip()}|{grade}|{subject}|{provider}|{tier}".encode("utf-8"))
    return h.hexdigest()


def solve(image: bytes | None, question_text: str, grade: int, subject: str, prompts: dict[str, str],
          provider_name: str | None = None, tier: str | None = None) -> dict[str, Any]:
    """Trả {"readable": bool, "problems": [...]} – CHỈ dùng nội bộ server."""
    provider, model = router.get("SOLVER", provider_name, tier)
    # Khóa cache gồm cả nhà cung cấp + model THỰC SỰ dùng: đổi AI thì không dùng lại lời giải cũ.
    key = _cache_key(image, question_text, grade, subject, f"{provider.name}:{model}", tier or "")
    cached = store.solver_cache_get(key, settings.image_retention_hours)
    if cached is not None:
        return cached

    system = render(prompts["solver"], grade=grade, subject_name=SUBJECT_NAMES.get(subject, subject))

    # AI không tự đọc được ảnh (giả lập, DeepSeek…) → OCR tiếng Việt trên máy chủ rồi gửi chữ.
    ocr_note = ""
    if image and settings.ocr_mode != "off" and (settings.ocr_mode == "always" or not provider.supports_vision):
        if ocr.available():
            text = ocr.image_to_text(image)
            if not text.strip() and not question_text.strip():
                return {"readable": False, "problems": []}
            question_text = (question_text.strip() + "\n" + text).strip()
            ocr_note = ("\n(Đề được đọc từ ảnh bằng OCR nên có thể sai dấu/sai chữ: hãy sửa lỗi OCR khi chắc chắn, "
                        "và chép lại đề đã sửa vào trường text.)")
            if not provider.supports_vision:
                image = None
        else:
            log.warning("Chưa cài OCR (pip install easyocr) – AI hiện tại không đọc được ảnh")

    user = f"Lớp {grade}, môn {SUBJECT_NAMES.get(subject, subject)}."
    if question_text.strip():
        user += f"\nĐề bài dạng chữ: {question_text.strip()}" + ocr_note
    if image:
        user += "\nẢnh trang vở/sách của bạn nhỏ ở trên. Hãy đọc và giải."
    raw = provider.complete(system, user, model=model, role="SOLVER", image_bytes=image,
                            max_tokens=8000, temperature=0, json_schema=schemas.SOLVER,
                            effort=settings.effort_for("SOLVER"))
    data = parse_json(raw)
    problems = []
    for i, p in enumerate(data.get("problems") or []):
        np_ = normalize_problem(p, i + 1)
        if np_:
            problems.append(np_)
    result = {"readable": bool(data.get("readable")) and bool(problems), "problems": problems[:8]}
    if result["readable"]:
        store.solver_cache_put(key, result)
    return result


def generate_challenge(problem: dict, grade: int, prompts: dict[str, str], provider_name: str | None,
                       tier: str | None) -> dict | None:
    """FR-30: sinh bài cùng dạng, khó hơn một chút (kèm lời giải BÍ MẬT)."""
    system = render(prompts["challenge"], grade=grade, problem_text=problem["text"], problem_type=problem["type"])
    provider, model = router.get("SOLVER", provider_name, tier)
    try:
        raw = provider.complete(system, "Tạo bài thử thách mới.", model=model, role="CHALLENGE",
                                max_tokens=4000, temperature=0.7, json_schema=schemas.CHALLENGE,
                                effort=settings.effort_for("SOLVER"))
        return normalize_problem(parse_json(raw).get("problem") or {}, 1)
    except (ProviderError, ValueError) as e:
        log.warning("challenge lỗi: %s", e)
        return None
