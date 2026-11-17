/// Cấu hình build. Truyền khi chạy:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080 --dart-define=APP_SECRET=...
/// Phụ huynh cũng có thể đổi địa chỉ máy chủ trong Góc phụ huynh → Cài đặt (dành cho bản thử nghiệm).
///
/// Lưu ý: APP_SECRET chỉ để backend nhận biết app, KHÔNG phải khóa AI. Khóa AI chỉ nằm trên server (NFR-07).
class AppConfig {
  static const apiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://192.168.1.10:8080');
  static const appSecret = String.fromEnvironment('APP_SECRET', defaultValue: 'change-me');

  /// Số hồ sơ bé tối đa trên một máy (FR-03).
  static const maxProfiles = 3;
}
