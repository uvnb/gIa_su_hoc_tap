"""Giọng Cú tự nhiên tạo trên máy chủ: mô hình mã nguồn mở Piper "vi_VN-vais1000-medium" (MIT,
dữ liệu VAIS-1000 CC BY 4.0) chạy bằng sherpa-onnx (Apache-2.0).

Máy tính bảng của bé (chip Cortex-A53) tạo giọng này quá chậm (1 giây giọng mất ~3 giây), còn máy chủ chỉ
mất ~0,1 giây – nên app xin máy chủ đọc từng câu rồi lưu lại file WAV; mất mạng thì app tự tạo trên máy.

Mô hình (64 MB) không nằm trong git: khi triển khai, scripts/deploy_vercel.py chép từ app/assets/tts/vi
(tải bằng app/tool/fetch_tts_model.py) vào app/tts_model/.
"""
from __future__ import annotations

import logging
import os
import struct
import threading
from collections import OrderedDict
from pathlib import Path

log = logging.getLogger("cu.tts")

_HERE = Path(__file__).resolve().parent
_CANDIDATES = [
    Path(os.environ["TTS_MODEL_DIR"]) if os.environ.get("TTS_MODEL_DIR") else None,
    _HERE / "tts_model",
    _HERE.parent.parent / "app" / "assets" / "tts" / "vi",  # chạy từ kho mã trên máy tính
]

_lock = threading.Lock()
_engine = None
_failed = False
_cache: OrderedDict[tuple, bytes] = OrderedDict()
_CACHE_MAX = 300


def model_dir() -> Path | None:
    for d in _CANDIDATES:
        if d is not None and (d / "vi.onnx").exists() and (d / "tokens.txt").exists():
            return d
    return None


_preloaded = False


def _sherpa():
    """import sherpa_onnx. Trên Vercel, các thư viện .so đi kèm gói (libonnxruntime, libasound) bị bỏ khi
    đóng gói → scripts/deploy_vercel.py chép chúng vào app/tts_lib/, nạp trước ở đây (RTLD_GLOBAL)."""
    global _preloaded
    if not _preloaded:
        _preloaded = True
        lib = _HERE / "tts_lib"
        if lib.is_dir():
            import ctypes

            for pattern in ("libasound*", "libonnxruntime.so*"):
                for f in sorted(lib.glob(pattern)):
                    try:
                        ctypes.CDLL(str(f), mode=ctypes.RTLD_GLOBAL)
                    except OSError as e:
                        log.warning("Không nạp được %s: %s", f.name, e)
    import sherpa_onnx

    return sherpa_onnx


def available() -> bool:
    if _failed or model_dir() is None:
        return False
    try:
        _sherpa()
    except Exception:  # noqa: BLE001
        return False
    return True


def status() -> dict:
    """Tình trạng giọng tự nhiên (cho /v1/health) – không lộ đường dẫn máy chủ."""
    d = model_dir()
    try:
        _sherpa()
        lib = "ok"
    except Exception as e:  # noqa: BLE001
        lib = f"{type(e).__name__}: {e}"[:160]
    return {"model": d is not None, "lib": lib, "loaded": _engine is not None, "failed": _failed}


def _get_engine():
    global _engine, _failed
    if _engine is not None:
        return _engine
    d = model_dir()
    if d is None:
        raise RuntimeError("chưa có mô hình giọng")
    try:
        sherpa_onnx = _sherpa()
        cfg = sherpa_onnx.OfflineTtsConfig(
            model=sherpa_onnx.OfflineTtsModelConfig(
                vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                    model=str(d / "vi.onnx"),
                    lexicon="",
                    tokens=str(d / "tokens.txt"),
                    data_dir=str(d / "espeak-ng-data"),
                    noise_scale=0.6,
                    noise_scale_w=0.75,
                ),
                num_threads=max(1, min(4, os.cpu_count() or 1)),
                provider="cpu",
            ),
            max_num_sentences=1,
        )
        _engine = sherpa_onnx.OfflineTts(cfg)
        log.info("Đã nạp giọng Piper vais1000 từ %s", d)
        return _engine
    except Exception:
        _failed = True
        raise


def resample(samples, factor: float) -> list[float]:
    """"Đọc nhanh" các mẫu theo hệ số [factor] → giọng cao hơn (giống app)."""
    n_in = len(samples)
    if abs(factor - 1.0) < 0.01 or n_in == 0:
        return list(samples)
    n = int(n_in / factor)
    out = [0.0] * n
    for i in range(n):
        x = i * factor
        j = int(x)
        t = x - j
        a = samples[j]
        b = samples[j + 1] if j + 1 < n_in else a
        out[i] = a + (b - a) * t
    return out


def wav_bytes(samples, sample_rate: int, lead_ms: int = 60) -> bytes:
    """WAV PCM 16-bit mono; thêm một chút lặng ở đầu để loa không "nuốt" chữ đầu."""
    lead = sample_rate * lead_ms // 1000
    pcm = bytearray(lead * 2)
    pcm += struct.pack(f"<{len(samples)}h", *(max(-32768, min(32767, round(v * 32767))) for v in samples))
    header = struct.pack("<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(pcm), b"WAVE", b"fmt ", 16, 1, 1,
                         sample_rate, sample_rate * 2, 2, 16, b"data", len(pcm))
    return header + bytes(pcm)


def synth_wav(text: str, speed: float = 1.0, pitch: float = 1.0) -> bytes:
    key = (text, round(speed, 2), round(pitch, 2))
    with _lock:
        hit = _cache.get(key)
        if hit is not None:
            _cache.move_to_end(key)
            return hit
        audio = _get_engine().generate(text, sid=0, speed=speed / pitch)
    wav = wav_bytes(resample(audio.samples, pitch), audio.sample_rate)
    with _lock:
        _cache[key] = wav
        while len(_cache) > _CACHE_MAX:
            _cache.popitem(last=False)
    return wav
