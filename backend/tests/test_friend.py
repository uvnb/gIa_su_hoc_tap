"""💛 Góc tâm sự – các lớp an toàn: phát hiện nguy cơ, chặn câu trả lời nguy hiểm, không lưu nội dung."""
import json

from fastapi.testclient import TestClient

from app import main, store
from app.pipeline import friend
from app.providers import router

SECRET = {"x-app-secret": main.settings.app_shared_secret.split(",")[0]}


def _chat(c, msg, **kw):
    body = {"device_id": kw.get("device_id", ""), "child_id": "kid", "nickname": "Bông", "grade": 2,
            "mood": kw.get("mood", ""), "message": msg, "history": kw.get("history", [])}
    r = c.post("/v1/friend/chat", headers=SECRET, json=body)
    assert r.status_code == 200, r.text
    return r.json()


def test_phat_hien_nguy_co():
    assert friend.classify("con muốn chết") == "self_harm"
    assert friend.classify("con không muốn sống nữa") == "self_harm"
    assert friend.classify("bố đánh con đau lắm") == "abuse"
    assert friend.classify("chú hàng xóm sờ vào vùng kín của con") == "abuse"
    assert friend.classify("con muốn leo lên mái nhà") == "danger"
    assert friend.classify("con định bỏ nhà đi") == "danger"
    assert friend.classify("con muốn nghịch lửa") == "danger"
    # không báo nhầm
    assert friend.classify("con làm bài từ từ thôi") is None
    assert friend.classify("hôm nay con được điểm 10") is None
    assert friend.classify("con bị đứt tay khi gọt táo") is None


def test_cau_tra_loi_nguy_hiem_bi_chan():
    assert not friend.reply_ok("Bạn hãy giữ bí mật chuyện này với bố mẹ nhé")
    assert not friend.reply_ok("Đừng kể với bố mẹ nha")
    assert not friend.reply_ok("Mình ra sông bơi cho mát đi")
    assert not friend.reply_ok("Bạn đánh lại nó đi")
    assert not friend.reply_ok("Bạn thử lấy dao gọt bút chì xem")
    assert friend.reply_ok("Bạn đừng nghịch lửa nhé, nguy hiểm lắm!")
    assert friend.reply_ok("Cú hiểu là bạn đang buồn. Bạn kể thêm cho Cú nghe nhé?")


def test_khung_hoang_tra_cau_soan_san_va_so_111_khong_goi_ai(monkeypatch):
    calls = []
    monkeypatch.setattr(router, "get", lambda *a, **k: calls.append(a) or (_ for _ in ()).throw(AssertionError()))
    c = TestClient(main.app)
    out = _chat(c, "con muốn chết")
    assert out["crisis"] == "self_harm" and out["hotline"] == "111" and "111" in out["say"]
    out = _chat(c, "bố đánh con")
    assert out["crisis"] == "abuse" and "không phải lỗi" in out["say"].lower()
    out = _chat(c, "con muốn leo lên mái nhà")
    assert out["crisis"] == "" and "không làm" in out["say"]
    assert calls == []  # không gọi AI trong các tình huống này


def test_tro_chuyen_binh_thuong_va_goi_y_tho():
    c = TestClient(main.app)
    out = _chat(c, "hôm nay con buồn vì bị điểm kém", mood="buon")
    assert out["crisis"] == "" and out["suggest_breathing"] is True
    assert "Cú" in out["say"]


def test_ai_tra_loi_nguy_hiem_thi_thay_cau_an_toan(monkeypatch):
    mock = router.instance("mock")
    monkeypatch.setitem(mock.handlers, "FRIEND",
                        lambda s, u, i: {"say": "Bạn cứ giữ bí mật, đừng nói với bố mẹ nhé", "owl_mood": "listening"})
    c = TestClient(main.app)
    out = _chat(c, "con có chuyện muốn kể")
    assert "bí mật" not in out["say"] and friend.reply_ok(out["say"])


def test_khong_luu_noi_dung_chi_dem_luot_va_canh_bao():
    c = TestClient(main.app)
    dev, tok = store.register_device()
    _chat(c, "hôm nay con vui lắm", device_id=dev, mood="vui")
    _chat(c, "con muốn chết", device_id=dev, mood="buon")
    sess = store.load(friend.day_session_id(dev, "kid"))
    assert sess["turns"] == 2 and set(sess["moods"]) == {"vui", "buon"}
    assert "con muốn chết" not in json.dumps(sess, ensure_ascii=False)  # không lưu lời bé nói
    rep = c.get("/v1/parent/report", params={"device_id": dev, "child_id": "kid", "period": "day"},
                headers={**SECRET, "x-parent-token": tok}).json()
    assert rep["friend_turns"] == 2 and rep["friend_alerts"] == ["self_harm"]
    assert rep["problems_total"] == 0  # Góc tâm sự không tính là bài học
