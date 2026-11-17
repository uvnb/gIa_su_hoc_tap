"""An toàn trẻ em (mục 15): lọc từ ngữ không phù hợp ở đầu vào/đầu ra + câu an toàn dựng sẵn."""
from __future__ import annotations

import random
import re

from . import vn_numbers as vn

# Câu an toàn theo bậc gợi ý (mục 11) – dùng khi Tutor làm lộ đáp án quá 2 lần hoặc AI lỗi.
SAFE_LINES = {
    0: "Bạn đọc lại đề bài cùng Cú nhé. Đề bài hỏi mình điều gì?",
    1: "Đề bài cho mình biết những số nào nhỉ?",
    2: "Mình nên làm phép tính gì đây? Bạn nghĩ sao?",
    3: "Mình thử một bài giống vậy nhưng số nhỏ hơn nhé. Bạn sẵn sàng chưa?",
    4: "Mình cùng xếp que tính để đếm nhé! Bạn bắt đầu xếp đi.",
    5: "Mình làm từng bước nhỏ xíu nhé. Bước đầu tiên bạn làm gì?",
}
SAFE_LINES_WRITING = {
    0: "Đề bài muốn mình viết về điều gì nhỉ? Bạn kể Cú nghe nhé!",
    1: "Bạn nghĩ ra một ý đầu tiên chưa? Bạn nói thử cho Cú nghe nhé.",
    2: "Ý đó hay đấy! Bạn muốn kể thêm điều gì nữa?",
    3: "Mình nhắm mắt tưởng tượng nhé. Bạn thấy gì đầu tiên?",
    4: "Bạn thử nói một câu thật ngắn về nó nhé?",
    5: "Mình làm từng ý nhỏ thôi. Ý đầu tiên của bạn là gì?",
}

OPENERS = [
    "Cú đọc bài rồi! Bạn kể lại cho Cú nghe: bài này hỏi mình điều gì nào?",
    "Mình cùng làm nhé! Bạn đọc to đề bài, rồi nói Cú nghe đề hỏi gì nhé?",
    "Bài thú vị quá! Bạn thấy đề bài cho mình biết những gì?",
]
OPENERS_WRITING = [
    "Bài viết này hay lắm! Bạn muốn viết về điều gì nào?",
    "Mình cùng nghĩ ý nhé! Đề bài muốn mình viết về gì?",
]
OPENERS_DISCOVERY = [
    "Câu hỏi hay quá! Bạn đoán thử xem vì sao nào?",
    "Ồ, Cú cũng tò mò lắm! Bạn nghĩ thế nào?",
]

ASK_ANSWER_LINES = [
    "Cú biết bạn muốn biết ngay! Nhưng Cú tin bạn tự tìm ra được. Mình làm bước nhỏ xíu này nhé?",
    "Cú chỉ gợi ý thôi, vì bạn giỏi lắm mà! Mình thử lại từng bước nhé?",
]
PERMISSION_LINE = ("Cú là bạn đồng hành nên Cú chỉ gợi ý thôi. Nếu bố mẹ muốn xem, bố mẹ vào Góc phụ huynh nhé! "
                   "Giờ mình thử bước tiếp theo nha?")
UNSAFE_LINE = "Chuyện này mình nên hỏi bố mẹ hoặc thầy cô nhé. Mình quay lại bài học cùng Cú nha?"
SELF_HARM_LINE = ("Cú thương bạn lắm. Bạn hãy nói ngay với bố mẹ hoặc thầy cô điều bạn đang nghĩ nhé, "
                  "người lớn sẽ giúp bạn. Bạn có muốn nghỉ một chút không?")
PARKED_LINE = "Bạn đã cố gắng rất nhiều rồi! Mình để dành câu này hỏi thầy cô nhé. Làm câu khác không?"
ERROR_LINE = "Ối, Cú hơi chậm một chút. Bạn nói lại giúp Cú nhé?"

# Danh sách tối thiểu – mở rộng theo thực tế.
# Từ nào bỏ dấu sẽ trùng từ bình thường ("lớn"/"lồn", "các"/"cặc", "từ từ"/"tự tử") thì CHỈ so trên bản có dấu.
_BAD_ACCENTED = [r"\blồn\b", r"\bcặc\b", r"\bđéo\b", r"\bđịt\b", r"\bđụ\b", r"\bchó chết\b", r"\bóc chó\b"]
_BAD_PLAIN = [r"\bdm\b", r"\bdmm\b", r"\bvcl\b", r"\bfuck", r"\bshit\b", r"\bbitch"]
_DANGER_PLAIN = [r"\bthuoc no\b", r"\bche bom\b", r"\bmua sung\b", r"\bma tuy\b", r"\bthuoc phien\b"]
_SELF_HARM_ACCENTED = [r"\btự tử\b", r"\btự sát\b", r"\bmuốn chết\b", r"\bkhông muốn sống\b",
                       r"\btự làm đau\b"]


def _plain(text: str) -> str:
    return vn.strip_accents(vn.norm(text))


def _bad(text: str) -> bool:
    a, p = vn.norm(text), _plain(text)
    return (any(re.search(x, a) for x in _BAD_ACCENTED)
            or any(re.search(x, p) for x in _BAD_PLAIN + _DANGER_PLAIN))


def classify_input(text: str) -> str | None:
    """Trả 'self_harm' | 'unsafe' | None."""
    if any(re.search(x, vn.norm(text)) for x in _SELF_HARM_ACCENTED):
        return "self_harm"
    if _bad(text):
        return "unsafe"
    return None


def output_ok(text: str) -> bool:
    return not _bad(text)


def safe_line(level: int, mode: str = "exercise") -> str:
    table = SAFE_LINES_WRITING if mode == "open_ended" else SAFE_LINES
    return table.get(max(0, min(5, level)), table[0])


def opener(mode: str) -> str:
    if mode == "open_ended":
        return random.choice(OPENERS_WRITING)
    if mode == "discovery":
        return random.choice(OPENERS_DISCOVERY)
    return random.choice(OPENERS)


def mentions_permission(text: str) -> bool:
    p = _plain(text)
    return bool(re.search(r"(cho phep|dong y|bao con|me bao|bo bao|co bao|co giao bao|thay bao)", p))
