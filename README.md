# 🦉 Cú Tò Mò – Gia sư AI cho học sinh Tiểu học

Ứng dụng Android (Masstel Tab 10 Edu) giúp bé lớp 1–5 **tự tìm ra đáp án**: Cú chỉ hỏi gợi mở, chia nhỏ vấn đề,
dùng que tính… và **không bao giờ nói đáp án**. Đặc tả gốc: [docs/cu-to-mo-gia-su-tieu-hoc-spec.md](docs/cu-to-mo-gia-su-tieu-hoc-spec.md).

```
apphocjtap/
├── backend/   FastAPI "Cú Brain" – giữ khóa API + đáp án bí mật, Solver/Checker/Tutor/Guard   (đã chạy & test)
├── app/       Flutter – giao diện cho bé, camera, giọng nói, Góc phụ huynh                     (cần Flutter SDK để build)
└── docs/      Spec + mẫu ghi thông số thiết bị
```

## 1. Chạy backend (5 phút)

```powershell
cd backend
py -3.10 -m venv .venv
.venv\Scripts\activate
pip install -r requirements-dev.txt
copy .env.example .env      # điền ANTHROPIC_API_KEY, đổi APP_SHARED_SECRET
python -m pytest            # 79 test – không gọi AI thật
uvicorn app.main:app --host 0.0.0.0 --port 8080
```

Chưa có khóa API? Trong `.env` đặt `DEFAULT_PROVIDER=mock` và mọi dòng `*_PROVIDER=mock` → chạy giả lập miễn phí.
Chi tiết: [backend/README.md](backend/README.md).

## 2. Cài app lên máy tính bảng (build trên GitHub – không cần cài Flutter)

**a) Bật backend trên máy tính** (máy tính và tablet cùng Wi-Fi):

```powershell
.\run_backend.ps1          # giả lập, miễn phí  ·  .\run_backend.ps1 -Real  → AI thật theo backend\.env
```
Script in ra địa chỉ cho tablet, ví dụ `http://192.168.0.100:8090`. Lần đầu Windows hỏi quyền mạng → chọn
**Mạng riêng (Private) → Cho phép**. Kiểm tra: trên tablet mở Chrome → `http://192.168.0.100:8090/v1/health`.

**b) Build APK trên GitHub** (workflow: [.github/workflows/build-apk.yml](.github/workflows/build-apk.yml)):
1. Tạo repo **riêng tư (Private)** trống trên github.com, ví dụ `cu-to-mo`.
2. Đẩy code lên:
   ```powershell
   git remote add origin https://github.com/<tài-khoản>/cu-to-mo.git
   git push -u origin main
   ```
3. Mỗi lần đẩy lên nhánh `main`, GitHub tự build (~10–15 phút). Muốn đổi địa chỉ backend:
   tab **Actions → Build APK → Run workflow**, sửa `api_base_url`.
4. Mở lần chạy có dấu ✅ → mục **Artifacts** → tải `cu-to-mo-apk` (.zip) → giải nén ra `cu-to-mo-<số>.apk`.

**c) Cài lên tablet:** chép file `.apk` sang (cáp USB, Zalo, Google Drive…) → mở file → cho phép
"Cài ứng dụng không rõ nguồn gốc" → Cài đặt. Bản mới cài đè bản cũ, không mất hồ sơ bé.

Đổi IP máy tính (router cấp IP khác)? Không cần build lại: vào **Góc phụ huynh → Cài đặt → Địa chỉ máy chủ**.

> Bản build này cho phép `http://` trong mạng nhà để thử nghiệm. Bản phát hành thật phải dùng HTTPS
> (bỏ cờ `--allow-http` trong workflow).

## 2b. Build trên máy (khi đã cài Flutter + Android Studio)

Cần: Flutter SDK 3.27+ , Android Studio (Android SDK), máy tính bảng bật **Gỡ lỗi USB** (mục 16 – M0).

