"""Cú Brain – backend FastAPI của Cú Tò Mò.

Chạy:  uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
"""
from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import io
import json
import logging
import threading
import time
from collections import defaultdict
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Optional

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from fastapi.staticfiles import StaticFiles

from . import store
from .config import TIERS, settings
from .models import (DeviceRegistration, FriendRequest, FriendResponse, MysteryBox, Owl, ParentAnswer,
                     ParentReport, ProblemBrief, ReportItem,
                     SelectRequest, SessionRef, StartResponse, TtsRequest, TurnRequest, TurnResponse)
from . import tts
from .pipeline import friend, safety, solver, tutor
from .providers import request_keys, router
from .providers.base import ProviderError, ProviderRefusal

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("cutomo")

PROMPTS: dict[str, str] = {p.stem: p.read_text(encoding="utf-8")
                           for p in (Path(__file__).parent / "prompts").glob("*.md")}
MYSTERY = json.loads((Path(__file__).parent / "content" / "mystery_box.json").read_text(encoding="utf-8"))
SUBJECTS = ("math", "vietnamese", "english", "science", "vietnam")
MAX_IMAGE_BYTES = 6 * 1024 * 1024


def _cleanup_loop(stop: threading.Event) -> None:
    while not stop.is_set():
        try:
            removed = store.cleanup()
            if any(removed.values()):
                log.info("dọn dữ liệu cũ: %s", removed)
        except Exception as e:  # pragma: no cover
            log.warning("cleanup lỗi: %s", e)
        stop.wait(3600)


@asynccontextmanager
async def lifespan(_: FastAPI):
    stop = threading.Event()
    t = threading.Thread(target=_cleanup_loop, args=(stop,), daemon=True)
    t.start()
    if settings.ocr_mode != "off":
        # Nạp sẵn mô hình OCR ở nền để lần chụp bài đầu tiên không phải chờ.
        from .pipeline import ocr
        threading.Thread(target=ocr.warm_up, daemon=True).start()
    if settings.app_shared_secret == "change-me":
        log.warning("APP_SHARED_SECRET đang là giá trị mặc định – hãy đổi trong .env trước khi dùng thật!")
    yield
    stop.set()


# Trên cloud (Firestore) tắt trang tài liệu /docs công khai.
_cloud = settings.store_backend == "firestore"
app = FastAPI(title="Cu To Mo Brain", version="1.0.0", lifespan=lifespan,
              docs_url=None if _cloud else "/docs", redoc_url=None if _cloud else "/redoc",
              openapi_url=None if _cloud else "/openapi.json")
if settings.cors_origin_regex and settings.cors_origin_regex.lower() != "off":
    app.add_middleware(CORSMiddleware, allow_origin_regex=settings.cors_origin_regex,
                       allow_methods=["GET", "POST", "DELETE", "OPTIONS"], allow_headers=["*"])


@app.middleware("http")
async def _parent_ai_key(request: Request, call_next):
    """Khóa AI riêng của phụ huynh (header x-ai-*) chỉ sống trong yêu cầu này – không lưu, không ghi log."""
    h = request.headers
    token = request_keys.set_from_headers(h.get("x-ai-provider"), h.get("x-ai-key"), h.get("x-ai-model"))
    try:
        return await call_next(request)
    finally:
        request_keys.reset(token)


# ------------------------------ xác thực ------------------------------

def require_app(x_app_secret: Optional[str] = Header(None)) -> None:
    allowed = [x.strip() for x in settings.app_shared_secret.split(",") if x.strip()]
    if not x_app_secret or not any(hmac.compare_digest(x_app_secret, a) for a in allowed):
        raise HTTPException(401, "Sai app secret")


def _parent_ok(device_id: str, token: Optional[str]) -> None:
    if not store.check_parent_token(device_id, token):
        raise HTTPException(403, "Cần mã phụ huynh hợp lệ")


# ------------------------------ tiện ích ------------------------------

def _clean_image(raw: bytes, max_size: tuple[int, int] = (1600, 1600)) -> bytes:
    """Kiểm tra là ảnh thật, xoay đúng chiều, thu nhỏ (mặc định ≤ 1600px), mã hóa lại JPEG (xóa EXIF/GPS)."""
    from PIL import Image, ImageOps, UnidentifiedImageError
    if len(raw) > MAX_IMAGE_BYTES:
        raise HTTPException(413, "Ảnh quá lớn")
    try:
        im = Image.open(io.BytesIO(raw))
        im = ImageOps.exif_transpose(im)
        im = im.convert("RGB")
    except (UnidentifiedImageError, OSError):
        raise HTTPException(400, "File không phải ảnh")
    im.thumbnail(max_size)
    out = io.BytesIO()
    im.save(out, format="JPEG", quality=85)
    return out.getvalue()


