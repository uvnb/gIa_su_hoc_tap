"""Tải giọng Việt tự nhiên (mã nguồn mở) vào app/assets/tts/vi/ để nhúng thẳng vào app.

Mô hình: Piper "vi_VN-vais1000-medium" (bản đóng gói của sherpa-onnx).
  - Piper: https://github.com/rhasspy/piper (MIT)
  - sherpa-onnx: https://github.com/k2-fsa/sherpa-onnx (Apache-2.0)
  - Dữ liệu giọng VAIS-1000 (CC BY 4.0): https://ieee-dataport.org/documents/vais-1000-vietnamese-speech-synthesis-corpus

Chỉ giữ phần espeak-ng-data cần cho tiếng Việt (bỏ ~20 MB dữ liệu các ngôn ngữ khác).

  python tool/fetch_tts_model.py               # tải từ GitHub (dùng trong CI)
  python tool/fetch_tts_model.py --from DIR    # chép từ thư mục mô hình đã giải nén sẵn
"""
from __future__ import annotations

import argparse
import shutil
import tarfile
import tempfile
import urllib.request
from pathlib import Path

URL = ("https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/"
       "vits-piper-vi_VN-vais1000-medium.tar.bz2")
APP = Path(__file__).resolve().parent.parent
OUT = APP / "assets" / "tts" / "vi"
ESPEAK_KEEP = ["intonations", "phondata", "phondata-manifest", "phonindex", "phontab", "vi_dict",
               "lang/aav/vi", "lang/aav/vi-VN-x-central", "lang/aav/vi-VN-x-south",
               # từ tiếng Anh xen trong câu (OK, Hello…) – espeak cần từ điển tiếng Anh nhỏ này
               "en_dict", "lang/gmw/en"]


def copy_model(src: Path) -> None:
    onnx = next((p for p in src.glob("*.onnx")), None)
    if onnx is None:
        raise SystemExit(f"Không thấy file .onnx trong {src}")
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "espeak-ng-data" / "lang" / "aav").mkdir(parents=True)
    (OUT / "espeak-ng-data" / "lang" / "gmw").mkdir(parents=True)
    shutil.copy2(onnx, OUT / "vi.onnx")
    shutil.copy2(src / "tokens.txt", OUT / "tokens.txt")
    for rel in ESPEAK_KEEP:
        shutil.copy2(src / "espeak-ng-data" / rel, OUT / "espeak-ng-data" / rel)
    total = sum(p.stat().st_size for p in OUT.rglob("*") if p.is_file())
    print(f"Đã chép giọng Việt vào {OUT} ({total / 1e6:.1f} MB)")


def download() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        tar = Path(tmp) / "model.tar.bz2"
        print(f"Đang tải {URL} …")
        for attempt in range(4):
            try:
                urllib.request.urlretrieve(URL, tar)
                break
            except OSError as e:
                print(f"  lỗi tải ({e}), thử lại…")
                if attempt == 3:
                    raise
        with tarfile.open(tar, "r:bz2") as t:
            t.extractall(tmp, filter="data")
        copy_model(Path(tmp) / "vits-piper-vi_VN-vais1000-medium")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--from", dest="src", help="thư mục mô hình đã giải nén")
    a = ap.parse_args()
    if (OUT / "vi.onnx").exists() and not a.src:
        print("Giọng Việt đã có sẵn – bỏ qua.")
        return
    if a.src:
        copy_model(Path(a.src))
    else:
        download()


if __name__ == "__main__":
    main()