```powershell
cd app
flutter create --org vn.dmtlab --project-name cu_to_mo --platforms android .   # sinh thư mục android/ (không ghi đè lib/)
Remove-Item test/widget_test.dart   # file mẫu flutter create sinh ra, không dùng
python tool/patch_android.py        # minSdk 30, quyền camera/micro, cho phép HTTP trong LAN khi debug
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://<IP-máy-tính>:8080 --dart-define=APP_SECRET=<APP_SHARED_SECRET>
```

Máy tính chạy backend và máy tính bảng phải **cùng Wi-Fi**. Địa chỉ máy chủ cũng đổi được trong
Góc phụ huynh → Cài đặt. Bản phát hành dùng HTTPS.

Chuẩn bị máy tính bảng: tải **giọng Tiếng Việt** cho Google Text-to-Speech và gói nhận dạng giọng nói Tiếng Việt
(hướng dẫn có trong Góc phụ huynh → An toàn).

## 3. Nguyên tắc vàng được bảo đảm bằng kỹ thuật

| Lớp | Cơ chế | Ở đâu |
|---|---|---|
| 1 | Đáp án chỉ nằm trên server; response model liệt kê tường minh, không có trường `answer` | `backend/app/models.py`, test `test_api.py` |
| 2 | Prompt Tutor + thang gợi ý 6 bậc, server khóa "chỉ leo 1 bậc/lượt" | `backend/app/prompts/tutor.md`, `pipeline/tutor.py` |
| 3 | Answer Guard: quy tắc (đổi "mười hai"→12, bắt "1 rồi 2") + AI giám khảo; lộ → sinh lại → câu an toàn | `pipeline/guard.py`, `vn_numbers.py` |
| 4 | Checker xác nhận khi bé nói đúng (đường nhanh cho đáp án số) | `pipeline/checker.py` |
| + | Công cụ trực quan chỉ nhận số trong đề; lựa chọn không chứa đáp án | `tutor.validate_actions` |

Bộ test chạy 10 tình huống mục 17.2 với Tutor giả lập **cố tình lộ đáp án** và 1000 lượt ngẫu nhiên: 0 lần lộ.
Khi tắt Guard, bài test 1000 lượt báo đỏ – chứng tỏ test bắt được lỗi thật.

## 4. Đối chiếu yêu cầu (FR) → code

