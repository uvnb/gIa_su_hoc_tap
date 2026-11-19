"""Giọng Cú tự nhiên trên máy chủ (/v1/tts)."""
import struct

from fastapi.testclient import TestClient

from app import tts
from app.main import app
from app.config import settings


def _hdr():
    return {"x-app-secret": settings.app_shared_secret.split(",")[0].strip()}


def test_wav_header_and_length():
    wav = tts.wav_bytes([0.0, 0.5, -0.5, 1.0, -1.0], 22050, lead_ms=0)
    assert wav[:4] == b"RIFF" and wav[8:12] == b"WAVE" and wav[36:40] == b"data"
    assert struct.unpack("<I", wav[40:44])[0] == 10
    assert struct.unpack("<5h", wav[44:])[3] == 32767


def test_resample_shortens_and_raises_pitch():
    s = [float(i % 10) for i in range(1000)]
    assert len(tts.resample(s, 1.1)) == int(1000 / 1.1)
    assert tts.resample(s, 1.0) == s


def test_endpoint_requires_secret_and_validates():
    c = TestClient(app)
    assert c.post("/v1/tts", json={"text": "xin chào"}).status_code in (401, 403)
    assert c.post("/v1/tts", json={"text": ""}, headers=_hdr()).status_code == 422
    assert c.post("/v1/tts", json={"text": "a", "speed": 9}, headers=_hdr()).status_code == 422


def test_endpoint_returns_wav_or_503(monkeypatch):
    c = TestClient(app)
    monkeypatch.setattr(tts, "available", lambda: True)
    monkeypatch.setattr(tts, "synth_wav", lambda text, speed, pitch: tts.wav_bytes([0.1] * 100, 22050))
    r = c.post("/v1/tts", json={"text": "Xin chào bạn nhỏ.", "speed": 0.9, "pitch": 1.1}, headers=_hdr())
    assert r.status_code == 200 and r.headers["content-type"] == "audio/wav" and r.content[:4] == b"RIFF"
    monkeypatch.setattr(tts, "available", lambda: False)
    assert c.post("/v1/tts", json={"text": "Xin chào."}, headers=_hdr()).status_code == 503
