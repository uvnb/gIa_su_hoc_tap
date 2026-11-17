import pytest

from app.pipeline import guard, tutor

PROBLEM = {
    "text": "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?",
    "mode": "exercise", "answer": "12 cái kẹo", "answer_variants": ["12", "12 cái", "mười hai"],
    "key_numbers": ["7", "5"], "steps": [], "common_mistakes": [], "suggested_tool": "sticks", "type": "x",
}


@pytest.mark.parametrize("candidate", [
    "Đáp án là 12 đó!",
    "Kết quả là mười hai nhé",
    "7 + 5 = 12, bạn thấy không?",
    "Số đó là 1 rồi 2 đấy.",
    "Số đó là 1, 2 đấy.",
    "Có phải mười hai không nhỉ?",
])
def test_rule_leak_detects(candidate):
    nums, words = guard.rule_variants(PROBLEM)
    assert guard.rule_leak(candidate, nums, words)


@pytest.mark.parametrize("candidate", [
    "Lúc đầu Lan có mấy cái kẹo? Mẹ cho thêm 5 cái thì sao?",
    "Mình thử bài nhỏ hơn: 2 thêm 1 là mấy?",
    "Bạn đọc lại đề cùng Cú nhé. Đề hỏi gì nào?",
    "Mình có 7 que và 5 que, bạn đếm thử nhé?",
])
def test_rule_leak_allows_safe(candidate):
    nums, words = guard.rule_variants(PROBLEM)
    assert not guard.rule_leak(candidate, nums, words)


def test_answer_in_problem_is_excluded_from_rules():
    p = dict(PROBLEM, text="So sánh 12 và 15. Số nào lớn hơn?", answer="15", answer_variants=["15"],
             key_numbers=["12", "15"])
    nums, words = guard.rule_variants(p)
    assert nums == []  # 15 có trong đề → để AI giám khảo quyết định
    assert guard.needs_llm_check("Bạn nhìn số 15 nhé", p)


def test_text_answer_rule():
    p = {"text": "Điền s hay x: ...ách vở", "mode": "exercise", "answer": "sách", "answer_variants": ["sách", "s"],
         "key_numbers": [], "steps": [], "common_mistakes": [], "suggested_tool": "none", "type": "chinh_ta"}
    nums, words = guard.rule_variants(p)
    assert words == ["sách"]  # "s" quá ngắn và có trong đề → bỏ qua ở lớp quy tắc
    assert guard.rule_leak("Từ đúng là sách đó", nums, words)
    assert not guard.rule_leak("Bạn đọc to từ đó lên nhé", nums, words)
    assert not guard.rule_leak("Bạn ơi", nums, words)  # "bạn" khác "bàn"/"sách" – giữ dấu


def test_smart_mode_skips_llm_without_numbers():
    assert not guard.needs_llm_check("Bạn kể lại đề cho Cú nghe nhé?", PROBLEM)
    assert guard.needs_llm_check("Bạn thử 7 cộng 5 xem", PROBLEM)
    assert guard.needs_llm_check("Kết quả chính là con số đó", PROBLEM)


def test_validate_actions_only_numbers_in_problem():
    acts = tutor.validate_actions([
        {"type": "show_manipulative", "tool": "sticks", "a": 7, "b": 5, "choices": []},
        {"type": "show_manipulative", "tool": "sticks", "a": 12, "b": 0, "choices": []},
        {"type": "offer_choices", "tool": "none", "a": 0, "b": 0, "choices": ["11", "12", "13"]},
        {"type": "open_number_pad", "tool": "none", "a": 0, "b": 0, "choices": []},
    ], PROBLEM)
    assert acts == [{"type": "show_manipulative", "tool": "sticks", "a": 7, "b": 5, "op": "+"}, {"type": "open_number_pad"}]


def test_validate_actions_rejects_result_tool():
    acts = tutor.validate_actions([{"type": "show_manipulative", "tool": "sticks", "a": 12, "b": 5}], PROBLEM)
    assert acts == []
    acts = tutor.validate_actions([{"type": "offer_choices", "choices": ["cộng", "trừ"]}], PROBLEM)
    assert acts == [{"type": "offer_choices", "choices": ["cộng", "trừ"]}]
