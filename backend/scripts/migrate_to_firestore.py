"""Chuyển thiết bị đã đăng ký + nhật ký bài (báo cáo phụ huynh) từ SQLite ở máy nhà lên Firestore.

Chạy một lần sau khi tạo Firestore:
    set GOOGLE_CLOUD_PROJECT=<project>   (PowerShell: $env:GOOGLE_CLOUD_PROJECT='<project>')
    .venv\Scripts\python scripts\migrate_to_firestore.py
Cần đăng nhập: gcloud auth application-default login. Không chuyển phiên học đang dở (có đáp án bí mật).
"""
import os
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
os.environ.setdefault("STORE_BACKEND", "firestore")

from app import store_firestore as fs  # noqa: E402
from app.config import settings  # noqa: E402

db_path = os.environ.get("DB_PATH", str(ROOT / "data" / "cutomo.sqlite3"))
con = sqlite3.connect(db_path)
con.row_factory = sqlite3.Row
devices = con.execute("SELECT * FROM devices").fetchall()
for d in devices:
    fs.import_device(d["device_id"], d["parent_token_hash"], d["created_at"])
logs = con.execute("SELECT * FROM problem_log").fetchall()
for r in logs:
    fs.import_problem_log(dict(r))
print(f"Đã chuyển {len(devices)} thiết bị, {len(logs)} bài trong nhật ký lên Firestore "
      f"(project {os.environ.get('GOOGLE_CLOUD_PROJECT')}, database {settings.firestore_database}).")