def _load(session_id: str) -> dict:
    sess = store.load(session_id)
    if not sess:
        raise HTTPException(404, "Không tìm thấy phiên học")
    return sess


def _turn_resp(out: dict) -> TurnResponse:
    o = out["owl"]
    return TurnResponse(owl=Owl(say=o["say"], mood=o.get("mood", "asking")), hint_level=out["hint_level"],
                        state=out["state"], stars_earned=out.get("stars_earned", 0),
                        ui_actions=out.get("ui_actions", []), fun_question=out.get("fun_question", ""))


def _new_session(device_id: str, child_id: str, nickname: str, grade: int, subject: str,
                 provider: Optional[str], tier: Optional[str], problems: list[dict]) -> tuple[str, dict]:
    sid = store.new_session_id()
    now = time.time()
    sess = {
        "id": sid, "device_id": device_id or "anon", "child_id": child_id or "default",
        "nickname": (nickname or "bạn").strip()[:20], "grade": grade, "subject": subject,
        "provider": provider, "tier": tier, "problems": problems, "problem": None,
        "state": "selecting", "hint_level": 0, "max_hint_level": 0, "stuck": 0, "turns": 0,
        "history": [], "stars": 0, "max_turns": settings.max_turns_per_problem,
        "created_at": now, "safety_flags": [],
    }
    return sid, sess


def _activate(sess: dict, problem: dict) -> str:
    sess["problem"] = problem
    sess["state"] = "confirming"
    return f"Cú đọc được bài rồi: {problem['text']} Đúng bài này không?"


# ------------------------------ endpoint chung ------------------------------

@app.get("/v1/health")
def health():
    return {"ok": True, "store": settings.store_backend,
            "providers": router.available(), "default_provider": settings.provider_for("TUTOR"),
            "configured_providers": [p for p in router.available() if router.configured(p)], "tiers": list(TIERS),
            "tts": tts.status()}


def _ai_error_info(e: BaseException) -> tuple[int, str]:
    """Mã lỗi HTTP + nội dung lỗi gốc (đi theo chuỗi __cause__) – để báo đúng tình huống."""
    status, parts, cur, seen = 0, [], e, 0
    while cur is not None and seen < 5:
        status = status or int(getattr(cur, "status_code", 0) or 0)
        parts += [type(cur).__name__, str(cur), str(getattr(cur, "body", "") or ""), str(getattr(cur, "message", "") or "")]
        cur, seen = cur.__cause__ or cur.__context__, seen + 1
    return status, " ".join(parts).lower()


def _friendly_ai_error(e: Exception, provider: str = "") -> str:
    """Lỗi khi thử khóa AI → câu dễ hiểu cho bố mẹ (không bao giờ chứa khóa)."""
    status, text = _ai_error_info(e)
    if any(k in text for k in ("insufficient_quota", "credit balance", "billing", "exceeded your current quota"))             or status == 402:
        return "Tài khoản AI chưa nạp tiền hoặc đã hết tiền. Vào trang của nhà cung cấp để nạp tiền nhé."
    if status in (401, 403) or any(k in text for k in ("invalid_api_key", "incorrect api key", "api key not valid",
                                                       "api_key_invalid", "authentication", "invalid x-api-key"))             or (status == 400 and provider == "gemini"):
        return "Khóa không đúng hoặc đã bị thu hồi. Kiểm tra lại (copy đủ cả chuỗi) nhé."
    if status == 429 or "rate" in text or "resource_exhausted" in text:
        return "Khóa đang bị giới hạn lượt dùng (gọi quá nhiều). Thử lại sau ít phút."
    if status == 404 or ("model" in text and "not" in text):
        return "Khóa chưa được dùng model này. Thử tạo khóa mới hoặc nâng cấp tài khoản."
    if status >= 500 or "overloaded" in text:
        return "Nhà cung cấp AI đang quá tải. Thử lại sau ít phút."
    if "timeout" in text or "connect" in text:
        return "Không kết nối được tới nhà cung cấp AI. Thử lại sau."
    return f"Khóa chưa dùng được ({type(e).__name__})."