| Mã | Trạng thái | Nơi thực hiện |
|---|---|---|
| FR-01 Cú vẫy tay + lời chào | ✅ | `app/lib/features/home/home_screen.dart`, `onboarding_screen.dart` |
| FR-02 Hồ sơ bé (biệt danh, lớp, avatar) | ✅ | `features/onboarding/profile_form.dart` |
| FR-03 Tối đa 3 hồ sơ, đổi bằng avatar | ✅ | `home_screen.dart`, Góc phụ huynh → Hồ sơ bé |
| FR-04 PIN 4 số + đồng ý điều khoản | ✅ | `onboarding_screen.dart`, `core/secure_store.dart` (băm + muối, khóa 1 phút sau 3 lần sai) |
| FR-10 Chụp bài có khung | ✅ | `features/capture/capture_screen.dart` |
| FR-11 Kiểm tra ảnh mờ/tối | ✅ | `core/image_utils.dart` (ngưỡng cần chỉnh trên máy thật) |
| FR-12 Cắt ảnh / chọn câu | ✅ | `crop_screen.dart` + danh sách câu chạm chọn trong màn gia sư |
| FR-13 Nói câu hỏi | ✅ | `features/ask/ask_screen.dart`, `widgets/mic_button.dart` |
| FR-14 Gõ câu hỏi (lớp 3–5) | ✅ | `ask_screen.dart`, nút ⌨️ trên bàn phím số |
| FR-15 Cú đọc lại đề, hỏi xác nhận | ✅ | `/v1/session/confirm` |
| FR-20…29 Phiên gia sư lõi | ✅ | `backend/app/pipeline/tutor.py`, `app/lib/features/tutor/` |
| FR-23 Bảng nháp + "Cú xem giúp" | ✅ | `widgets/scratch_pad.dart`, `/v1/session/scratch` |
| FR-24 Que tính, chấm tròn, khối chục, đồng hồ, thước, phân số | ✅ | `widgets/manipulatives.dart` |
| FR-30 Thử thách tương tự | ✅ | `/v1/session/challenge` |
| FR-40 Sao cho nỗ lực (tự sửa sai, tự giải thích) | ✅ | `tutor.py` |
| FR-41 Cú lớn lên 4 giai đoạn | ✅ | `widgets/owl_view.dart` (stage 0–3) |
| FR-42 Hộp bí ẩn hôm nay | ✅ | `features/mystery/`, `/v1/mystery-box` |
| FR-43 Bản đồ khám phá | ⏳ một phần | Các "đảo" môn học trên màn chính (chưa có bản đồ trạm) |
| FR-44 Sticker | ⏳ chưa làm (P2) | |
| FR-45 "Bạn có biết vì sao…?" | ✅ | `explain.md` + thẻ 💡 trong màn gia sư (≤ 1 lần/phiên) |
| FR-50 Nghỉ giải lao | ✅ | `features/break_time/break_time_screen.dart`, `StudyTimer` |
| FR-51 Giới hạn phút/ngày | ✅ | `StudyTimer`, `sleep_screen.dart` (bố mẹ mở thêm 15 phút bằng PIN) |
| FR-52 Giờ ngủ | ✅ | `AppSettings.isBedtime` |
| FR-60 Báo cáo | ✅ | `/v1/parent/report`, `parent_home_screen.dart` |
| FR-61 Đáp án tham khảo cho phụ huynh | ✅ | `/v1/parent/answer` (cần parent token) |
| FR-62 Chọn ChatGPT/Claude + mức | ✅ | Cài đặt → AI; `backend/app/config.py` |
| FR-63 Giọng, tốc độ, nghỉ, giới hạn | ✅ | Cài đặt |
| FR-64 Xóa dữ liệu của bé (cả server) | ✅ | Hồ sơ bé → Xóa dữ liệu; `DELETE /v1/parent/child` |
| FR-70 Luyện tập offline | ✅ | `features/offline/` (sinh bài theo lớp, gợi ý 6 bậc, không lộ kết quả) |
| FR-71 Tự thử lại 3 lần | ✅ | `core/api_client.dart` |

**Khác với spec (có chủ đích):**
- Linh vật vẽ bằng `CustomPainter` (7 trạng thái + 4 giai đoạn) thay cho file Rive → không cần thiết kế đồ họa, APK nhẹ.
  Khi có `owl.riv`, chỉ cần thay `OwlView`.
- Âm thanh pop/ting/tada được tổng hợp bằng `app/tool/gen_sounds.py` (dạng WAV, không lo bản quyền).
- Font Baloo 2 / Nunito tải qua `google_fonts` (lần đầu cần mạng; muốn chạy offline hoàn toàn thì đóng gói font vào assets).
- Bài luyện offline sinh ngẫu nhiên trong code thay cho `math_g1_g5.json`.
- Backend không lưu ảnh (chặt hơn mức "xóa sau 24 giờ"); ảnh được mã hóa lại để xóa EXIF/GPS.

## 5. Việc còn lại / cần kiểm tra

- ⚠️ **App Flutter chưa được biên dịch** (máy phát triển chưa có Flutter SDK): chạy `flutter analyze` và sửa lỗi nếu có.
- ⚠️ VERIFY phiên bản thư viện trên pub.dev; tốc độ TTS (thang 0–1 trên Android); tên menu Android 11/13;
  tên model OpenAI; văn bản pháp lý về dữ liệu trẻ em (Nghị định 13/2023/NĐ-CP và cập nhật).
- Đo NFR-01…06 trên cả 2 bản máy (ghi vào [docs/device.md](docs/device.md)) – mốc M6.
- Chạy `backend/scripts/leak_eval.py` với AI thật (tốn phí) để đo tỉ lệ lộ đáp án thực tế trước khi cho trẻ dùng.
- Giai đoạn 2: Tiếng Anh, giọng TTS cloud (`/v1/tts`), bản đồ đảo, sticker, robot ESP32 (backend dùng chung được).
