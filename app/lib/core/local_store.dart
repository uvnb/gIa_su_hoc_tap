import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/child_profile.dart';

/// Lưu cục bộ bằng Hive (không cần sinh code): hồ sơ bé, cài đặt, thời gian học mỗi ngày.
class LocalStore {
  late Box _profiles;
  late Box _settings;
  late Box _usage;
  late Box _meta;

  Future<void> init() async {
    await Hive.initFlutter('cu_to_mo');
    _profiles = await Hive.openBox('profiles');
    _settings = await Hive.openBox('settings');
    _usage = await Hive.openBox('usage');
    _meta = await Hive.openBox('meta');
  }

  // ---------------- hồ sơ bé ----------------
  List<ChildProfile> profiles() => _profiles.values
      .whereType<Map>()
      .map((m) => ChildProfile.fromMap(m))
      .toList();

  Future<void> saveProfile(ChildProfile p) => _profiles.put(p.id, p.toMap());
  Future<void> deleteProfile(String id) => _profiles.delete(id);

  String? get activeChildId => _meta.get('activeChildId') as String?;
  Future<void> setActiveChild(String? id) => _meta.put('activeChildId', id);

  bool get onboardingDone => (_meta.get('onboardingDone') as bool?) ?? false;
  Future<void> setOnboardingDone(bool v) => _meta.put('onboardingDone', v);

  // ---------------- cài đặt ----------------
  AppSettings settings() => AppSettings.fromMap(_settings.get('app') as Map?);
  Future<void> saveSettings(AppSettings s) => _settings.put('app', s.toMap());

  // ---------------- thời gian học (FR-51) ----------------
  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int secondsToday(String childId) => (_usage.get('$childId|${dayKey(DateTime.now())}') as int?) ?? 0;

  Future<void> addSeconds(String childId, int s) {
    final k = '$childId|${dayKey(DateTime.now())}';
    return _usage.put(k, ((_usage.get(k) as int?) ?? 0) + s);
  }

  /// Phút phụ huynh cho thêm hôm nay (mở khóa khi hết giờ).
  int extraMinutesToday(String childId) =>
      (_usage.get('extra|$childId|${dayKey(DateTime.now())}') as int?) ?? 0;

  Future<void> addExtraMinutes(String childId, int m) {
    final k = 'extra|$childId|${dayKey(DateTime.now())}';
    return _usage.put(k, ((_usage.get(k) as int?) ?? 0) + m);
  }

  /// Phút học 7 ngày gần nhất (dùng trong báo cáo, kể cả luyện tập offline).
  Map<String, int> lastWeekMinutes(String childId) {
    final out = <String, int>{};
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d = dayKey(now.subtract(Duration(days: i)));
      out[d] = (((_usage.get('$childId|$d') as int?) ?? 0) / 60).round();
    }
    return out;
  }

  Future<void> clearChildUsage(String childId) async {
    final keys = _usage.keys.where((k) => k.toString().contains(childId)).toList();
    await _usage.deleteAll(keys);
  }

  // ---------------- linh tinh ----------------
  String? metaString(String k) => _meta.get(k) as String?;
  Future<void> setMeta(String k, Object? v) => _meta.put(k, v);
}
