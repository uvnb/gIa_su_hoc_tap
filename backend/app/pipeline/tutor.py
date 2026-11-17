"""③ TUTOR – điều phối một lượt gia sư: Checker → (ăn mừng | Tutor + Guard) → câu an toàn dự phòng."""
from __future__ import annotations

import json
import re
import logging
import random
from typing import Any

from ..config import settings
from ..providers import router
from ..providers.base import ProviderError
from . import checker, guard, safety, schemas, vn_numbers as vn
from .jsonutil import parse_json, render

log = logging.getLogger("cutomo.tutor")

MODE_RULES = {
    "exercise": "",
    "open_ended": (
        "\n## BÀI VIẾT (tập làm văn / đặt câu)\n"
        "Giúp bạn nhỏ lập dàn ý bằng câu hỏi gợi mở; bạn nhỏ tự nghĩ từng ý, tự nói từng câu.\n"
        "Không viết câu mẫu hoàn chỉnh để chép. Khen ý hay của bạn nhỏ, gợi ý thêm giác quan (nhìn, nghe, sờ).\n"
        "Khi bạn nhỏ đã có đủ 3-4 ý, khen và gợi ý bạn nhỏ tự viết vào vở."
    ),
    "discovery": (
        "\n## CÂU HỎI KHÁM PHÁ\n"
        "Lượt đầu: hỏi bạn nhỏ đoán trước. Khi bạn nhỏ đã đoán hoặc nói không biết, bạn ĐƯỢC giải thích ngắn gọn "
        "(tối đa 3 câu, dùng hình ảnh quen thuộc), rồi hỏi 1 câu nhỏ để bạn nhỏ tự nói lại bằng lời của mình."
    ),
}

STATE_NOTES = {
    "too_hard": "Bạn nhỏ vừa bấm nút 'Khó quá'. Hãy hạ độ khó: dùng ví dụ số nhỏ hơn hoặc công cụ trực quan, giọng thật nhẹ nhàng.",
    "guessing": "Bạn nhỏ đang đoán bừa nhiều lần. KHÔNG nói lớn hơn/nhỏ hơn. Mời bạn nhỏ kể cách tính, quay lại hỏi đề cho gì.",
    "dont_know_streak": "Bạn nhỏ đã nói 'không biết' nhiều lần. Hãy dùng ví dụ thật nhỏ hoặc công cụ trực quan, khen bạn đã cố gắng.",
    "asks_for_answer": "Bạn nhỏ đang xin đáp án. Đồng cảm, nói Cú tin bạn tự tìm được, rồi đưa ra MỘT bước nhỏ xíu.",
    "off_topic": "Bạn nhỏ đang nói chuyện khác. Đáp lại thân thiện một câu rồi nhẹ nhàng quay về bài.",
}


def _num(x: Any) -> int | float:
    try:
        f = float(x)
    except (TypeError, ValueError):
        return 0
    return int(f) if f.is_integer() else f


def owl(say: str, mood: str, sess: dict, state: str | None = None, stars: int = 0,
        ui_actions: list | None = None, **extra: Any) -> dict:
    out = {"owl": {"say": say, "mood": mood}, "hint_level": sess["hint_level"],
           "state": state or sess["state"], "stars_earned": stars, "ui_actions": ui_actions or []}
    out.update(extra)
    return out


def infer_op(problem: dict) -> str:
    """Phép tính để công cụ trực quan hiển thị đúng kiểu (thêm vào / bớt đi / nhóm / chia đều)."""
    t = vn.norm(problem.get("type", "").replace("_", " ") + " " + problem.get("text", ""))
    t = re.sub(r"\b(bài|câu)\s*\d+\s*[:.]", " ", t)  # bỏ "Bài 1:" để không nhầm dấu chia
    if re.search(r"\bchia\b|÷|\d\s*:\s*\d", t):
        return ":"
    if re.search(r"\bnhan\b|\bnhân\b|×|\d\s*x\s*\d|\bmỗi\b", t):
        return "×"
    if re.search(r"\btru\b|\btrừ\b|\bbớt\b|còn lại|cho đi|ăn mất|bay đi|\bbán\b|\d\s*-\s*\d", t):
        return "-"
    return "+"


