import 'package:web/web.dart' as web;

/// true khi trang mở bằng http:// trong mạng nhà mà chưa bật tùy chọn Chrome
/// "Insecure origins treated as secure" → trình duyệt chặn camera, micro và mã hóa (crypto.subtle).
bool get isInsecureWebContext => !web.window.isSecureContext;
