"""Lưu trữ SQLite (máy tính ở nhà): phiên học (có đáp án BÍ MẬT), nhật ký bài cho báo cáo phụ huynh, thiết bị, cache Solver.

- Ảnh bài tập KHÔNG được lưu (chỉ xử lý trong bộ nhớ) → đáp ứng NFR-08 ở mức chặt nhất.
- Cache Solver lưu văn bản đề + lời giải theo hash ảnh, tự xóa sau IMAGE_RETENTION_HOURS.
- Phiên & nhật ký tự xóa sau SESSION_RETENTION_DAYS.
"""
from __future__ import annotations

import hashlib
import json
import os
import secrets
import sqlite3
import threading
import time
from contextlib import contextmanager
from typing import Any, Iterator

from .config import settings

_lock = threading.RLock()
_conn: sqlite3.Connection | None = None
_db_path: str | None = None

SCHEMA = """
CREATE TABLE IF NOT EXISTS devices (
    device_id TEXT PRIMARY KEY,
    parent_token_hash TEXT NOT NULL,
    created_at REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    child_id TEXT NOT NULL,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL,
    data TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS ix_sessions_child ON sessions(device_id, child_id, created_at);
CREATE TABLE IF NOT EXISTS problem_log (
    session_id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    child_id TEXT NOT NULL,
    subject TEXT, grade INTEGER, problem_type TEXT, problem_text TEXT,
    started_at REAL NOT NULL, updated_at REAL NOT NULL,
    turns INTEGER DEFAULT 0, max_hint INTEGER DEFAULT 0,
    outcome TEXT DEFAULT 'in_progress', stars INTEGER DEFAULT 0, safety_flag TEXT DEFAULT ''
);
CREATE INDEX IF NOT EXISTS ix_log_child ON problem_log(device_id, child_id, started_at);
CREATE TABLE IF NOT EXISTS solver_cache (
    key TEXT PRIMARY KEY,
    created_at REAL NOT NULL,
    data TEXT NOT NULL
);
"""


def _connect() -> sqlite3.Connection:
    global _conn, _db_path
    path = settings.db_path
    if _conn is None or _db_path != path:
        if path != ":memory:":
            os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
        _conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        _conn.row_factory = sqlite3.Row
        _conn.execute("PRAGMA journal_mode=WAL" if path != ":memory:" else "PRAGMA journal_mode=MEMORY")
        _conn.executescript(SCHEMA)
        _db_path = path
    return _conn


@contextmanager
def db() -> Iterator[sqlite3.Connection]:
    with _lock:
        yield _connect()


def reset_for_tests() -> None:
    global _conn, _db_path
    with _lock:
        if _conn is not None:
            _conn.close()
        _conn, _db_path = None, None


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


# ------------------------------ thiết bị / phụ huynh ------------------------------

def register_device() -> tuple[str, str]:
    device_id = secrets.token_hex(8)
    token = secrets.token_urlsafe(24)
    with db() as c:
        c.execute("INSERT INTO devices(device_id, parent_token_hash, created_at) VALUES (?,?,?)",
                  (device_id, _hash(token), time.time()))
    return device_id, token


def device_exists(device_id: str) -> bool:
    with db() as c:
        return c.execute("SELECT 1 FROM devices WHERE device_id=?", (device_id,)).fetchone() is not None


def check_parent_token(device_id: str, token: str | None) -> bool:
    if not token:
        return False
    with db() as c:
        row = c.execute("SELECT parent_token_hash FROM devices WHERE device_id=?", (device_id,)).fetchone()
    return bool(row) and secrets.compare_digest(row["parent_token_hash"], _hash(token))


# ------------------------------ phiên học ------------------------------

def new_session_id() -> str:
    return secrets.token_hex(6)