def validate_actions(actions: list[dict], problem: dict) -> list[dict]:
    """Chỉ cho phép công cụ nhận SỐ TRONG ĐỀ; lựa chọn không được chứa đáp án."""
    keys = problem.get("key_numbers", [])
    nums, words = guard.rule_variants(problem)
    target = vn.numeric_value(str(problem.get("answer", "")))
    clean: list[dict] = []
    seen: set[str] = set()
    for a in actions or []:
        t = a.get("type")
        if t in seen:
            continue
        if t == "show_manipulative":
            tool = a.get("tool")
            if tool not in schemas.TOOLS or tool == "none":
                continue
            av, bv = str(_num(a.get("a"))), str(_num(a.get("b")))
            if not any(vn.same_number(av, k) for k in keys):
                continue
            if bv != "0" and not any(vn.same_number(bv, k) for k in keys):
                continue
            if target and target not in keys and (vn.same_number(av, target) or vn.same_number(bv, target)):
                continue
            clean.append({"type": t, "tool": tool, "a": _num(av), "b": _num(bv), "op": infer_op(problem)})
        elif t == "offer_choices":
            choices = [str(c)[:30] for c in (a.get("choices") or []) if str(c).strip()][:4]
            if len(choices) < 2 or any(guard.rule_leak(c, nums, words) for c in choices):
                continue
            clean.append({"type": t, "choices": choices})
        elif t in ("open_number_pad", "open_scratch_pad", "suggest_break"):
            clean.append({"type": t})
        else:
            continue
        seen.add(t)
    return clean


def _history_text(sess: dict, limit: int = 6) -> str:
    lines = []
    for h in sess.get("history", [])[-limit:]:
        if h.get("child"):
            lines.append(f"Bạn nhỏ: {h['child']}")
        if h.get("owl"):
            lines.append(f"Cú: {h['owl']}")
    return "\n".join(lines) or "(chưa có)"


def _last_owl(sess: dict) -> str:
    for h in reversed(sess.get("history", [])):
        if h.get("owl"):
            return h["owl"]
    return ""


def tutor_system(sess: dict, prompts: dict[str, str]) -> str:
    p = sess["problem"]
    return render(
        prompts["tutor"], nickname=sess["nickname"], grade=sess["grade"], age_hint=int(sess["grade"]) + 5,
        problem_text=p["text"], problem_type=p["type"], steps=p["steps"], answer=p["answer"],
        common_mistakes=p["common_mistakes"], key_numbers=p["key_numbers"], suggested_tool=p["suggested_tool"],
        mode_rules=MODE_RULES.get(p.get("mode", "exercise"), ""),
    )


def _tutor_user(sess: dict, child_input: str, verdict: dict, notes: list[str], retry_note: str) -> str:
    parts = [
        "## TRẠNG THÁI",
        f"Bậc gợi ý hiện tại: L{sess['hint_level']}",
        f"Số lượt đã trao đổi cho câu này: {sess['turns']}",
        f"Kết quả kiểm tra câu trả lời mới nhất: {json.dumps(verdict, ensure_ascii=False)}",
    ]
    if notes:
        parts.append("Lưu ý: " + " ".join(notes))
    parts += ["", "## HỘI THOẠI GẦN ĐÂY", _history_text(sess), "", "## LƯỢT MỚI",
              f'Bạn nhỏ nói: "{child_input}"']
    if retry_note:
        parts.append(retry_note)
    return "\n".join(parts)


