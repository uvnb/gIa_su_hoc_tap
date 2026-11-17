"""Vá thư mục web/ do `flutter create --platforms web .` sinh ra.

- index.html: lang="vi", tiêu đề "Cú Tò Mò", màu nền kem khi đang tải.
- manifest.json: tên app, màn ngang, toàn màn hình khi "Thêm vào màn hình chính" trên máy tính bảng.
Chạy lại nhiều lần vẫn an toàn.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

WEB = Path(__file__).resolve().parents[1] / "web"


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if not WEB.exists():
        print("✘ Chưa có thư mục web/. Chạy: flutter create --platforms web .")
        sys.exit(1)

    idx = WEB / "index.html"
    s = idx.read_text(encoding="utf-8")
    s = re.sub(r"<html[^>]*>", '<html lang="vi">', s, count=1)
    s = re.sub(r"<title>.*?</title>", "<title>Cú Tò Mò</title>", s, count=1, flags=re.S)
    s = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")', r"\1Cú Tò Mò\2", s)
    s = re.sub(r'(<meta name="description" content=")[^"]*(")',
               r"\1Gia sư AI cho học sinh tiểu học – Cú không bao giờ nói đáp án\2", s)
    if "background-color: #FFF8EC" not in s:
        s = s.replace("</head>", "  <style>html,body{background-color: #FFF8EC;}</style>\n</head>", 1)
    idx.write_text(s, encoding="utf-8")
    print("✔ web/index.html")

    man = WEB / "manifest.json"
    m = json.loads(man.read_text(encoding="utf-8"))
    m.update({
        "name": "Cú Tò Mò",
        "short_name": "Cú Tò Mò",
        "description": "Gia sư AI cho học sinh tiểu học",
        "display": "fullscreen",
        "orientation": "landscape",
        "background_color": "#FFF8EC",
        "theme_color": "#4FA3FF",
        "lang": "vi",
    })
    man.write_text(json.dumps(m, ensure_ascii=False, indent=2), encoding="utf-8")
    print("✔ web/manifest.json")


if __name__ == "__main__":
    main()
