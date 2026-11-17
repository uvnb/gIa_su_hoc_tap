"""Hợp đồng API (mục 9.3) + Góc phụ huynh + an toàn dữ liệu."""
import io

from PIL import Image

from .conftest import HEADERS, say, start_and_confirm, start_text

FORBIDDEN_KEYS = {"answer", "answer_variants", "steps", "solution", "common_mistakes", "key_numbers"}


def _keys(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from _keys(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _keys(v)


def _jpeg(color=(255, 255, 255)) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (640, 480), color).save(buf, format="JPEG")
    return buf.getvalue()


def test_auth_required(client):
    r = client.post("/v1/session/start", data={"grade": "1", "question_text": "1 + 1"})
    assert r.status_code == 401


def test_start_never_returns_answer(client):
    s = start_text(client, "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?")
    assert not FORBIDDEN_KEYS & set(_keys(s))
    assert s["readable"] and s["state"] == "confirming" and s["problems_found"] == 1
    assert "Đúng bài này không" in s["owl"]["say"]


def test_image_start_with_mock_demo_problem(client):
    r = client.post("/v1/session/start", data={"grade": "1", "subject": "math"},
                    files={"image": ("q.jpg", _jpeg(), "image/jpeg")}, headers=HEADERS)
    assert r.status_code == 200
    assert r.json()["readable"] is True


def test_non_image_rejected(client):
    r = client.post("/v1/session/start", data={"grade": "1"}, files={"image": ("q.jpg", b"not an image", "image/jpeg")},
                    headers=HEADERS)
    assert r.status_code == 400


def test_unreadable(client):
    s = start_text(client, "....")
    assert s["readable"] is False and s["session_id"] is None
    assert "chụp lại" in s["owl"]["say"]


def test_multiple_problems_select_flow(client):
    s = start_text(client, "Bài 1: 3 + 4 = ?\nBài 2: 9 - 2 = ?")
    assert s["needs_selection"] and s["problems_found"] == 2 and s["state"] == "selecting"
    r = client.post("/v1/session/select", json={"session_id": s["session_id"], "problem_id": 2}, headers=HEADERS)
    assert r.status_code == 200
    body = r.json()
    assert "9 - 2" in body["problem_display"]
    assert not FORBIDDEN_KEYS & set(_keys(body))
    c = client.post("/v1/session/confirm", json={"session_id": s["session_id"]}, headers=HEADERS).json()
    assert c["state"] == "tutoring"
    assert say(client, s["session_id"], "7")["state"] == "solved"


def test_all_turn_responses_have_no_secret_keys(client):
    sid, _, _ = start_and_confirm(client, "Có 15 quả cam, ăn mất 6 quả. Hỏi còn lại bao nhiêu quả?")
    for t in ["không biết", "khó quá", "10", "9"]:
        r = say(client, sid, t)
        assert not FORBIDDEN_KEYS & set(_keys(r))


def test_scratch_review(client):
    sid, _, _ = start_and_confirm(client, "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?")
    r = client.post("/v1/session/scratch", data={"session_id": sid},
                    files={"image": ("nhap.jpg", _jpeg(), "image/jpeg")}, headers=HEADERS)
    assert r.status_code == 200
    assert r.json()["owl"]["say"]


def test_challenge_creates_new_session(client):
    sid, _, _ = start_and_confirm(client, "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?")
    say(client, sid, "12")
    r = client.post("/v1/session/challenge", json={"session_id": sid}, headers=HEADERS)
    assert r.status_code == 200
    body = r.json()
    assert body["session_id"] != sid and body["state"] == "tutoring"
    assert not FORBIDDEN_KEYS & set(_keys(body))
    assert say(client, body["session_id"], "18")["state"] == "solved"  # mock: 10 + 8


def test_mystery_box_is_stable_per_day(client):
    a = client.get("/v1/mystery-box?grade=2&date=2026-11-17", headers=HEADERS).json()
    b = client.get("/v1/mystery-box?grade=2&date=2026-11-17", headers=HEADERS).json()
    assert a == b and a["question"]


def test_parent_flow_report_answer_delete(client):
    reg = client.post("/v1/device/register", headers=HEADERS).json()
    dev, tok = reg["device_id"], reg["parent_token"]
    sid, _, _ = start_and_confirm(client, "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?",
                                  device_id=dev, child_id="c1")
    say(client, sid, "12")
    sid2, _, _ = start_and_confirm(client, "Có 15 quả cam, ăn mất 6 quả. Hỏi còn lại bao nhiêu quả?",
                                   device_id=dev, child_id="c1")
    for _ in range(12):
        say(client, sid2, "không biết")

    # Không có token → 403
    assert client.get(f"/v1/parent/report?device_id={dev}&child_id=c1", headers=HEADERS).status_code == 403
    assert client.get(f"/v1/parent/answer?session_id={sid}", headers=HEADERS).status_code == 403
    ph = dict(HEADERS, **{"x-parent-token": tok})
    rep = client.get(f"/v1/parent/report?device_id={dev}&child_id=c1&period=week", headers=ph).json()
    assert rep["problems_total"] == 2 and rep["solved_self"] == 1 and rep["parked"] == 1
    assert rep["parked_items"][0]["session_id"] == sid2
    ans = client.get(f"/v1/parent/answer?session_id={sid2}", headers=ph).json()
    assert ans["answer"] == "9"
    # Token của thiết bị khác không xem được
    other = client.post("/v1/device/register", headers=HEADERS).json()
    bad = dict(HEADERS, **{"x-parent-token": other["parent_token"]})
    assert client.get(f"/v1/parent/answer?session_id={sid2}", headers=bad).status_code == 403
    # Xóa dữ liệu bé (FR-64)
    d = client.delete(f"/v1/parent/child?device_id={dev}&child_id=c1", headers=ph).json()
    assert d["deleted_sessions"] == 2
    rep = client.get(f"/v1/parent/report?device_id={dev}&child_id=c1&period=week", headers=ph).json()
    assert rep["problems_total"] == 0


def test_health(client):
    assert client.get("/v1/health").json()["ok"] is True


def test_cors_allows_localhost_web_build_only(client):
    pre = {"Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "x-app-secret"}
    ok = client.options("/v1/session/turn", headers={"Origin": "http://localhost:5050", **pre})
    assert ok.headers.get("access-control-allow-origin") == "http://localhost:5050"
    bad = client.options("/v1/session/turn", headers={"Origin": "https://evil.example.com", **pre})
    assert "access-control-allow-origin" not in bad.headers
