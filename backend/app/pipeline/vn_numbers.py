"""Chuẩn hóa văn bản tiếng Việt và đổi số đọc bằng chữ sang chữ số.

Dùng cho:
- Answer Guard (mục 11): "mười hai" → 12 trước khi so khớp đáp án.
- Checker nhanh: bạn nhỏ nói "mười hai cái" → 12.
"""
from __future__ import annotations

import re
import unicodedata
from fractions import Fraction

UNITS = {
    "không": 0, "một": 1, "mốt": 1, "hai": 2, "ba": 3, "bốn": 4, "tư": 4, "năm": 5, "lăm": 5,
    "nhăm": 5, "sáu": 6, "bảy": 7, "bẩy": 7, "tám": 8, "chín": 9,
}
# Từ chỉ là số khi đứng sau một chữ số khác (tránh "tư" = thứ tư, "lăm"...).
TRAILING_ONLY = {"mốt", "tư", "lăm", "nhăm"}
# Từ quá mơ hồ khi đứng một mình ("không" = phủ định) → chỉ đổi khi nằm trong cụm số.
AMBIGUOUS_ALONE = {"không", "tư", "mốt", "lăm", "nhăm", "linh", "lẻ", "mươi", "trăm", "nghìn",
                   "ngàn", "triệu", "chục"}
TENS_WORDS = {"mươi", "chục"}
NUMBER_WORDS = set(UNITS) | {"mười", "mươi", "chục", "trăm", "nghìn", "ngàn", "triệu", "linh", "lẻ"}

_WORD_RE = re.compile(r"[0-9]+(?:[.,][0-9]+)*(?:/[0-9]+)?|[^\W\d_]+|[^\w\s]|\s+", re.UNICODE)


def norm(s: str) -> str:
    """Chữ thường, NFC, gộp khoảng trắng. GIỮ dấu tiếng Việt (bàn ≠ bạn)."""
    s = unicodedata.normalize("NFC", str(s)).lower()
    s = s.replace(" ", " ")
    return re.sub(r"\s+", " ", s).strip()


def strip_accents(s: str) -> str:
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    return s.replace("đ", "d").replace("Đ", "D")


def _parse_run(words: list[str]) -> list[int]:
    """Đổi một cụm từ số liên tiếp thành 1 hoặc nhiều số nguyên."""
    out: list[int] = []
    total = 0      # phần đã nhân nghìn/triệu
    seg = 0        # phần < 1000 đang dựng
    last = None    # chữ số đơn vị vừa đọc
    started = False

    def flush():
        nonlocal total, seg, last, started
        if started:
            out.append(total + seg)
        total, seg, last, started = 0, 0, None, False

    prev = None
    for w in words:
        if w in UNITS:
            d = UNITS[w]
            if w in TRAILING_ONLY and prev in UNITS and prev not in ("không",) and seg < 10 and last is not None:
                # "hai mốt" = 21, "ba lăm" = 35 (cách đọc tắt)
                seg = seg - last + last * 10 + d
                last = None
            elif last is not None and prev in UNITS and not (prev == "không" and seg >= 100):
                # Hai chữ số đứng liền mà không có "mươi/trăm" → là hai số riêng ("một hai ba")
                flush()
                seg, last, started = d, d, True
            else:
                seg += d
                last = d
                started = True
        elif w == "mười":
            seg += 10
            last = None
            started = True
        elif w in TENS_WORDS:
            if last is not None:
                seg = seg - last + last * 10
                last = None
        elif w == "trăm":
            if last is not None:
                seg = seg - last + last * 100
            elif not started:
                seg = 100
            last = None
            started = True
        elif w in ("nghìn", "ngàn"):
            total += (seg or 1) * 1000
            seg, last = 0, None
            started = True
        elif w == "triệu":
            total += (seg or 1) * 1_000_000
            seg, last = 0, None
            started = True
        elif w in ("linh", "lẻ"):
            last = None
        prev = w
    flush()
    return out


def words_to_digits(text: str) -> str:
    """'Lan có mười hai cái kẹo' → 'lan có 12 cái kẹo'. Giữ nguyên dấu câu và khoảng trắng."""
    t = norm(text)
    tokens = _WORD_RE.findall(t)
    result: list[str] = []
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if tok in NUMBER_WORDS:
            # gom cụm: từ số xen khoảng trắng
            j = i
            run: list[str] = []
            last_word_idx = i
            while j < len(tokens):
                if tokens[j] in NUMBER_WORDS:
                    run.append(tokens[j])
                    last_word_idx = j
                    j += 1
                elif tokens[j].isspace():
                    j += 1
                else:
                    break
            if len(run) == 1 and run[0] in AMBIGUOUS_ALONE:
                result.append(tok)
                i += 1
                continue
            nums = _parse_run(run)
            if nums:
                result.append(" ".join(str(n) for n in nums))
            else:
                result.append("".join(tokens[i:last_word_idx + 1]))
            i = last_word_idx + 1
        else:
            result.append(tok)
            i += 1
    return "".join(result)


_NUM_RE = re.compile(r"(?<![\d/])(\d+(?:[.,]\d+)*)(?:\s*/\s*(\d+))?(?![\d/])")


def _canon_number(raw: str) -> str:
    """'1.000' → '1000'; '2,5' → '2.5'; '12' → '12'."""
    s = raw
    if re.fullmatch(r"\d{1,3}(\.\d{3})+", s):        # nghìn kiểu VN: 1.000
        s = s.replace(".", "")
    elif re.fullmatch(r"\d{1,3}(,\d{3})+", s) and len(s) > 5:  # 1,000,000 kiểu EN
        s = s.replace(",", "")
    s = s.replace(",", ".")
    try:
        f = Fraction(s)
    except ValueError:
        return s
    if f.denominator == 1:
        return str(f.numerator)
    return str(float(f)).rstrip("0").rstrip(".")


def extract_numbers(text: str, *, convert_words: bool = True) -> list[str]:
    """Trích mọi số (dạng chuẩn) theo thứ tự xuất hiện. Phân số giữ dạng 'a/b'."""
    t = words_to_digits(text) if convert_words else norm(text)
    out: list[str] = []
    for m in _NUM_RE.finditer(t):
        a, b = m.group(1), m.group(2)
        if b:
            out.append(f"{_canon_number(a)}/{_canon_number(b)}")
        else:
            out.append(_canon_number(a))
    return out


def numeric_value(answer: str) -> str | None:
    """Nếu đáp án là một số (có thể kèm đơn vị: '12 cái kẹo'), trả số dạng chuẩn."""
    nums = extract_numbers(answer)
    if len(nums) == 1:
        return nums[0]
    return None


def same_number(a: str, b: str) -> bool:
    if a == b:
        return True
    try:
        return Fraction(a.replace(",", ".")) == Fraction(b.replace(",", "."))
    except (ValueError, ZeroDivisionError):
        return False
