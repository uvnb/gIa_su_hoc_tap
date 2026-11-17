import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu bí mật trên máy: mã PIN phụ huynh (băm + muối), device_id, parent_token (FR-04, FR-61).
class SecureStore {
  final _s = const FlutterSecureStorage();

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
          key: _kLockUntil,
          value: DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch.toString());
      await _s.delete(key: _kFails);
    } else {
      await _s.write(key: _kFails, value: '$fails');
    }
    return false;
  }

  Future<String?> deviceId() => _s.read(key: _kDeviceId);
  Future<String?> parentToken() => _s.read(key: _kParentToken);

  Future<void> saveDevice(String deviceId, String parentToken) async {
    await _s.write(key: _kDeviceId, value: deviceId);
    await _s.write(key: _kParentToken, value: parentToken);
  }

  Future<void> clearDevice() async {
    await _s.delete(key: _kDeviceId);
    await _s.delete(key: _kParentToken);
  }
}
