"""OCR tiếng Việt: ảnh chụp bài → đúng đề bài (không còn hiện "bài mẫu")."""
import io

import pytest
from PIL import Image, ImageDraw, ImageFont

from app.config import settings
from app.pipeline import ocr
from app.providers import router

from .conftest import HEADERS

PROBLEM = "Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?"


def test_join_problems_keeps_one_problem_per_marker():
    lines = ["Bài 1: Lan có 7 cái kẹo, mẹ cho", "thêm 5 cái. Hỏi Lan có tất cả", "bao nhiêu cái kẹo?",
             "Bài 2: 9 - 2 = ?"]
    assert ocr._join_problems(lines) == (
        "Bài 1: Lan có 7 cái kẹo, mẹ cho thêm 5 cái. Hỏi Lan có tất cả bao nhiêu cái kẹo?\nBài 2: 9 - 2 = ?")


def test_group_lines_reading_order():
    items = [(52, 300, 20, "thế giới"), (50, 10, 20, "Xin chào"), (100, 10, 20, "Dòng hai")]
    assert ocr._group_lines(items) == ["Xin chào thế giới", "Dòng hai"]


def test_unconfigured_compat_providers():
    for name in ("deepseek", "gemini", "openrouter"):
        assert name in router.available()


def _render(text_lines: list[str]) -> bytes:
    try:
        font = ImageFont.truetype("arial.ttf", 44)
    except OSError:
        pytest.skip("không có font Arial để vẽ chữ tiếng Việt")
    im = Image.new("RGB", (1600, 140 + 70 * len(text_lines)), "white")
    d = ImageDraw.Draw(im)
    for i, ln in enumerate(text_lines):
        d.text((60, 60 + 70 * i), ln, font=font, fill="black")
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=92)
    return buf.getvalue()


needs_ocr = pytest.mark.skipif(not ocr.available(), reason="chưa cài easyocr")


@needs_ocr
def test_ocr_reads_vietnamese_problem():
    jpeg = _render(["Lan có 7 cái kẹo, mẹ cho thêm 5 cái.", "Hỏi Lan có tất cả bao nhiêu cái kẹo?"])
    text = ocr.image_to_text(jpeg)
    low = text.lower()
    assert "7" in text and "5" in text
    assert "kẹo" in low or "keo" in low
    assert "\n" not in text  # hai dòng của cùng một bài được nối lại


@needs_ocr
def test_photo_start_shows_the_real_problem(client, monkeypatch):
    """Chụp bài → Cú hiện ĐÚNG đề trong ảnh và giải được (giả lập), không còn bài mẫu."""
    monkeypatch.setattr(settings, "ocr_mode", "auto")
    jpeg = _render(["Bình có 8 viên bi, Bình cho bạn 3 viên.", "Hỏi Bình còn lại bao nhiêu viên bi?"])
    r = client.post("/v1/session/start", data={"grade": "2", "subject": "math"},
                    files={"image": ("q.jpg", jpeg, "image/jpeg")}, headers=HEADERS)
    body = r.json()
    assert body["readable"] is True, body
    assert "8" in body["problem_display"] and "3" in body["problem_display"]
    assert "Lan" not in body["problem_display"]
