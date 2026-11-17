import os
import sys
from pathlib import Path

# Cấu hình test: luôn dùng provider giả lập, không gọi API thật, không tốn tiền.
os.environ["DEFAULT_PROVIDER"] = "mock"
for role in ("SOLVER", "TUTOR", "CHECKER", "GUARD"):
    os.environ[f"{role}_PROVIDER"] = "mock"
os.environ["APP_SHARED_SECRET"] = "test-secret"
os.environ["OCR_MODE"] = "off"  # test nhanh, không nạp mô hình OCR (test riêng ở test_ocr.py)
os.environ.pop("MOCK_TUTOR_LEAK", None)

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app import store  # noqa: E402
from app.config import settings  # noqa: E402
from app.providers import router  # noqa: E402

HEADERS = {"x-app-secret": "test-secret"}


@pytest.fixture()
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "db_path", str(tmp_path / "test.sqlite3"))
    monkeypatch.setattr(settings, "app_shared_secret", "test-secret")
    store.reset_for_tests()
    router.reset()
    from app.main import app
    with TestClient(app) as c:
        yield c
    store.reset_for_tests()


@pytest.fixture()
def mock_provider():
    return router.instance("mock")


def start_text(client, text, grade=2, subject="math", **extra):
    data = {"grade": str(grade), "subject": subject, "child_nickname": "Bông", "question_text": text}
    data.update(extra)
    r = client.post("/v1/session/start", data=data, headers=HEADERS)
    assert r.status_code == 200, r.text
    return r.json()


def start_and_confirm(client, text, **kw):
    s = start_text(client, text, **kw)
    sid = s["session_id"]
    r = client.post("/v1/session/confirm", json={"session_id": sid}, headers=HEADERS)
    assert r.status_code == 200, r.text
    return sid, s, r.json()


def say(client, sid, text, mode="voice"):
    r = client.post("/v1/session/turn", json={"session_id": sid, "child_input": text, "input_mode": mode},
                    headers=HEADERS)
    assert r.status_code == 200, r.text
    return r.json()