def _generate(sess: dict, child_input: str, verdict: dict, notes: list[str], prompts: dict[str, str]) -> tuple[str, str, int, list]:
    """Sinh câu Tutor, qua Guard; tối đa 3 lần rồi dùng câu an toàn."""
    p = sess["problem"]
    system = tutor_system(sess, prompts)
    try:
        provider, model = router.get("TUTOR", sess.get("provider"), sess.get("tier"))
    except ProviderError as e:
        log.error("tutor router: %s", e)
        return safety.safe_line(sess["hint_level"], p.get("mode")), "asking", sess["hint_level"], []
    retry = ""
    for attempt in range(3):
        try:
            raw = provider.complete(system, _tutor_user(sess, child_input, verdict, notes, retry), model=model,
                                    role="TUTOR", max_tokens=1200, temperature=0.6, json_schema=schemas.TUTOR,
                                    effort=settings.effort_for("TUTOR"))
            out = parse_json(raw)
        except (ProviderError, ValueError) as e:
            log.warning("tutor lỗi (lần %d): %s", attempt + 1, e)
            break
        say = str(out.get("say", "")).strip()
        if not say or not safety.output_ok(say):
            retry = "\nLƯU Ý: câu trước không phù hợp. Hãy nói ngắn, thân thiện, đúng bài học."
            continue
        if guard.is_leak(say, p, prompts, sess.get("provider"), sess.get("tier")):
            log.info("guard chặn câu lộ đáp án (lần %d)", attempt + 1)
            retry = ("\nLƯU Ý: câu trước đã làm lộ đáp án. Hãy hỏi gợi mở, KHÔNG nhắc tới kết quả cuối, "
                     "không đánh vần, không xác nhận lần đoán.")
            continue
        mood = out.get("mood") if out.get("mood") in schemas.MOODS else "asking"
        try:
            nxt = int(out.get("next_hint_level", sess["hint_level"]))
        except (TypeError, ValueError):
            nxt = sess["hint_level"]
        return say, mood, nxt, validate_actions(out.get("ui_actions") or [], p)
    return safety.safe_line(sess["hint_level"], p.get("mode")), "asking", sess["hint_level"], []


def opening(sess: dict) -> dict:
    """Lời mở đầu (L0) sau khi bạn nhỏ xác nhận đúng đề (FR-15)."""
    sess["state"] = "tutoring"
    say = safety.opener(sess["problem"].get("mode", "exercise"))
    sess["history"].append({"child": "", "owl": say})
    return owl(say, "asking", sess)


def _bump(sess: dict, to: int | None = None) -> None:
    lvl = sess["hint_level"]
    sess["hint_level"] = max(0, min(5, to if to is not None else lvl + 1))
    sess["max_hint_level"] = max(sess.get("max_hint_level", 0), sess["hint_level"])
    sess["stuck"] = 0


