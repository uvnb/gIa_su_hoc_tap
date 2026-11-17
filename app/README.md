# Cú Tò Mò – ứng dụng Flutter

Xem hướng dẫn build ở [../README.md](../README.md#2-build-app-flutter).

```
lib/
├── main.dart, app_router.dart, config.dart
├── theme/app_theme.dart            bảng màu mục 6.2, chữ ≥ 20sp, nút ≥ 64dp
├── core/                           api_client (retry 3 lần), tts/stt tiếng Việt, âm thanh, ảnh (isolate),
│                                   local_store (Hive), secure_store (PIN, token), providers (Riverpod, StudyTimer)
├── models/                         hồ sơ bé, cài đặt, dữ liệu phiên (không có đáp án)
├── widgets/                        OwlView (linh vật vẽ bằng code), MicButton, PinPad, nút lớn…
└── features/
    ├── onboarding/   home/   capture/ (chụp + cắt + kiểm tra mờ/tối)   ask/ (nói/gõ câu hỏi)
    ├── tutor/        màn gia sư + bong bóng, bàn phím số, bảng nháp, công cụ trực quan, pháo giấy
    ├── mystery/      hộp bí ẩn   break_time/ (nghỉ giải lao, đi ngủ)   offline/ (luyện tập không mạng)
    └── parent/       PIN gate + báo cáo, đáp án tham khảo, cài đặt, hồ sơ bé, an toàn
tool/gen_sounds.py      sinh assets/sounds/{pop,ting,tada}.wav
tool/patch_android.py   vá android/ sau `flutter create .`
test/                   unit test logic thuần (flutter test)
```

Biến build: `--dart-define=API_BASE_URL=...` và `--dart-define=APP_SECRET=...` (khớp `APP_SHARED_SECRET` của backend).