@app.post("/v1/ai/check", dependencies=[Depends(require_app)])
def ai_check():
    """Bố mẹ bấm "Kiểm tra khóa": thử 1 câu rất ngắn với khóa gửi kèm (x-ai-provider, x-ai-key).
    Với ChatGPT: chọn model rẻ, đọc được ảnh mà khóa dùng được – app nhớ model này (x-ai-model)."""
    own = request_keys.current()
    if not own:
        raise HTTPException(400, "Thiếu khóa hoặc nhà cung cấp chưa hỗ trợ")
    try:
        provider = router.instance(own.provider)
        model = own.model
        if own.provider == "openai" and not model:
            model = router.DEFAULT_OPENAI_MODEL
            try:
                ids = {m.id for m in provider.client.models.list()}
                model = next((m for m in router.OPENAI_PREFERENCE if m in ids), model)
            except Exception:  # khóa giới hạn quyền liệt kê model – dùng mặc định
                pass
        if not model:
            model = settings.model_for("TUTOR", own.provider, None)
        for attempt in range(3):  # gói miễn phí hay quá tải tạm thời (503) → thử lại
            try:
                reply = provider.complete("Trả lời đúng một từ: OK", "Kiểm tra kết nối", model=model, role="TUTOR",
                                          max_tokens=64)
                break
            except Exception as e:
                status, _ = _ai_error_info(e)
                if attempt == 2 or not (status >= 500 or status == 0 and "không có câu trả lời" in str(e)):
                    raise
                time.sleep(1.5)
        return {"ok": True, "provider": own.provider, "model": model, "reply": (reply or "")[:20]}
    except Exception as e:  # không ghi log nội dung lỗi có thể chứa khóa
        log.info("ai_check thất bại: provider=%s mã=%s", own.provider, _ai_error_info(e)[0])
        return {"ok": False, "provider": own.provider, "error": _friendly_ai_error(e, own.provider)}


@app.post("/v1/device/register", response_model=DeviceRegistration, dependencies=[Depends(require_app)])
def register_device():
    """Gọi 1 lần khi cài app. parent_token chỉ dùng trong Góc phụ huynh (lưu trong secure storage)."""
    device_id, token = store.register_device()
    return DeviceRegistration(device_id=device_id, parent_token=token)


@app.post("/v1/session/start", response_model=StartResponse, dependencies=[Depends(require_app)])
def start(grade: int = Form(...), subject: str = Form("math"), child_nickname: str = Form("bạn"),
          question_text: str = Form(""), provider: Optional[str] = Form(None), tier: Optional[str] = Form(None),
          device_id: str = Form(""), child_id: str = Form(""), image: Optional[UploadFile] = File(None)):
    if not 1 <= grade <= 5:
        raise HTTPException(422, "grade phải từ 1 đến 5")
    subject = subject if subject in SUBJECTS else "math"
    # Phụ huynh chọn AI chưa có khóa trên máy chủ → dùng nhà cung cấp mặc định thay vì báo lỗi.
    provider = provider if router.configured(provider) else None
    tier = tier if tier in TIERS else None
    if device_id and store.count_sessions_today(device_id) >= settings.max_sessions_per_day:
        return JSONResponse(status_code=429, content={"detail": "Hôm nay bạn học nhiều lắm rồi! Mai mình học tiếp nhé."})
    if safety.classify_input(question_text):
        return StartResponse(readable=False, state="unreadable",
                             owl=Owl(say=safety.UNSAFE_LINE, mood="encouraging"))
    jpeg = _clean_image(image.file.read()) if image is not None else None
    if not jpeg and not question_text.strip():
        raise HTTPException(422, "Cần ảnh hoặc câu hỏi")
    try:
        result = solver.solve(jpeg, question_text, grade, subject, PROMPTS, provider, tier)
    except ProviderRefusal:
        return StartResponse(readable=False, state="unreadable",
                             owl=Owl(say="Cú chưa giúp được bài này. Bạn hỏi bố mẹ hoặc thầy cô nhé!", mood="encouraging"))
    except (ProviderError, ValueError) as e:
        log.error("solver lỗi: %s", e)
        raise HTTPException(503, "Cú đang bận, thử lại sau nhé")
    if not result.get("readable") or not result.get("problems"):
        say = ("Ảnh hơi mờ, Cú chưa đọc được. Mình chụp lại gần hơn và sáng hơn nhé!" if jpeg
               else "Cú chưa hiểu câu hỏi này. Bạn đọc lại rõ hơn, hoặc nhờ bố mẹ gõ giúp nhé!")
        return StartResponse(readable=False, state="unreadable", owl=Owl(say=say, mood="encouraging"))
    problems = result["problems"]
    sid, sess = _new_session(device_id, child_id, child_nickname, grade, subject, provider, tier, problems)
    briefs = [ProblemBrief(id=p["id"], text=p["text"]) for p in problems]
    if len(problems) == 1:
        say = _activate(sess, problems[0])
        store.save(sid, sess)
        return StartResponse(session_id=sid, readable=True, problem_display=problems[0]["text"], problems_found=1,
                             problems=briefs, subject=subject, mode=problems[0]["mode"],
                             owl=Owl(say=say, mood="asking"), state="confirming")
    store.save(sid, sess)
    return StartResponse(session_id=sid, readable=True, problems_found=len(problems), problems=briefs,
                         needs_selection=True, subject=subject, state="selecting",
                         owl=Owl(say=f"Trang này có {len(problems)} câu. Bạn muốn làm câu nào? Bạn chạm vào câu đó nhé!",
                                 mood="asking"))