def run_turn(sess: dict, child_input: str, input_mode: str, prompts: dict[str, str]) -> dict:
    child_input = (child_input or "").strip()[:500]
    p = sess["problem"]

    # --- An toàn đầu vào ---
    flag = safety.classify_input(child_input)
    if flag:
        sess.setdefault("safety_flags", []).append(flag)
        say = safety.SELF_HARM_LINE if flag == "self_harm" else safety.UNSAFE_LINE
        sess["history"].append({"child": "(đã ẩn)", "owl": say})
        acts = [{"type": "suggest_break"}] if flag == "self_harm" else []
        return owl(say, "encouraging", sess, ui_actions=acts)

    if sess["state"] == "parked":
        return owl("Câu này mình để dành hỏi thầy cô rồi. Bạn muốn làm câu khác không?", "encouraging", sess)
    if sess["state"] in ("solved", "explaining"):
        return explain_turn(sess, child_input, prompts)

    notes: list[str] = []
    level_before = sess["hint_level"]

    # --- Nút "Khó quá" (FR-28) ---
    if input_mode == "too_hard":
        _bump(sess, 3 if sess["hint_level"] < 3 else sess["hint_level"] + 1)
        verdict = {"verdict": "dont_know", "detected_value": "", "mistake_hint": ""}
        notes.append(STATE_NOTES["too_hard"])
        child_input = child_input or "(Bạn nhỏ bấm nút 'Khó quá')"
    else:
        if not child_input:
            return owl("Cú chưa nghe rõ. Bạn nói lại giúp Cú nhé?", "encouraging", sess)
        verdict = checker.check(p, child_input, _last_owl(sess), prompts, sess.get("provider"), sess.get("tier"))

    v = verdict["verdict"]
    if v == "error":
        say = safety.ERROR_LINE
        return owl(say, "encouraging", sess)

    # --- Bạn nhỏ tự nói ra đáp án (FR-25) ---
    if v == "correct_final":
        sess["state"] = "solved"
        stars = 3 + (1 if sess.get("last_verdict") in ("incorrect", "partially_correct") else 0)  # +1 tự sửa sai
        sess["stars"] = sess.get("stars", 0) + stars
        sess["last_verdict"] = v
        value = verdict.get("detected_value") or "vậy"
        if p.get("mode") == "discovery":
            say = "Đúng rồi, bạn giỏi quá! 🎉 Bạn kể lại cho Cú nghe bằng lời của bạn nhé?"
        else:
            say = f"Bạn tự tìm ra rồi! 🎉 Bạn kể Cú nghe vì sao lại là {value} nhé?"
        sess["history"].append({"child": child_input, "owl": say})
        return owl(say, "celebrating", sess, state="solved", stars=stars, ui_actions=[{"type": "celebrate"}])

    # --- Điều chỉnh bậc gợi ý (chỉ leo 1 bậc mỗi lần) ---
    if input_mode != "too_hard":
        if v in ("incorrect", "dont_know", "asks_for_answer"):
            sess["stuck"] = sess.get("stuck", 0) + 1
        elif v in ("correct_step", "partially_correct"):
            sess["stuck"] = 0
        sess["dont_know_streak"] = sess.get("dont_know_streak", 0) + 1 if v == "dont_know" else 0
        numeric_guess = v == "incorrect" and bool(vn.extract_numbers(child_input))
        sess["guess_streak"] = sess.get("guess_streak", 0) + 1 if numeric_guess else 0
        if sess["dont_know_streak"] >= 3 and sess["hint_level"] < 3:
            _bump(sess, 3)                     # "không biết" 3 lần liền → hạ độ khó (L3)
            notes.append(STATE_NOTES["dont_know_streak"])
        elif sess["stuck"] >= 2:
            _bump(sess)
        if sess["guess_streak"] >= 3:
            notes.append(STATE_NOTES["guessing"])
        if v in STATE_NOTES:
            notes.append(STATE_NOTES[v])
    sess["turns"] = sess.get("turns", 0) + 1
    sess["last_verdict"] = v

    # --- Quá số lượt → để dành hỏi thầy cô (FR-29) ---
    if sess["turns"] >= int(sess.get("max_turns", settings.max_turns_per_problem)):
        sess["state"] = "parked"
        sess["stars"] = sess.get("stars", 0) + 1
        sess["history"].append({"child": child_input, "owl": safety.PARKED_LINE})
        return owl(safety.PARKED_LINE, "encouraging", sess, state="parked", stars=1)

    # --- "Mẹ cho phép xem đáp án" → câu dựng sẵn (mục 3.3) ---
    if v == "asks_for_answer" and safety.mentions_permission(child_input):
        say, mood, nxt, actions = safety.PERMISSION_LINE, "encouraging", sess["hint_level"], []
    else:
        say, mood, nxt, actions = _generate(sess, child_input, verdict, notes, prompts)

    # Tutor được đề xuất bậc mới nhưng không nhảy quá 1 bậc so với đầu lượt.
    if nxt > sess["hint_level"]:
        _bump(sess, min(nxt, max(sess["hint_level"], level_before) + 1))

    # Bậc L4: tự mở công cụ trực quan nếu Tutor quên (FR-24)
    if sess["hint_level"] >= 4 and not sess.get("tool_shown") and not any(a["type"] == "show_manipulative" for a in actions):
        keys = p.get("key_numbers", [])
        if p.get("suggested_tool", "none") != "none" and len(keys) >= 1:
            auto = validate_actions([{"type": "show_manipulative", "tool": p["suggested_tool"],
                                      "a": keys[0], "b": keys[1] if len(keys) > 1 else 0}], p)
            actions = auto + actions
    if any(a["type"] == "show_manipulative" for a in actions):
        sess["tool_shown"] = True

    stars = 1 if v in ("correct_step", "partially_correct") else 0
    if stars and sess.get("prev_wrong"):
        stars += 1  # tự sửa sai
    sess["prev_wrong"] = v == "incorrect"
    sess["stars"] = sess.get("stars", 0) + stars
    sess["history"].append({"child": child_input, "owl": say})
    state = "break_suggested" if any(a["type"] == "suggest_break" for a in actions) else "tutoring"
    return owl(say, mood, sess, state=state, stars=stars, ui_actions=actions)


