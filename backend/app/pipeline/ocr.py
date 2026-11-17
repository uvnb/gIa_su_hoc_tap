"""OCR tiếng Việt chạy NGAY TRÊN MÁY CHỦ (EasyOCR) – miễn phí, không cần khóa API.

Dùng khi AI đang chọn không tự đọc được ảnh (chế độ giả lập, DeepSeek…): ảnh bài tập → văn bản → AI giải.
Ảnh không bị lưu lại; chỉ xử lý trong bộ nhớ.
"""
from __future__ import annotations

import io
import logging
import re
import statistics
import threading

log = logging.getLogger("cutomo.ocr")

_reader = None
_lock = threading.Lock()
_MARKER = re.compile(r"^\s*((bài|câu|bai|cau)\s*\d+|\d+\s*[.)]|[a-dA-D]\s*[.)])", re.IGNORECASE)


def available() -> bool:
    try:
        import easyocr  # noqa: F401
        return True
    except Exception:
        return False


def _get_reader():
    global _reader
    with _lock:
        if _reader is None:
            import easyocr
            log.info("Đang nạp mô hình OCR tiếng Việt (lần đầu tải ~100MB)…")
            _reader = easyocr.Reader(["vi", "en"], gpu=False, verbose=False)
        return _reader


def warm_up() -> None:
    """Nạp sẵn mô hình khi khởi động máy chủ để bé chụp bài lần đầu không phải chờ lâu."""
    if available():
        try:
            _get_reader()
        except Exception as e:  # pragma: no cover
            log.warning("OCR chưa sẵn sàng: %s", e)


def _group_lines(items: list[tuple[float, float, float, str]]) -> list[str]:
    """items: (y_giữa, x_trái, chiều_cao, chữ) → các dòng theo thứ tự đọc."""
    if not items:
        return []
    h = statistics.median(i[2] for i in items) or 10
    items.sort(key=lambda i: (i[0], i[1]))
    lines: list[list[tuple[float, float, float, str]]] = []
    for it in items:
        if lines and abs(lines[-1][0][0] - it[0]) <= h * 0.6:
            lines[-1].append(it)
        else:
            lines.append([it])
    return [" ".join(t for _, _, _, t in sorted(line, key=lambda i: i[1])) for line in lines]


def _join_problems(lines: list[str]) -> str:
    """Nối các dòng của cùng một bài; chỉ xuống dòng khi gặp "Bài 1", "Câu 2", "1.", "a)"…"""
    out: list[str] = []
    for ln in lines:
        ln = re.sub(r"\s+", " ", ln).strip()
        if not ln:
            continue
        if out and not _MARKER.match(ln):
            out[-1] += " " + ln
        else:
            out.append(ln)
    return "\n".join(out)


def image_to_text(image: bytes, min_conf: float = 0.25) -> str:
    """Trả về đề bài dạng chữ ('' nếu không đọc được)."""
    import numpy as np
    from PIL import Image, ImageOps

    im = ImageOps.exif_transpose(Image.open(io.BytesIO(image))).convert("RGB")
    # Ảnh nhỏ → phóng to cho chữ rõ hơn; ảnh quá lớn → thu nhỏ cho nhanh.
    longest = max(im.size)
    if longest < 1200:
        im = im.resize((im.width * 1600 // longest, im.height * 1600 // longest))
    elif longest > 2000:
        im.thumbnail((2000, 2000))
    results = _get_reader().readtext(np.array(im), detail=1, paragraph=False)
    items = []
    for box, text, conf in results:
        if conf < min_conf or not str(text).strip():
            continue
        ys = [p[1] for p in box]
        xs = [p[0] for p in box]
        items.append(((min(ys) + max(ys)) / 2, min(xs), max(ys) - min(ys), str(text)))
    text = _join_problems(_group_lines(items))
    log.info("OCR đọc được %d ký tự", len(text))
    return text
