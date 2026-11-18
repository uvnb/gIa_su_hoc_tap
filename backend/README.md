# 🦉 Cú Brain – Backend FastAPI

Backend giữ **khóa API** và **đáp án bí mật**. App máy tính bảng không bao giờ nhận đáp án.

## Chạy nhanh (Windows PowerShell)

```powershell
cd backend
py -3.10 -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
copy .env.example .env          # rồi mở .env điền ANTHROPIC_API_KEY, đổi APP_SHARED_SECRET
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

Mở http://localhost:8080/docs để thử API trên trình duyệt.

**Chưa có khóa API?** Đặt `DEFAULT_PROVIDER=mock` và các dòng `*_PROVIDER=mock` trong `.env` → Cú chạy giả lập
(đọc đề dạng chữ, chấm số, câu gợi ý mẫu) để thử app Flutter miễn phí. Ảnh chụp sẽ luôn được hiểu là bài mẫu
"Lan có 7 cái kẹo…".

## Kiểm thử

```powershell
python -m pytest            # 79 test, dùng provider giả lập, không tốn tiền
python scripts/leak_eval.py --turns 50 --yes   # ⚠️ gọi AI thật, tốn phí – đo tỉ lệ lộ đáp án
```

Bộ test gồm 10 tình huống "chống lộ đáp án" (mục 17.2) chạy với Tutor giả lập **cố tình lộ đáp án**
(bằng chữ số và bằng chữ) để chứng minh Guard chặn được, cùng một bài chạy 1000 lượt ngẫu nhiên phải 0 lần lộ.

## Cấu trúc

| File | Vai trò |
|---|---|
| `app/main.py` | Các endpoint `/v1/...` |
| `app/models.py` | Schema request/response – liệt kê tường minh, không có trường `answer` |
| `app/store.py` | SQLite: phiên, nhật ký bài (báo cáo), thiết bị, cache Solver; tự dọn dữ liệu cũ |
| `app/pipeline/solver.py` | ① Đọc đề + giải (bí mật) · sinh bài thử thách |
| `app/pipeline/checker.py` | ② Chấm câu trả lời (đường nhanh cho đáp án số) |
| `app/pipeline/tutor.py` | ③ Vòng gia sư, thang gợi ý 6 bậc, tự giải thích, xem nháp |
| `app/pipeline/guard.py` | ④ Answer Guard: quy tắc + AI giám khảo |
| `app/pipeline/vn_numbers.py` | Đổi "mười hai" → 12, chuẩn hóa số kiểu Việt Nam (2,5 · 1.000) |
| `app/pipeline/safety.py` | Lọc từ ngữ, xử lý tình huống nhạy cảm, câu an toàn dựng sẵn |
| `app/providers/` | Adapter Claude / ChatGPT / giả lập + router chọn model theo vai trò & mức |
| `app/prompts/*.md` | Bộ prompt tiếng Việt |

## API

| Method | Đường dẫn | Ghi chú |
|---|---|---|
| GET | `/v1/health` | |
| POST | `/v1/device/register` | → `device_id`, `parent_token` (lưu trong secure storage của app) |
| POST | `/v1/session/start` | multipart: `image` hoặc `question_text`, `grade`, `subject`, `child_nickname`, `device_id`, `child_id`, `provider`, `tier` |
| POST | `/v1/session/select` | `{session_id, problem_id}` – chọn câu khi trang có nhiều câu (FR-12) |
| POST | `/v1/session/confirm` | `{session_id}` – bé bấm "Đúng rồi" (FR-15) → Cú hỏi câu mở đầu |
| POST | `/v1/session/turn` | `{session_id, child_input, input_mode}`; `input_mode=too_hard` cho nút "Khó quá" |
| POST | `/v1/session/scratch` | multipart `session_id`, `image` – "Cú xem giúp" bảng nháp (FR-23) |
| POST | `/v1/session/challenge` | `{session_id}` – thử thách tương tự (FR-30) |
| GET | `/v1/mystery-box?grade=` | Hộp bí ẩn hôm nay (FR-42) |
| GET | `/v1/parent/report` | header `x-parent-token` (FR-60) |
| GET | `/v1/parent/answer` | header `x-parent-token` – đáp án tham khảo (FR-61) |
| DELETE | `/v1/parent/child`, `/v1/parent/device` | xóa dữ liệu (FR-64) |

Mọi endpoint (trừ health) cần header `x-app-secret`.

## Ghi chú về model Claude (11/2026)

- Vai trò → model ở `.env`; mức "Tiết kiệm / Cân bằng / Thông minh" (FR-62) ánh xạ trong `app/config.py`.
- Adapter Claude **không gửi `temperature`** (Sonnet 5.5 / Haiku 5.5 trả lỗi 400), dùng `output_config.effort`
  để chỉnh độ suy nghĩ và **structured outputs** (`output_config.format`) để JSON luôn hợp lệ.
- Với Sonnet 5.5 / Opus 5.5 có bật **server-side fallback** (`fallbacks: "default"`) khi model từ chối;
  tắt bằng `ANTHROPIC_SERVER_FALLBACK=0`. Haiku 5.5 không hỗ trợ tham số này nên không gửi.
- System prompt của Tutor (luật + đề bí mật) được đánh dấu prompt caching → các lượt sau rẻ và nhanh hơn.
- Ảnh **không được lưu**: chỉ xử lý trong bộ nhớ, được mã hóa lại để xóa EXIF/GPS trước khi gửi AI.

## Triển khai thật

- Chạy sau HTTPS (Caddy / Nginx / PaaS). Đổi `APP_SHARED_SECRET`.
- SQLite đủ cho thử nghiệm; khi nhiều người dùng chuyển sang Postgres (chỉ cần viết lại `store.py`).
- Chọn gói API không dùng dữ liệu để huấn luyện ⚠️ VERIFY điều khoản từng nhà cung cấp.

## ☁️ Chạy trên cloud (không cần bật máy tính) – máy nhà làm dự phòng

Hiện tại: **Vercel** (gói Hobby miễn phí, Singapore) chạy FastAPI + **Google Firestore** (gói miễn phí) lưu dữ liệu.
Địa chỉ: `https://cu-to-mo-brain.vercel.app` (kiểm tra: `/v1/health` → `"store":"firestore"`).

- App gọi cloud trước; cloud không trả lời (mất mạng) thì tự thử máy nhà qua cáp USB (`run_backend.ps1`).
- Cập nhật cloud sau khi sửa backend:
  `python scripts/deploy_vercel.py --code-only --token-file D:/tools/vercel_token.txt --sa-file D:/tools/cu-brain-sa.json`
  (bỏ `--code-only` nếu đổi khóa Gemini / mã bí mật trong `.env`).
- Mã bí mật app (`APP_SHARED_SECRET` trong `.env`) = secret `APP_SECRET` của kho GitHub (CI dùng khi build APK)
  = biến môi trường trên Vercel. Máy nhà nhận cả mã này lẫn mã cũ `cutomo-local`.
- Firestore: project Google Cloud `cu-to-mo-brain-5089`, tài khoản dịch vụ `cu-brain-hf` (chỉ quyền Datastore User),
  khóa JSON để ngoài thư mục code (`D:/tools/cu-brain-sa.json`). Dữ liệu cũ tự dọn mỗi giờ (TTL cần billing nên chưa bật).
- Chuyển dữ liệu máy nhà lên cloud: `scripts/migrate_to_firestore.py`.
- Có `Dockerfile` sẵn nếu sau này dùng Google Cloud Run (cần thẻ thanh toán).