@app.post("/v1/session/select", response_model=StartResponse, dependencies=[Depends(require_app)])
def select(body: SelectRequest):
    """FR-12: bạn nhỏ chạm chọn câu muốn làm."""
    sess = _load(body.session_id)
    prob = next((p for p in sess.get("problems", []) if p["id"] == body.problem_id), None)
    if not prob:
        raise HTTPException(404, "Không có câu này")
    # Đổi câu → làm lại từ đầu với câu mới
    sess.update(hint_level=0, max_hint_level=0, stuck=0, turns=0, history=[], tool_shown=False, stars=0)
    say = _activate(sess, prob)
    store.save(body.session_id, sess)
    return StartResponse(session_id=body.session_id, readable=True, problem_display=prob["text"],
                         problems_found=len(sess["problems"]),
                         problems=[ProblemBrief(id=p["id"], text=p["text"]) for p in sess["problems"]],
                         subject=sess["subject"], mode=prob["mode"], owl=Owl(say=say, mood="asking"), state="confirming")


@app.post("/v1/session/confirm", response_model=TurnResponse, dependencies=[Depends(require_app)])
def confirm(body: SessionRef):
    """FR-15: bạn nhỏ bấm "Đúng rồi" → Cú bắt đầu hỏi gợi mở (L0)."""
    sess = _load(body.session_id)
    if not sess.get("problem"):
        raise HTTPException(409, "Chưa chọn câu")
    out = tutor.opening(sess)
    store.save(body.session_id, sess)
    return _turn_resp(out)


@app.post("/v1/session/turn", response_model=TurnResponse, dependencies=[Depends(require_app)])
def turn(body: TurnRequest):
    sess = _load(body.session_id)
    if not sess.get("problem"):
        raise HTTPException(409, "Chưa chọn câu")
    if sess["state"] == "confirming":
        tutor.opening(sess)
    out = tutor.run_turn(sess, body.child_input, body.input_mode, PROMPTS)
    store.save(body.session_id, sess)
    return _turn_resp(out)


@app.post("/v1/session/scratch", response_model=TurnResponse, dependencies=[Depends(require_app)])
def scratch(session_id: str = Form(...), image: UploadFile = File(...)):
    """FR-23: "Cú xem giúp" bảng nháp."""
    sess = _load(session_id)
    if not sess.get("problem"):
        raise HTTPException(409, "Chưa chọn câu")
    # Tờ nháp cuộn được nên có thể rất dài: giữ chiều cao (≤ 6000px) để chữ không bị thu quá nhỏ.
    jpeg = _clean_image(image.file.read(), max_size=(1600, 6000))
    out = tutor.scratch_review(sess, jpeg, "image/jpeg", PROMPTS)
    store.save(session_id, sess)
    return _turn_resp(out)


@app.post("/v1/session/challenge", response_model=StartResponse, dependencies=[Depends(require_app)])
def challenge(body: SessionRef):
    """FR-30: Thử thách tương tự (khó hơn chút xíu) sau khi làm đúng."""
    old = _load(body.session_id)
    if not old.get("problem"):
        raise HTTPException(409, "Chưa có bài gốc")
    prob = solver.generate_challenge(old["problem"], old["grade"], PROMPTS, old.get("provider"), old.get("tier"))
    if not prob:
        raise HTTPException(503, "Cú chưa nghĩ ra thử thách, thử lại sau nhé")
    sid, sess = _new_session(old["device_id"], old["child_id"], old["nickname"], old["grade"], old["subject"],
                             old.get("provider"), old.get("tier"), [prob])
    sess["problem"] = prob
    out = tutor.opening(sess)
    store.save(sid, sess)
    return StartResponse(session_id=sid, readable=True, problem_display=prob["text"], problems_found=1,
                         problems=[ProblemBrief(id=1, text=prob["text"])], subject=sess["subject"], mode=prob["mode"],
                         owl=Owl(say="Thử thách mới đây! " + out["owl"]["say"], mood="asking"), state="tutoring")