def explain_turn(sess: dict, child_input: str, prompts: dict[str, str]) -> dict:
    """Bạn nhỏ tự giải thích sau khi làm đúng (mục 3.4) – không cần Guard vì đáp án do bạn nhỏ nói ra."""
    p = sess["problem"]
    first = sess["state"] == "solved"
    sess["state"] = "explaining"
    system = render(prompts["explain"], nickname=sess["nickname"], grade=sess["grade"], problem_text=p["text"],
                    answer=p["answer"], steps=p["steps"])
    quality, fun = "partial", ""
    try:
        provider, model = router.get("TUTOR", sess.get("provider"), sess.get("tier"))
        out = parse_json(provider.complete(system, f'Bạn nhỏ giải thích: "{child_input}"', model=model,
                                           role="EXPLAIN", max_tokens=1000, temperature=0.6,
                                           json_schema=schemas.EXPLAIN, effort=settings.effort_for("TUTOR")))
        say = str(out.get("say", "")).strip()
        quality = out.get("explanation_quality", "partial")
        fun = str(out.get("fun_question", "")).strip()
        mood = out.get("mood") if out.get("mood") in schemas.MOODS else "celebrating"
        if not say or not safety.output_ok(say):
            raise ValueError("say rỗng")
    except (ProviderError, ValueError) as e:
        log.warning("explain lỗi: %s", e)
        say, mood = "Bạn giải thích hay lắm! Bạn muốn làm câu tiếp hay thử thách khó hơn?", "celebrating"
    stars = 0
    if first:
        stars = {"good": 2, "partial": 1}.get(quality, 0)  # sao cho việc tự giải thích (FR-40)
    sess["stars"] = sess.get("stars", 0) + stars
    sess["history"].append({"child": child_input, "owl": say})
    extra: dict[str, Any] = {}
    if fun and not sess.get("fun_question_used") and random.random() < 0.7:
        sess["fun_question_used"] = True  # FR-45: tối đa 1 lần/phiên
        extra["fun_question"] = fun
    return owl(say, mood, sess, state="explaining", stars=stars,
               ui_actions=[{"type": "offer_next"}], **extra)


def scratch_review(sess: dict, image: bytes, media_type: str, prompts: dict[str, str]) -> dict:
    """FR-23: Cú xem bảng nháp – nhận xét CÁCH LÀM, không viết đáp án."""
    p = sess["problem"]
    system = render(prompts["scratch"], nickname=sess["nickname"], grade=sess["grade"], problem_text=p["text"],
                    steps=p["steps"], answer=p["answer"])
    fallback = owl("Cú thấy bạn đã viết nháp rồi! Bạn kể Cú nghe bạn đã làm bước nào nhé?", "encouraging", sess)
    try:
        provider, model = router.get("TUTOR", sess.get("provider"), sess.get("tier"))
        out = parse_json(provider.complete(system, "Đây là bảng nháp của bạn nhỏ.", model=model, role="SCRATCH",
                                           image_bytes=image, image_media_type=media_type, max_tokens=1000,
                                           temperature=0.4, json_schema=schemas.SCRATCH,
                                           effort=settings.effort_for("TUTOR")))
    except (ProviderError, ValueError) as e:
        log.warning("scratch lỗi: %s", e)
        return fallback
    say = str(out.get("say", "")).strip()
    if not say or not safety.output_ok(say) or guard.is_leak(say, p, prompts, sess.get("provider"), sess.get("tier")):
        return fallback
    if out.get("child_wrote_final") and sess["state"] == "tutoring":
        say = say.rstrip() + " Bạn đọc to kết quả cho Cú nghe nhé?"
    mood = out.get("mood") if out.get("mood") in schemas.MOODS else "encouraging"
    sess["history"].append({"child": "(gửi bảng nháp)", "owl": say})
    return owl(say, mood, sess)
