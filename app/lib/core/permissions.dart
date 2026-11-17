import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Xin quyền camera / micro. Trên trình duyệt (bản chạy thử trên máy tính) chính trình duyệt sẽ hỏi
/// khi mở camera/micro, nên coi như đã được phép; mọi lỗi plugin cũng không làm app dừng.
Future<bool> ensurePermission(Permission p) async {
  if (kIsWeb) return true;
  try {
    final s = await p.request();
    return s.isGranted || s.isLimited;
  } catch (_) {
    return true;
  }
}