@app.post("/v1/tts", dependencies=[Depends(require_app)])
def tts_say(req: TtsRequest) -> Response:
    """Giọng Cú tự nhiên (Piper vais1000) cho một câu → WAV. App lưu lại, lần sau phát ngay."""
    if not tts.available():
        raise HTTPException(503, "Máy chủ chưa có giọng tự nhiên")
    try:
        wav = tts.synth_wav(req.text.strip(), req.speed, req.pitch)
    except Exception as e:  # noqa: BLE001
        log.warning("TTS lỗi: %s", e)
        raise HTTPException(503, "Không tạo được giọng") from e
    return Response(wav, media_type="audio/wav", headers={"Cache-Control": "private, max-age=604800"})


@app.post("/v1/friend/chat", response_model=FriendResponse, dependencies=[Depends(require_app)])
def friend_chat(body: FriendRequest):
    """💛 Góc tâm sự: Cú lắng nghe như một người bạn (nhiều lớp an toàn – xem pipeline/friend.py).
    KHÔNG lưu nội dung; chỉ ghi số lượt, tâm trạng và loại cảnh báo theo ngày để bố mẹ biết khi cần quan tâm."""
    provider = body.provider if router.configured(body.provider) else None
    out = friend.chat(nickname=body.nickname, grade=body.grade, mood=body.mood, message=body.message,
                      history=[m.model_dump() for m in body.history], prompts=PROMPTS,
                      provider=provider, tier=body.tier)
    if body.device_id:
        sid = friend.day_session_id(body.device_id, body.child_id)
        now = time.time()
        sess = store.load(sid) or {"device_id": body.device_id, "child_id": body.child_id, "created_at": now,
                                   "subject": "wellbeing", "grade": body.grade, "state": "tam_su", "turns": 0,
                                   "problem": {"type": "tam_su", "text": "💬 Góc tâm sự"}, "moods": [],
                                   "safety_flags": []}
        sess["turns"] = int(sess.get("turns", 0)) + 1
        if body.mood and body.mood not in sess["moods"]:
            sess["moods"].append(body.mood)
        if out.get("flag"):
            sess["safety_flags"].append(out["flag"])
            log.warning("Góc tâm sự: cảnh báo %s (thiết bị %s…)", out["flag"], body.device_id[:6])
        store.save(sid, sess)
    return FriendResponse(say=out["say"], owl_mood=out["owl_mood"], suggest_breathing=out["suggest_breathing"],
                          crisis=out.get("crisis", ""), hotline=out.get("hotline", ""))


@app.get("/v1/mystery-box", response_model=MysteryBox, dependencies=[Depends(require_app)])
def mystery_box(grade: int = Query(1, ge=1, le=5), date: Optional[str] = None):
    """FR-42: một câu đố/câu hỏi khám phá mỗi ngày (cùng ngày → cùng câu)."""
    day = date or dt.date.today().isoformat()
    bank = MYSTERY["lop_1_2" if grade <= 2 else "lop_3_5"]
    idx = int(hashlib.sha256(f"{day}|{grade}".encode()).hexdigest(), 16) % len(bank)
    item = bank[idx]
    return MysteryBox(question=item["question"], subject=item["subject"], kind=item["kind"], date=day)


# ------------------------------ Góc phụ huynh ------------------------------

