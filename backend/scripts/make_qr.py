"""Tạo ảnh mã QR để máy tính bảng quét là mở Cú Tò Mò.

    python scripts/make_qr.py http://192.168.0.100:8090 ../dist/ma-qr-cu-to-mo.png
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont

INK = (35, 48, 90)
CREAM = (255, 248, 236)
ORANGE = (255, 138, 61)


def _font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    for name in (("arialbd.ttf" if bold else "arial.ttf"), "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def make(url: str, out: Path) -> None:
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=14, border=2)
    qr.add_data(url)
    qr.make(fit=True)
    code = qr.make_image(fill_color=INK, back_color="white").convert("RGB")

    w = max(code.width + 120, 760)
    h = code.height + 330
    card = Image.new("RGB", (w, h), CREAM)
    d = ImageDraw.Draw(card)
    title = "🦉 Cú Tò Mò".replace("🦉 ", "")  # font hệ thống không vẽ được emoji
    d.text((w // 2, 60), title, font=_font(64, True), fill=INK, anchor="mm")
    d.text((w // 2, 120), "Quét bằng camera hoặc Chrome trên máy tính bảng", font=_font(28), fill=INK, anchor="mm")
    card.paste(code, ((w - code.width) // 2, 160))
    y = 160 + code.height + 40
    d.text((w // 2, y), url, font=_font(34, True), fill=ORANGE, anchor="mm")
    d.text((w // 2, y + 50), "Máy tính phải bật · tablet dùng cùng Wi-Fi", font=_font(26), fill=INK, anchor="mm")
    d.text((w // 2, y + 90), "Lần đầu: bật tùy chọn Chrome (xem README) để dùng camera, micro",
           font=_font(22), fill=INK, anchor="mm")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp.png")
    card.save(tmp)
    try:
        os.replace(tmp, out)
    except OSError:
        # Ảnh cũ đang mở trong trình xem ảnh → Windows khóa file; giữ bản mới bên cạnh.
        alt = out.with_name(out.stem + "-moi.png")
        os.replace(tmp, alt)
        print(f"(Ảnh cũ đang mở nên lưu bản mới ở: {alt})")


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    make(sys.argv[1], Path(sys.argv[2]))
    print(f"Đã tạo mã QR: {Path(sys.argv[2]).resolve()}")
