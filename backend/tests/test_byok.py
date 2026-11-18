"""Khóa AI riêng của phụ huynh (nhập trong app): chỉ dùng trong yêu cầu, không lưu, có kiểm tra khóa."""
from fastapi.testclient import TestClient

from app import main
from app.providers import request_keys, router
from app.providers.base import LLMProvider

SECRET = {"x-app-secret": main.settings.app_shared_secret.split(",")[0]}


class FakeProvider(LLMProvider):
    name = "fake"
    supports_vision = True

    def __init__(self, api_key=None):
        self.api_key = api_key

    def complete(self, system, user_text, *, model, role="TUTOR", **kw):
        if self.api_key == "bad-key-1234567":
            raise RuntimeError("Error code: 401 - invalid_api_key")
        return "OK"


def test_khoa_chi_song_trong_yeu_cau(monkeypatch):
    monkeypatch.setitem(router.REGISTRY, "openai", FakeProvider)
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    router.reset()
    assert not router.configured("openai")
    tok = request_keys.set_from_headers("openai", "sk-test-1234567890", "gpt-4o-mini")
    try:
        assert router.configured("openai")
        p, model = router.get("TUTOR", "openai")
        assert isinstance(p, FakeProvider) and p.api_key == "sk-test-1234567890"
        assert model == "gpt-4o-mini"
    finally:
        request_keys.reset(tok)
    assert request_keys.current() is None
    assert not router.configured("openai")


def test_phien_chon_ai_rieng_nhung_luot_sau_khong_kem_khoa_thi_dung_mac_dinh(monkeypatch):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    router.reset()
    p, _ = router.get("TUTOR", "openai")  # không có khóa → về AI mặc định của máy chủ (mock trong test)
    assert p.name == "mock"


def test_kiem_tra_khoa_dung_va_sai(monkeypatch):
    monkeypatch.setitem(router.REGISTRY, "gemini", FakeProvider)
    router.reset()
    c = TestClient(main.app)
    ok = c.post("/v1/ai/check", headers={**SECRET, "x-ai-provider": "gemini", "x-ai-key": "good-key-1234567"}).json()
    assert ok["ok"] is True and ok["provider"] == "gemini"
    bad = c.post("/v1/ai/check", headers={**SECRET, "x-ai-provider": "gemini", "x-ai-key": "bad-key-1234567"}).json()
    assert bad["ok"] is False and "Khóa không đúng" in bad["error"]
    assert "bad-key" not in str(bad)  # không bao giờ trả lại khóa
    assert c.post("/v1/ai/check", headers=SECRET).status_code == 400
    assert c.post("/v1/ai/check", headers={"x-ai-provider": "gemini", "x-ai-key": "good-key-1234567"}).status_code == 401


def test_header_la_bi_bo_qua():
    tok = request_keys.set_from_headers("hacker", "x" * 50, "")
    try:
        assert request_keys.current() is None
    finally:
        request_keys.reset(tok)
    tok = request_keys.set_from_headers("openai", "short", "")
    try:
        assert request_keys.current() is None
    finally:
        request_keys.reset(tok)
