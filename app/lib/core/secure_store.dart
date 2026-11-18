import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'web_env.dart';

/// Kho bảo mật của máy; nếu trình duyệt chặn mã hóa (trang http:// chưa bật tùy chọn Chrome)
/// thì lưu tạm vào bộ nhớ thường của app – PIN vẫn được băm + muối, không bao giờ lưu dạng rõ.
class _Store {
  final _secure = const FlutterSecureStorage();
  Box get _box => Hive.box('meta');
  String _k(String key) => 'sec:$key';

  Future<String?> read({required String key}) async {
    if (isInsecureWebContext) return _box.get(_k(key)) as String?;
    try {
      return await _secure.read(key: key) ?? _box.get(_k(key)) as String?;
    } catch (_) {
      return _box.get(_k(key)) as String?;
    }
  }

  Future<void> write({required String key, required String value}) async {
    if (!isInsecureWebContext) {
      try {
        await _secure.write(key: key, value: value);
        return;
      } catch (_) {}
    }
    await _box.put(_k(key), value);
  }

  Future<void> delete({required String key}) async {
    await _box.delete(_k(key));
    if (isInsecureWebContext) return;
    try {
      await _secure.delete(key: key);
    } catch (_) {}
  }
}

/// Lưu bí mật trên máy: mã PIN phụ huynh (băm + muối), device_id, parent_token (FR-04, FR-61).
class SecureStore {
  final _s = _Store();

  static const _kPinHash = 'pin_hash';
  static const _kPinSalt = 'pin_salt';
  static const _kFails = 'pin_fails';
  static const _kLockUntil = 'pin_lock_until';
  static const _kDeviceId = 'device_id';
  static const _kParentToken = 'parent_token';

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt::$pin')).toString();

  Future<bool> hasPin() async => (await _s.read(key: _kPinHash)) != null;

  Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _s.write(key: _kPinSalt, value: salt);
    await _s.write(key: _kPinHash, value: _hash(pin, salt));
    await _s.delete(key: _kFails);
    await _s.delete(key: _kLockUntil);
  }

  /// Thời điểm hết khóa (null nếu không bị khóa).
  Future<DateTime?> lockedUntil() async {
    final v = await _s.read(key: _kLockUntil);
    if (v == null) return null;
    final t = DateTime.fromMillisecondsSinceEpoch(int.tryParse(v) ?? 0);
    return t.isAfter(DateTime.now()) ? t : null;
  }

  /// Kiểm tra PIN. Sai 3 lần → khóa 1 phút (mục 14.6 ParentGate).
  Future<bool> verifyPin(String pin) async {
    if (await lockedUntil() != null) return false;
    final salt = await _s.read(key: _kPinSalt);
    final hash = await _s.read(key: _kPinHash);
    if (salt == null || hash == null) return false;
    if (_hash(pin, salt) == hash) {
      await _s.delete(key: _kFails);
      return true;
    }
    final fails = (int.tryParse(await _s.read(key: _kFails) ?? '0') ?? 0) + 1;
    if (fails >= 3) {
      await _s.write(
          key: _kLockUntil, value: DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch.toString());
      await _s.delete(key: _kFails);
    } else {
      await _s.write(key: _kFails, value: '$fails');
    }
    return false;
  }

  Future<String?> deviceId() => _s.read(key: _kDeviceId);
  Future<String?> parentToken() => _s.read(key: _kParentToken);

  // ---- khóa AI riêng của phụ huynh (mã hóa trên máy, chỉ gửi kèm khi hỏi Cú) ----
  Future<String?> aiKey(String provider) => _s.read(key: 'ai_key_$provider');
  Future<String?> aiModel(String provider) => _s.read(key: 'ai_model_$provider');
  Future<void> setAiKey(String provider, String key, {String model = ''}) async {
    await _s.write(key: 'ai_key_$provider', value: key);
    await _s.write(key: 'ai_model_$provider', value: model);
  }

  Future<void> deleteAiKey(String provider) async {
    await _s.delete(key: 'ai_key_$provider');
    await _s.delete(key: 'ai_model_$provider');
  }

  Future<void> saveDevice(String deviceId, String parentToken) async {
    await _s.write(key: _kDeviceId, value: deviceId);
    await _s.write(key: _kParentToken, value: parentToken);
  }

  Future<void> clearDevice() async {
    await _s.delete(key: _kDeviceId);
    await _s.delete(key: _kParentToken);
  }
}
