import 'package:flutter/foundation.dart';

/// Cấu hình build. Truyền khi chạy:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080 --dart-define=APP_SECRET=...
/// Phụ huynh cũng có thể đổi địa chỉ máy chủ trong Góc phụ huynh → Cài đặt (dành cho bản thử nghiệm).
///
/// Bản WEB (mở bằng trình duyệt trên máy tính bảng): nếu không truyền API_BASE_URL thì app gọi API về
/// chính địa chỉ đang mở trang (backend phục vụ cả giao diện lẫn API) → đổi IP máy tính không cần build lại.
///
/// Lưu ý: APP_SECRET chỉ để backend nhận biết app, KHÔNG phải khóa AI. Khóa AI chỉ nằm trên server (NFR-07).
class AppConfig {
  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kIsWeb) return Uri.base.origin;
    return 'http://192.168.1.10:8080';
  }

  static const appSecret = String.fromEnvironment('APP_SECRET', defaultValue: 'change-me');

  /// Số hồ sơ bé tối đa trên một máy (FR-03).
  static const maxProfiles = 3;
}
