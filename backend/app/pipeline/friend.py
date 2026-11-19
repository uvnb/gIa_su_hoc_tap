"""💛 Góc tâm sự – Cú là người bạn lắng nghe (tâm lý học đường) với NHIỀU LỚP AN TOÀN.

Lớp 1 – đầu vào: phát hiện nguy cơ (muốn chết / tự làm đau, bị xâm hại – bạo hành, ý định làm việc nguy hiểm)
         → KHÔNG gọi AI, trả lời bằng câu soạn sẵn đã kiểm duyệt + hướng tới người lớn và tổng đài 111.
Lớp 2 – lời dặn AI (prompts/friend.md): nguyên tắc tuyệt đối không xúi trẻ làm việc nguy hiểm, không bảo giữ bí mật…
Lớp 3 – đầu ra: câu AI trả lời có dấu hiệu xúi làm việc nguy hiểm / giữ bí mật / gặp người lạ / từ không phù hợp
         → thay bằng câu an toàn soạn sẵn.
Riêng tư: KHÔNG lưu nội dung trò chuyện. Chỉ ghi (theo ngày) số lượt, tâm trạng bé chọn và loại cảnh báo
để bố mẹ biết bé có cần quan tâm không.
"""
from __future__ import annotations

import datetime as dt
import random
import re
from typing import Any

from ..providers import router
from ..providers.base import ProviderError
from . import safety
from . import vn_numbers as vn
from .jsonutil import parse_json, render

HOTLINE = "111"

# ---------------------------------------------------------------- lớp 1: phát hiện nguy cơ (so trên bản bỏ dấu)
# "từ từ" bỏ dấu trùng "tự tử", "cắt tay" có thể chỉ là đứt tay khi gọt táo → "tự tử" so trên bản có dấu
# (safety.classify_input), chỉ bắt "tự cắt tay".
_SELF_HARM = [r"tu sat", r"muon chet", r"khong muon song", r"tu lam dau", r"tu cat (tay|minh)",
              r"muon bien mat", r"ghet ban than", r"chet di cho xong", r"nhay lau", r"uong thuoc cho chet"]
_ABUSE = [r"bi (danh|dap|tat|bop co|nhot|doa)", r"(bo|me|ba|ong|chu|co|thay|anh|chi|nguoi lon) (danh|tat|dap) (con|chau|em|minh)",
          r"bi (so|cham|xo) (vao|chim|vung kin|cho kin|nguc|mong)", r"(so|cham) vao (chim|vung kin|cho kin)",
          r"cho (con|chau|em) xem (chim|cho kin)", r"bat (con|em|chau) coi (do|quan|ao)", r"bi nguoi la (theo|bat|dua)",
          r"bi bat coc", r"bi de doa", r"doa (giet|danh|bat)"]
_DANGER_INTENT = [r"(muon|se|dinh|thu) (nhay|leo|treo) (tu|len|xuong|qua)", r"(muon|se|dinh|thu) (chơi|choi|nghich) (lua|dien|dao|diem|bat lua|thuoc|o dien)",
                  r"(muon|se|dinh) bo (nha|di)", r"(muon|se|dinh|thu) (bat lua|dot)", r"(muon|se|dinh) (danh|dam|tra thu|dap)",
                  r"(muon|se|dinh) di (theo|gap) nguoi la", r"(muon|se|dinh) (boi|ra song|ra ho|ra suoi) mot minh",
                  r"thu thach (nguy hiem|tren mang)"]

CRISIS_SELF_HARM = (
    "Cú rất thương {name} và lo cho {name} lắm. Những điều bạn đang nghĩ rất quan trọng. "
    "Bạn hãy nói ngay với bố mẹ, thầy cô hoặc một người lớn bạn tin tưởng nhé. "
    "Nếu cần, gọi số 111 – miễn phí, có cô chú lắng nghe và giúp bạn. Bạn không một mình đâu.")
CRISIS_ABUSE = (
    "Cảm ơn {name} đã dũng cảm kể cho Cú. Không ai được phép làm bạn đau hay làm bạn sợ, và đó KHÔNG phải lỗi của bạn. "
    "Bạn hãy kể ngay với một người lớn bạn tin tưởng như bố, mẹ, ông bà hay thầy cô. "
    "Bạn cũng có thể gọi số 111 – miễn phí – để được giúp đỡ.")
VIOLENCE_REDIRECT = (
    "Cú hiểu là {name} đang giận lắm. Nhưng đánh nhau sẽ làm cả hai bạn bị đau và buồn hơn đấy. "
    "Mình hít thở thật sâu cùng Cú nhé, rồi kể với thầy cô hoặc bố mẹ để người lớn giúp bạn nha!")
DANGER_REDIRECT = (
    "Ối, việc đó có thể làm {name} bị đau đấy, Cú không muốn bạn gặp nguy hiểm đâu. "
    "Mình không làm nhé! Bạn hỏi bố mẹ trước, rồi Cú với bạn tìm trò khác vui mà an toàn nha?")
BAD_WORD_LINE = "Cú nghĩ mình dùng lời hay ý đẹp nhé. Bạn đang thấy bực mình à? Kể Cú nghe chuyện gì xảy ra nào?"
SAFE_FALLBACKS = [
    "Cú đang lắng nghe {name} đây. Bạn kể thêm cho Cú nghe nhé? Chuyện quan trọng thì mình kể với bố mẹ, thầy cô nữa nha.",
    "Cú hiểu mà. Mình cùng hít thở thật chậm một chút nhé, rồi bạn kể tiếp cho Cú nghe?",
    "Cảm ơn {name} đã chia sẻ với Cú. Bạn muốn kể thêm điều gì nữa không?",
]


def _plain(text: str) -> str:
    return vn.strip_accents(vn.norm(text))


