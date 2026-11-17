/// Thông tin môi trường chạy trên trình duyệt (bản web mở trên máy tính bảng qua mạng nhà).
/// Android/iOS dùng bản stub; trình duyệt dùng bản _web.
export 'web_env_stub.dart' if (dart.library.js_interop) 'web_env_web.dart';
