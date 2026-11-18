import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings.dart';
import '../models/child_profile.dart';
import '../models/game_models.dart';

/// Lưu cục bộ bằng Hive (không cần sinh code): hồ sơ bé, cài đặt, thời gian học mỗi ngày.
class LocalStore {
  late Box _profiles;
  late Box _settings;
  late Box _usage;
  late Box _meta;
  late Box _wishes;
  late Box _voices;

  Future<void> init() async {
    await Hive.initFlutter('cu_to_mo');
    _profiles = await Hive.openBox('profiles');
    _settings = await Hive.openBox('settings');
    _usage = await Hive.openBox('usage');
    _meta = await Hive.openBox('meta');
    _wishes = await Hive.openBox('wishes');
    _voices = await Hive.openBox('parent_voices');
  }

  // ---------------- hồ sơ bé ----------------
  List<ChildProfile> profiles() => _profiles.values.whereType<Map>().map((m) => ChildProfile.fromMap(m)).toList();

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
  int extraMinutesToday(String childId) => (_usage.get('extra|$childId|${dayKey(DateTime.now())}') as int?) ?? 0;

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
    final wishKeys = _wishes.keys.where((k) => (_wishes.get(k) as Map?)?['childId'] == childId).toList();
    await _wishes.deleteAll(wishKeys);
  }

  // ---------------- Góc trò chơi: thời gian chơi, điểm, cấp độ ----------------
  String get _today => dayKey(DateTime.now());

  int _int(String k) => (_usage.get(k) as int?) ?? 0;
  Future<void> _add(String k, int v) => _usage.put(k, _int(k) + v);

  int gameSecondsToday(String childId) => _int('game|$childId|$_today');
  Future<void> addGameSeconds(String childId, int s) => _add('game|$childId|$_today', s);

  int gameExtraMinutesToday(String childId) => _int('gextra|$childId|$_today');
  Future<void> addGameExtraMinutes(String childId, int m) => _add('gextra|$childId|$_today', m);

  int gamePointsToday(String childId) => _int('gpts|$childId|$_today');
  int gamePointsTotal(String childId) => _int('gptotal|$childId');
  Future<void> addGamePoints(String childId, int n) async {
    if (n <= 0) return;
    await _add('gpts|$childId|$_today', n);
    await _add('gptotal|$childId', n);
  }

  /// Cấp cao nhất bé đã mở trong từng trò (blocks | runner).
  int gameLevel(String childId, String game) => (_usage.get('glvl|$game|$childId') as int?) ?? 1;
  Future<void> setGameLevel(String childId, String game, int level) async {
    if (level > gameLevel(childId, game)) await _usage.put('glvl|$game|$childId', level);
  }

  int gameBest(String childId, String game) => _int('gbest|$game|$childId');
  Future<bool> submitGameBest(String childId, String game, int score) async {
    if (score <= gameBest(childId, game)) return false;
    await _usage.put('gbest|$game|$childId', score);
    return true;
  }

  /// Đã báo "đạt mục tiêu hôm nay" chưa (chỉ chúc mừng một lần mỗi ngày).
  bool goalCelebratedToday(String childId) => (_usage.get('ggoal|$childId|$_today') as bool?) ?? false;
  Future<void> setGoalCelebratedToday(String childId) => _usage.put('ggoal|$childId|$_today', true);

  Map<String, int> lastWeekGameMinutes(String childId) {
    final out = <String, int>{};
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final d = dayKey(now.subtract(Duration(days: i)));
      out[d] = (_int('game|$childId|$d') / 60).round();
    }
    return out;
  }

  // ---------------- điều ước gửi bố mẹ ----------------
  List<Wish> wishes({String? childId}) {
    final list = _wishes.values
        .whereType<Map>()
        .map((m) => Wish.fromMap(m))
        .where((w) => childId == null || w.childId == childId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Wish? wishToday(String childId) {
    final today = _today;
    for (final w in wishes(childId: childId)) {
      if (w.day == today) return w;
    }
    return null;
  }

  Future<void> saveWish(Wish w) => _wishes.put(w.id, w.toMap());
  Future<void> deleteWish(String id) => _wishes.delete(id);

  // ---------------- lời ghi âm của bố mẹ ----------------
  List<ParentVoice> voices() => _voices.values.whereType<Map>().map((m) => ParentVoice.fromMap(m)).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> saveVoice(ParentVoice v) => _voices.put(v.id, v.toMap());
  Future<void> deleteVoice(String id) => _voices.delete(id);

  // ---------------- linh tinh ----------------
  String? metaString(String k) => _meta.get(k) as String?;
  Future<void> setMeta(String k, Object? v) => _meta.put(k, v);
}
