"""Vá thư mục android/ do `flutter create` sinh ra cho đúng yêu cầu spec (mục 14.1).

Chạy SAU khi đã tạo khung Android:
    cd app
    flutter create --org vn.dmtlab --project-name cu_to_mo --platforms android .
    python tool/patch_android.py

Việc làm:
  1. minSdk = 30 (Android 11 – Masstel Tab 10 Edu bản cũ).
  2. AndroidManifest: quyền INTERNET, CAMERA, RECORD_AUDIO + <queries> cho nhận dạng giọng nói và TTS,
     tên app "Cú Tò Mò".
  3. Bản DEBUG cho phép HTTP (cleartext) để thử với backend trong mạng LAN; bản release chỉ HTTPS.
Script chạy lại nhiều lần vẫn an toàn (idempotent).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
]
QUERIES = """    <queries>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
"""


def patch_gradle() -> None:
    for name in ("build.gradle.kts", "build.gradle"):
        f = ANDROID / "app" / name
        if not f.exists():
            continue
        s = f.read_text(encoding="utf-8")
        new = re.sub(r"minSdk\s*=\s*[\w.]+", "minSdk = 30", s)              # Kotlin DSL / AGP mới
        new = re.sub(r"minSdkVersion\s+[\w.]+", "minSdkVersion 30", new)   # Groovy cũ
        if new != s:
            f.write_text(new, encoding="utf-8")
            print(f"✔ {f.relative_to(ROOT)}: minSdk = 30")
        else:
            print(f"• {f.relative_to(ROOT)}: không thấy minSdk – hãy tự đặt minSdk = 30")
        return
    print("✘ Không thấy android/app/build.gradle(.kts). Đã chạy `flutter create .` chưa?")
    sys.exit(1)


def patch_main_manifest() -> None:
    f = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
    s = f.read_text(encoding="utf-8")
    for perm in PERMISSIONS:
        if perm not in s:
            s = re.sub(r"(<manifest[^>]*>\s*\n)", rf'\1    <uses-permission android:name="{perm}" />\n', s, count=1)
    # flutter create thường đã có <queries> cho PROCESS_TEXT → thay bằng bản đầy đủ
    if "android.speech.RecognitionService" not in s:
        if "<queries>" in s:
            s = re.sub(r"\s*<queries>.*?</queries>\s*\n", "\n" + QUERIES, s, flags=re.S)
        else:
            s = s.replace("</manifest>", QUERIES + "</manifest>")
    s = re.sub(r'android:label="[^"]*"', 'android:label="Cú Tò Mò"', s, count=1)
    f.write_text(s, encoding="utf-8")
    print(f"✔ {f.relative_to(ROOT)}: quyền + queries + tên app")


def allow_http_everywhere() -> None:
    """--allow-http: bản build THỬ NGHIỆM gọi được backend qua http:// trong mạng nhà (kể cả bản release).
    Bản phát hành thật phải dùng HTTPS và KHÔNG dùng cờ này."""
    f = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
    s = f.read_text(encoding="utf-8")
    if "usesCleartextTraffic" not in s:
        s = s.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
        f.write_text(s, encoding="utf-8")
    print(f"✔ {f.relative_to(ROOT)}: cho phép HTTP (chỉ dùng cho bản thử nghiệm)")


def patch_debug_manifest() -> None:
    f = ANDROID / "app" / "src" / "debug" / "AndroidManifest.xml"
    if not f.exists():
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n</manifest>\n',
                     encoding="utf-8")
    s = f.read_text(encoding="utf-8")
    if "usesCleartextTraffic" not in s:
        s = s.replace("</manifest>", '    <application android:usesCleartextTraffic="true" />\n</manifest>')
        f.write_text(s, encoding="utf-8")
    print(f"✔ {f.relative_to(ROOT)}: cho phép HTTP khi debug (backend trong mạng LAN)")


if __name__ == "__main__":
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if not ANDROID.exists():
        print("✘ Chưa có thư mục android/. Chạy: flutter create --org vn.dmtlab --project-name cu_to_mo --platforms android .")
        sys.exit(1)
    patch_gradle()
    patch_main_manifest()
    patch_debug_manifest()
    if "--allow-http" in sys.argv:
        allow_http_everywhere()
    print("Xong! Chạy: flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:8080 --dart-define=APP_SECRET=<APP_SHARED_SECRET>")