def save(session_id: str, sess: dict[str, Any]) -> None:
    now = time.time()
    sess["updated_at"] = now
    with db() as c:
        c.execute(
            "INSERT INTO sessions(session_id, device_id, child_id, created_at, updated_at, data) VALUES (?,?,?,?,?,?) "
            "ON CONFLICT(session_id) DO UPDATE SET updated_at=excluded.updated_at, data=excluded.data",
            (session_id, sess.get("device_id", ""), sess.get("child_id", ""), sess.get("created_at", now), now,
             json.dumps(sess, ensure_ascii=False)))
        p = sess.get("problem")
        if p:
            outcome = {"solved": "solved", "explaining": "solved", "parked": "parked"}.get(sess.get("state"), "in_progress")
            c.execute(
                "INSERT INTO problem_log(session_id, device_id, child_id, subject, grade, problem_type, problem_text, "
                "started_at, updated_at, turns, max_hint, outcome, stars, safety_flag) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?) "
                "ON CONFLICT(session_id) DO UPDATE SET updated_at=excluded.updated_at, turns=excluded.turns, "
                "max_hint=excluded.max_hint, outcome=excluded.outcome, stars=excluded.stars, "
                "safety_flag=excluded.safety_flag, problem_text=excluded.problem_text, problem_type=excluded.problem_type",
                (session_id, sess.get("device_id", ""), sess.get("child_id", ""), sess.get("subject", ""),
                 int(sess.get("grade", 0)), p.get("type", ""), p.get("text", "")[:500], sess.get("created_at", now), now,
                 int(sess.get("turns", 0)), int(sess.get("max_hint_level", 0)), outcome, int(sess.get("stars", 0)),
                 ",".join(sorted(set(sess.get("safety_flags", []))))))


def load(session_id: str) -> dict[str, Any] | None:
    with db() as c:
        row = c.execute("SELECT data FROM sessions WHERE session_id=?", (session_id,)).fetchone()
    return json.loads(row["data"]) if row else None


def count_sessions_today(device_id: str) -> int:
    start = time.time() - 24 * 3600
    with db() as c:
        row = c.execute("SELECT COUNT(*) AS n FROM sessions WHERE device_id=? AND created_at>=?",
                        (device_id, start)).fetchone()
    return int(row["n"])


def problem_logs(device_id: str, child_id: str, since: float) -> list[dict[str, Any]]:
    with db() as c:
        rows = c.execute("SELECT * FROM problem_log WHERE device_id=? AND child_id=? AND started_at>=? "
                         "ORDER BY started_at DESC", (device_id, child_id, since)).fetchall()
    return [dict(r) for r in rows]


def delete_child(device_id: str, child_id: str | None) -> int:
    """FR-64: xóa toàn bộ dữ liệu của bé (child_id=None → cả thiết bị)."""
    with db() as c:
        if child_id:
            n = c.execute("DELETE FROM sessions WHERE device_id=? AND child_id=?", (device_id, child_id)).rowcount
            c.execute("DELETE FROM problem_log WHERE device_id=? AND child_id=?", (device_id, child_id))
        else:
            n = c.execute("DELETE FROM sessions WHERE device_id=?", (device_id,)).rowcount
            c.execute("DELETE FROM problem_log WHERE device_id=?", (device_id,))
            c.execute("DELETE FROM devices WHERE device_id=?", (device_id,))
    return n


# ------------------------------ cache Solver ------------------------------

def solver_cache_get(key: str, max_age_hours: int) -> dict[str, Any] | None:
    with db() as c:
        row = c.execute("SELECT data, created_at FROM solver_cache WHERE key=?", (key,)).fetchone()
    if not row or time.time() - row["created_at"] > max_age_hours * 3600:
        return None
    return json.loads(row["data"])


def solver_cache_put(key: str, data: dict[str, Any]) -> None:
    with db() as c:
        c.execute("INSERT OR REPLACE INTO solver_cache(key, created_at, data) VALUES (?,?,?)",
                  (key, time.time(), json.dumps(data, ensure_ascii=False)))


# ------------------------------ dọn dẹp ------------------------------

def cleanup() -> dict[str, int]:
    now = time.time()
    cache_cut = now - settings.image_retention_hours * 3600
    sess_cut = now - settings.session_retention_days * 86400
    with db() as c:
        a = c.execute("DELETE FROM solver_cache WHERE created_at<?", (cache_cut,)).rowcount
        b = c.execute("DELETE FROM sessions WHERE updated_at<?", (sess_cut,)).rowcount
        d = c.execute("DELETE FROM problem_log WHERE updated_at<?", (sess_cut,)).rowcount
    return {"solver_cache": a, "sessions": b, "problem_log": d}


# ------------------------------ chạy trên cloud ------------------------------
# STORE_BACKEND=firestore (Cloud Run): dùng cùng các hàm nhưng lưu ở Firestore.
if settings.store_backend == "firestore":  # pragma: no cover – kiểm thử bằng bản SQLite
    from .store_firestore import (  # noqa: F401,F811
        check_parent_token, cleanup, count_sessions_today, delete_child, device_exists, import_device,
        import_problem_log, load, new_session_id, problem_logs, register_device, reset_for_tests, save,
        solver_cache_get, solver_cache_put)