@app.get("/v1/parent/report", response_model=ParentReport, dependencies=[Depends(require_app)])
def parent_report(device_id: str, child_id: str, period: str = Query("day", pattern="^(day|week)$"),
                  x_parent_token: Optional[str] = Header(None)):
    """FR-60: thời gian học, số câu tự giải, dạng bài khó, câu "để dành hỏi thầy cô"."""
    _parent_ok(device_id, x_parent_token)
    now = time.time()
    if period == "day":
        start_of_day = dt.datetime.combine(dt.date.today(), dt.time()).timestamp()
        since = start_of_day
    else:
        since = now - 7 * 86400
    all_logs = store.problem_logs(device_id, child_id, since)
    friend_logs = [r for r in all_logs if r.get("problem_type") == "tam_su"]
    logs = [r for r in all_logs if r.get("problem_type") != "tam_su"]

    def minutes_of(r: dict) -> float:
        return min(30.0, max(1.0, (r["updated_at"] - r["started_at"]) / 60))

    by_type: dict[str, dict] = defaultdict(lambda: {"count": 0, "hint_sum": 0, "parked": 0})
    by_day: dict[str, dict] = defaultdict(lambda: {"minutes": 0.0, "problems": 0, "solved": 0})
    for r in logs:
        t = by_type[r["problem_type"] or "khac"]
        t["count"] += 1
        t["hint_sum"] += r["max_hint"]
        t["parked"] += 1 if r["outcome"] == "parked" else 0
        d = by_day[dt.date.fromtimestamp(r["started_at"]).isoformat()]
        d["minutes"] += minutes_of(r)
        d["problems"] += 1
        d["solved"] += 1 if r["outcome"] == "solved" else 0
    hard = sorted(({"type": k, "count": v["count"], "avg_hint": round(v["hint_sum"] / v["count"], 1),
                    "parked": v["parked"]} for k, v in by_type.items()),
                  key=lambda x: (x["parked"], x["avg_hint"]), reverse=True)

    def item(r: dict) -> ReportItem:
        return ReportItem(session_id=r["session_id"], started_at=r["started_at"], subject=r["subject"] or "",
                          problem_type=r["problem_type"] or "", problem_text=r["problem_text"] or "",
                          turns=r["turns"], max_hint=r["max_hint"], outcome=r["outcome"], stars=r["stars"])

    return ParentReport(
        period=period,
        minutes=int(round(sum(minutes_of(r) for r in logs))),
        problems_total=len(logs),
        solved_self=sum(1 for r in logs if r["outcome"] == "solved"),
        parked=sum(1 for r in logs if r["outcome"] == "parked"),
        stars=sum(r["stars"] for r in logs),
        hard_types=[h for h in hard if h["avg_hint"] >= 2 or h["parked"]][:5],
        parked_items=[item(r) for r in logs if r["outcome"] == "parked"][:20],
        recent=[item(r) for r in logs][:20],
        safety_alerts=sum(1 for r in logs if r["safety_flag"]),
        by_day=[{"date": k, "minutes": int(round(v["minutes"])), "problems": v["problems"], "solved": v["solved"]}
                for k, v in sorted(by_day.items())],
        friend_turns=sum(int(r.get("turns") or 0) for r in friend_logs),
        friend_days=len(friend_logs),
        friend_alerts=sorted({f for r in friend_logs for f in (r.get("safety_flag") or "").split(",") if f}),
    )


@app.get("/v1/parent/answer", response_model=ParentAnswer, dependencies=[Depends(require_app)])
def parent_answer(session_id: str, x_parent_token: Optional[str] = Header(None)):
    """FR-61: đáp án tham khảo – CHỈ trong Góc phụ huynh, cần parent token."""
    sess = _load(session_id)
    _parent_ok(sess["device_id"], x_parent_token)
    p = sess.get("problem") or (sess.get("problems") or [None])[0]
    if not p:
        raise HTTPException(404, "Không có bài")
    answer = "Bài viết – không có đáp án duy nhất" if p["mode"] == "open_ended" else p["answer"]
    return ParentAnswer(problem=p["text"], answer=answer, steps=p.get("steps", []), mode=p["mode"])


@app.delete("/v1/parent/child", dependencies=[Depends(require_app)])
def delete_child(device_id: str, child_id: str, x_parent_token: Optional[str] = Header(None)):
    """FR-64: xóa toàn bộ dữ liệu của bé trên server."""
    _parent_ok(device_id, x_parent_token)
    return {"deleted_sessions": store.delete_child(device_id, child_id)}


@app.delete("/v1/parent/device", dependencies=[Depends(require_app)])
def delete_device(device_id: str, x_parent_token: Optional[str] = Header(None)):
    _parent_ok(device_id, x_parent_token)
    return {"deleted_sessions": store.delete_child(device_id, None)}


# ------------------------------ giao diện web (mở bằng trình duyệt trên máy tính bảng) ------------------------------
# Gắn SAU mọi route /v1 để API luôn được ưu tiên. Chưa build web thì bỏ qua.
if Path(settings.web_dir, "index.html").is_file():
    app.mount("/", StaticFiles(directory=settings.web_dir, html=True), name="web")
    log.info("Phục vụ giao diện web từ %s", settings.web_dir)
