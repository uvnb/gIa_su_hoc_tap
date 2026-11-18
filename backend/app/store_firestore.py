"""Lưu trữ trên Google Firestore – dùng khi chạy trên Cloud Run (STORE_BACKEND=firestore).

Cùng giao diện hàm với store.py (bản SQLite chạy trên máy tính – giữ làm dự phòng).
Cloud Run có thể tắt máy chủ khi không ai dùng hoặc chạy nhiều bản cùng lúc → không thể lưu trong
file SQLite cục bộ; Firestore là database luôn sống, mọi bản máy chủ đọc chung.

Collection:
  devices/{device_id}         parent_token_hash, created_at
  sessions/{session_id}       device_id, child_id, created_at, updated_at, data (JSON – có đáp án BÍ MẬT), expire_at
  problem_log/{session_id}    các cột như bản SQLite (báo cáo phụ huynh), expire_at
  solver_cache/{key}          created_at, data (JSON), expire_at
`expire_at` dùng cho chính sách TTL của Firestore (tự xóa); cleanup() dọn thêm phòng khi TTL chưa bật.
Chỉ dùng truy vấn bằng (==) rồi lọc trong Python → không cần tạo chỉ mục ghép.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import logging
import os
import secrets
import time
from typing import Any

from google.cloud import firestore
from google.cloud.firestore_v1.base_query import FieldFilter

from .config import settings

_client: firestore.Client | None = None
log = logging.getLogger("cutomo.firestore")


def _db() -> firestore.Client:
    """Trên Google Cloud tự dùng tài khoản dịch vụ của máy chủ; ở nơi khác (Hugging Face…) đọc khóa
    tài khoản dịch vụ từ biến bí mật FIRESTORE_CREDENTIALS_JSON (nội dung file JSON)."""
    global _client
    if _client is None:
        db_name = settings.firestore_database or "(default)"
        raw = os.environ.get("FIRESTORE_CREDENTIALS_JSON", "").strip()
        if raw:
            from google.oauth2 import service_account
            info = json.loads(raw)
            creds = service_account.Credentials.from_service_account_info(info)
            _client = firestore.Client(project=info.get("project_id"), credentials=creds, database=db_name)
        else:
            _client = firestore.Client(database=db_name)
    return _client


def _col(name: str):
    return _db().collection(name)


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def _expire(seconds: float) -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=seconds)


def _eq(col: str, **kw: Any):
    q = _col(col)
    for k, v in kw.items():
        q = q.where(filter=FieldFilter(k, "==", v))
    return q


def reset_for_tests() -> None:  # giữ cùng giao diện với bản SQLite
    pass


# ------------------------------ thiết bị / phụ huynh ------------------------------

def register_device() -> tuple[str, str]:
    device_id = secrets.token_hex(8)
    token = secrets.token_urlsafe(24)
    _col("devices").document(device_id).set({"parent_token_hash": _hash(token), "created_at": time.time()})
    return device_id, token


def import_device(device_id: str, parent_token_hash: str, created_at: float) -> None:
    """Chuyển thiết bị đã đăng ký ở máy chủ nhà lên cloud (giữ nguyên mã phụ huynh)."""
    _col("devices").document(device_id).set({"parent_token_hash": parent_token_hash, "created_at": created_at})


def device_exists(device_id: str) -> bool:
    return _col("devices").document(device_id).get().exists


def check_parent_token(device_id: str, token: str | None) -> bool:
    if not token or not device_id:
        return False
    snap = _col("devices").document(device_id).get()
    if not snap.exists:
        return False
    stored = (snap.to_dict() or {}).get("parent_token_hash", "")
    return bool(stored) and secrets.compare_digest(stored, _hash(token))


# ------------------------------ phiên học ------------------------------

def new_session_id() -> str:
    return secrets.token_hex(6)


def save(session_id: str, sess: dict[str, Any]) -> None:
    now = time.time()
    sess["updated_at"] = now
    keep = settings.session_retention_days * 86400
    batch = _db().batch()
    batch.set(_col("sessions").document(session_id), {
        "device_id": sess.get("device_id", ""),
        "child_id": sess.get("child_id", ""),
        "created_at": sess.get("created_at", now),
        "updated_at": now,
        "data": json.dumps(sess, ensure_ascii=False),
        "expire_at": _expire(keep),
    })
    p = sess.get("problem")
    if p:
        outcome = {"solved": "solved", "explaining": "solved", "parked": "parked"}.get(sess.get("state"), "in_progress")
        batch.set(_col("problem_log").document(session_id), {
            "session_id": session_id,
            "device_id": sess.get("device_id", ""),
            "child_id": sess.get("child_id", ""),
            "subject": sess.get("subject", ""),
            "grade": int(sess.get("grade", 0)),
            "problem_type": p.get("type", ""),
            "problem_text": p.get("text", "")[:500],
            "started_at": sess.get("created_at", now),
            "updated_at": now,
            "turns": int(sess.get("turns", 0)),
            "max_hint": int(sess.get("max_hint_level", 0)),
            "outcome": outcome,
            "stars": int(sess.get("stars", 0)),
            "safety_flag": ",".join(sorted(set(sess.get("safety_flags", [])))),
            "expire_at": _expire(keep),
        })
    batch.commit()


def load(session_id: str) -> dict[str, Any] | None:
    if not session_id:
        return None
    snap = _col("sessions").document(session_id).get()
    if not snap.exists:
        return None
    return json.loads((snap.to_dict() or {}).get("data", "null"))


def count_sessions_today(device_id: str) -> int:
    start = time.time() - 24 * 3600
    try:  # cần chỉ mục ghép (device_id, created_at) – nhanh, ít lượt đọc
        q = _eq("sessions", device_id=device_id).where(filter=FieldFilter("created_at", ">=", start))
        return q.count().get()[0][0].value
    except Exception as e:  # chưa có chỉ mục → lọc trong Python
        log.info("count_sessions_today dùng cách dự phòng: %s", e)
        return sum(1 for d in _eq("sessions", device_id=device_id).stream()
                   if (d.to_dict() or {}).get("created_at", 0) >= start)


_LOG_FIELDS = ("session_id", "device_id", "child_id", "subject", "grade", "problem_type", "problem_text",
               "started_at", "updated_at", "turns", "max_hint", "outcome", "stars", "safety_flag")


def problem_logs(device_id: str, child_id: str, since: float) -> list[dict[str, Any]]:
    rows = []
    q = _eq("problem_log", device_id=device_id, child_id=child_id)
    try:  # cần chỉ mục ghép (device_id, child_id, started_at)
        docs = list(q.where(filter=FieldFilter("started_at", ">=", since)).stream())
    except Exception as e:
        log.info("problem_logs dùng cách dự phòng: %s", e)
        docs = list(q.stream())
    for d in docs:
        r = d.to_dict() or {}
        if r.get("started_at", 0) >= since:
            rows.append({k: r.get(k) for k in _LOG_FIELDS})
    rows.sort(key=lambda r: r.get("started_at") or 0, reverse=True)
    return rows


def import_problem_log(row: dict[str, Any]) -> None:
    """Chuyển nhật ký bài từ máy chủ nhà lên cloud (để báo cáo phụ huynh không mất lịch sử)."""
    data = {k: row.get(k) for k in _LOG_FIELDS}
    data["expire_at"] = _expire(settings.session_retention_days * 86400 - (time.time() - (row.get("updated_at") or 0)))
    _col("problem_log").document(str(row["session_id"])).set(data)


def _delete_all(query) -> int:
    n = 0
    for d in query.stream():
        d.reference.delete()
        n += 1
    return n


def delete_child(device_id: str, child_id: str | None) -> int:
    """FR-64: xóa toàn bộ dữ liệu của bé (child_id=None → cả thiết bị)."""
    if child_id:
        n = _delete_all(_eq("sessions", device_id=device_id, child_id=child_id))
        _delete_all(_eq("problem_log", device_id=device_id, child_id=child_id))
    else:
        n = _delete_all(_eq("sessions", device_id=device_id))
        _delete_all(_eq("problem_log", device_id=device_id))
        _col("devices").document(device_id).delete()
    return n


# ------------------------------ cache Solver ------------------------------

def solver_cache_get(key: str, max_age_hours: int) -> dict[str, Any] | None:
    snap = _col("solver_cache").document(key).get()
    if not snap.exists:
        return None
    r = snap.to_dict() or {}
    if time.time() - r.get("created_at", 0) > max_age_hours * 3600:
        return None
    return json.loads(r.get("data", "null"))


def solver_cache_put(key: str, data: dict[str, Any]) -> None:
    _col("solver_cache").document(key).set({
        "created_at": time.time(),
        "data": json.dumps(data, ensure_ascii=False),
        "expire_at": _expire(settings.image_retention_hours * 3600),
    })


# ------------------------------ dọn dẹp ------------------------------

def cleanup() -> dict[str, int]:
    now = time.time()
    cache_cut = now - settings.image_retention_hours * 3600
    sess_cut = now - settings.session_retention_days * 86400
    out = {}
    for name, field, cut in (("solver_cache", "created_at", cache_cut), ("sessions", "updated_at", sess_cut),
                             ("problem_log", "updated_at", sess_cut)):
        out[name] = _delete_all(_col(name).where(filter=FieldFilter(field, "<", cut)).limit(300))
    return out