def classify(text: str) -> str | None:
    """'self_harm' | 'abuse' | 'danger' | 'unsafe' | None."""
    p = _plain(text)
    if any(re.search(x, p) for x in _SELF_HARM) or safety.classify_input(text) == "self_harm":
        return "self_harm"
    if any(re.search(x, p) for x in _ABUSE):
        return "abuse"
    if any(re.search(x, p) for x in _DANGER_INTENT):
        return "danger"
    if safety.classify_input(text) == "unsafe":
        return "unsafe"
    return None


# ---------------------------------------------------------------- lớp 3: kiểm câu trả lời
_REPLY_FORBIDDEN = [
    r"giu bi mat", r"(dung|khong can|chang can) (ke|noi|bao) (voi |cho )?(bo|me|ai|thay|co|nguoi lon)",
    r"gap nguoi la", r"di theo nguoi", r"tra thu", r"danh lai", r"(cu|ban) (hay|nen|cu) bo nha", r"tu lam dau",
    r"so dien thoai cua ban", r"dia chi nha", r"mat khau",
]
_DANGER_WORDS = [r"\bdao\b", r"\bkeo\b", r"\blua\b", r"\bdiem\b", r"bat lua", r"o dien", r"\bdien\b", r"thuoc",
                 r"hoa chat", r"leo (len|cao)", r"\bnhay\b", r"ra song", r"ra ho", r"\bboi\b"]
# Lời cấm / cảnh báo. Không dùng "chớ" (bỏ dấu thành "cho" – trùng "cho mát", "cho bạn") hay "xa" (trùng "xa nhà").
_NEGATION = re.compile(r"\b(khong|dung|tranh|nguy hiem|khong an toan|hoi bo me|tranh xa|cam)\b")


def reply_ok(say: str) -> bool:
    """Câu Cú nói có an toàn không. Nhắc tới đồ vật nguy hiểm chỉ được phép khi là lời CẤM / CẢNH BÁO."""
    if not say or not safety.output_ok(say):
        return False
    p = _plain(say)
    if any(re.search(x, p) for x in _REPLY_FORBIDDEN):
        return False
    for sentence in re.split(r"[.!?\n]+", p):
        if any(re.search(x, sentence) for x in _DANGER_WORDS) and not _NEGATION.search(sentence):
            return False
    return len(say) <= 400


# ---------------------------------------------------------------- trò chuyện
MOODS = {"vui": "vui 😊", "buon": "buồn 😢", "gian": "giận 😠", "so": "sợ 😨", "met": "mệt 😴", "lo": "lo lắng 🤔"}


def chat(*, nickname: str, grade: int, mood: str, message: str, history: list[dict[str, str]],
         prompts: dict[str, str], provider: str | None = None, tier: str | None = None) -> dict[str, Any]:
    name = (nickname or "bạn").strip()[:20] or "bạn"
    msg = (message or "").strip()[:300]
    flag = classify(msg)
    if flag == "self_harm":
        return {"say": CRISIS_SELF_HARM.format(name=name), "owl_mood": "encouraging", "suggest_breathing": True,
                "crisis": "self_harm", "hotline": HOTLINE, "flag": flag}
    if flag == "abuse":
        return {"say": CRISIS_ABUSE.format(name=name), "owl_mood": "encouraging", "suggest_breathing": False,
                "crisis": "abuse", "hotline": HOTLINE, "flag": flag}
    if flag == "danger" and re.search(r"(danh|dam|tra thu|dap)", _plain(msg)):
        return {"say": VIOLENCE_REDIRECT.format(name=name), "owl_mood": "encouraging", "suggest_breathing": True,
                "crisis": "", "hotline": "", "flag": flag}
    if flag == "danger":
        return {"say": DANGER_REDIRECT.format(name=name), "owl_mood": "encouraging", "suggest_breathing": False,
                "crisis": "", "hotline": "", "flag": flag}
    if flag == "unsafe":
        return {"say": BAD_WORD_LINE, "owl_mood": "thinking", "suggest_breathing": True, "crisis": "", "hotline": "",
                "flag": ""}

    system = render(prompts["friend"], nickname=name, grade=grade, mood=MOODS.get(mood, "chưa chọn"))
    lines = []
    for h in history[-8:]:
        who = "Bé" if h.get("who") == "child" else "Cú"
        lines.append(f"{who}: {str(h.get('text', ''))[:300]}")
    lines.append(f"Bé: {msg}")
    user = "Cuộc trò chuyện:\n" + "\n".join(lines) + "\n\nCú trả lời câu cuối của bé."
    say, owl_mood, breathe = "", "listening", mood in ("buon", "gian", "so", "lo")
    try:
        p, model = router.get("TUTOR", provider, tier)
        out = parse_json(p.complete(system, user, model=model, role="FRIEND", max_tokens=400))
        say = str(out.get("say", "")).strip()
        owl_mood = str(out.get("owl_mood", "listening"))
        breathe = bool(out.get("suggest_breathing", breathe))
    except (ProviderError, ValueError, KeyError, TypeError):
        say = ""
    if not reply_ok(say):
        say = random.choice(SAFE_FALLBACKS).format(name=name)
    if owl_mood not in ("listening", "encouraging", "celebrating", "thinking"):
        owl_mood = "listening"
    return {"say": say, "owl_mood": owl_mood, "suggest_breathing": breathe, "crisis": "", "hotline": "", "flag": ""}


def day_session_id(device_id: str, child_id: str) -> str:
    """Mỗi bé mỗi ngày một dòng nhật ký Góc tâm sự (chỉ số lượt, tâm trạng, cảnh báo – không có nội dung)."""
    return f"tamsu-{device_id[:16]}-{child_id[:24]}-{dt.date.today().isoformat()}"
