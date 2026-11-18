import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config.dart';
import '../models/app_settings.dart';
import '../models/child_profile.dart';
import '../models/game_models.dart';
import 'api_client.dart';
import 'local_store.dart';
import 'music_service.dart';
import 'parent_voice_service.dart';
import 'secure_store.dart';
import 'sound_service.dart';
import 'stt_service.dart';
import 'tts_service.dart';

// ---------------------------------------------------------------- dịch vụ (khởi tạo trong main.dart)
final localStoreProvider = Provider<LocalStore>((ref) => throw UnimplementedError('override trong main'));
final ttsProvider = Provider<TtsService>((ref) => throw UnimplementedError('override trong main'));
final soundProvider = Provider<SoundService>((ref) => throw UnimplementedError('override trong main'));
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
final sttProvider = Provider<SttService>((ref) => SttService());
final musicProvider = Provider<MusicService>((ref) => throw UnimplementedError('override trong main'));
final parentVoiceProvider = Provider<ParentVoiceService>((ref) => throw UnimplementedError('override trong main'));

// ---------------------------------------------------------------- cài đặt
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._ref) : super(_ref.read(localStoreProvider).settings());
  final Ref _ref;

  Future<void> save(AppSettings s) async {
    state = s;
    await _ref.read(localStoreProvider).saveSettings(s);
    await _ref.read(ttsProvider).apply(rate: s.ttsRate, pitch: s.ttsPitch, voice: s.voiceName);
    _ref.read(soundProvider).enabled = s.soundEffects;
    final music = _ref.read(musicProvider);
    if (music.enabled != s.gameMusic) await music.setEnabled(s.gameMusic);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) => SettingsNotifier(ref));

/// Khóa AI riêng của phụ huynh cho nhà cung cấp đang chọn (null = dùng AI mặc định của máy chủ).
class AiCred {
  final String provider, key, model;
  const AiCred(this.provider, this.key, this.model);
}

class AiCredNotifier extends StateNotifier<AiCred?> {
  AiCredNotifier(this._ref) : super(null) {
    reload();
  }
  final Ref _ref;

  Future<void> reload() async {
    final provider = _ref.read(settingsProvider).provider;
    if (provider.isEmpty) {
      state = null;
      return;
    }
    final sec = _ref.read(secureStoreProvider);
    final key = await sec.aiKey(provider);
    state = key == null || key.isEmpty ? null : AiCred(provider, key, await sec.aiModel(provider) ?? '');
  }
}

final aiCredProvider = StateNotifierProvider<AiCredNotifier, AiCred?>((ref) {
  ref.watch(settingsProvider.select((s) => s.provider)); // đổi nhà cung cấp → nạp lại khóa tương ứng
  return AiCredNotifier(ref);
});

final apiProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(settingsProvider.select((s) => s.serverUrl));
  final cred = ref.watch(aiCredProvider);
  return ApiClient(
    url.trim().isNotEmpty ? url.trim() : AppConfig.apiBaseUrl,
    AppConfig.appSecret,
    aiHeaders: cred == null
        ? const {}
        : {'x-ai-provider': cred.provider, 'x-ai-key': cred.key, if (cred.model.isNotEmpty) 'x-ai-model': cred.model},
  );
});

// ---------------------------------------------------------------- hồ sơ bé
class ProfilesState {
  final List<ChildProfile> list;
  final String? activeId;
  const ProfilesState(this.list, this.activeId);

  ChildProfile? get active {
    for (final p in list) {
      if (p.id == activeId) return p;
    }
    return list.isNotEmpty ? list.first : null;
  }
}

class ProfilesNotifier extends StateNotifier<ProfilesState> {
  ProfilesNotifier(this._store) : super(ProfilesState(_store.profiles(), _store.activeChildId));
  final LocalStore _store;

  Future<void> upsert(ChildProfile p, {bool makeActive = false}) async {
    await _store.saveProfile(p);
    final list = [...state.list];
    final idx = list.indexWhere((e) => e.id == p.id);
    if (idx >= 0) {
      list[idx] = p;
    } else {
      list.add(p);
    }
    final active = makeActive ? p.id : (state.activeId ?? p.id);
    await _store.setActiveChild(active);
    state = ProfilesState(list, active);
  }

  Future<void> remove(String id) async {
    await _store.deleteProfile(id);
    await _store.clearChildUsage(id);
    final list = state.list.where((e) => e.id != id).toList();
    final active = state.activeId == id ? (list.isNotEmpty ? list.first.id : null) : state.activeId;
    await _store.setActiveChild(active);
    state = ProfilesState(list, active);
  }

  Future<void> setActive(String id) async {
    await _store.setActiveChild(id);
    state = ProfilesState(state.list, id);
  }

  /// FR-40: cộng sao cho bé đang học.
  Future<void> addStars(int n) async {
    final a = state.active;
    if (a == null || n <= 0) return;
    await upsert(a.copyWith(stars: a.stars + n));
  }
}

final profilesProvider =
    StateNotifierProvider<ProfilesNotifier, ProfilesState>((ref) => ProfilesNotifier(ref.read(localStoreProvider)));

final activeChildProvider = Provider<ChildProfile?>((ref) => ref.watch(profilesProvider).active);

// ---------------------------------------------------------------- đăng ký thiết bị với backend
class DeviceService {
  DeviceService(this._ref);
  final Ref _ref;

  /// Trả device_id; đăng ký lần đầu nếu chưa có (cần mạng). Lỗi mạng → null (thử lại lần sau).
  Future<String?> ensureRegistered() async {
    final sec = _ref.read(secureStoreProvider);
    final existing = await sec.deviceId();
    if (existing != null) return existing;
    try {
      final (id, token) = await _ref.read(apiProvider).registerDevice();
      await sec.saveDevice(id, token);
      return id;
    } catch (_) {
      return null;
    }
  }
}

final deviceServiceProvider = Provider<DeviceService>((ref) => DeviceService(ref));

// ---------------------------------------------------------------- đồng hồ học (FR-50, FR-51, FR-52)
class StudyState {
  final int secondsToday;
  final int sinceBreak;
  final bool breakDue;
  final bool limitReached;
  final bool bedtime;
  const StudyState({
    this.secondsToday = 0,
    this.sinceBreak = 0,
    this.breakDue = false,
    this.limitReached = false,
    this.bedtime = false,
  });

  bool get canStudy => !limitReached && !bedtime;
}

/// Đếm thời gian học khi đang ở màn học (TutorScreen, luyện tập) và app ở tiền cảnh.
class StudyTimer extends StateNotifier<StudyState> with WidgetsBindingObserver {
  StudyTimer(this._ref) : super(const StudyState()) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    refresh();
  }

  final Ref _ref;
  Timer? _timer;
  int _active = 0;
  bool _foreground = true;
  int _unsaved = 0;
  DateTime? _bedtimeOverrideUntil; // bố mẹ cho thêm giờ cả khi tới giờ ngủ

  void enter() => _active++;

  void leave() {
    _active = max(0, _active - 1);
    _flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _foreground = s == AppLifecycleState.resumed;
    if (!_foreground) _flush();
  }

  void refresh() {
    final child = _ref.read(activeChildProvider);
    final settings = _ref.read(settingsProvider);
    final store = _ref.read(localStoreProvider);
    final secs = child == null ? 0 : store.secondsToday(child.id) + _unsaved;
    final extra = child == null ? 0 : store.extraMinutesToday(child.id);
    final limit = settings.dailyLimitMinutes;
    state = StudyState(
      secondsToday: secs,
      sinceBreak: state.sinceBreak,
      breakDue: settings.breakMinutes > 0 && state.sinceBreak >= settings.breakMinutes * 60,
      limitReached: limit > 0 && secs >= (limit + extra) * 60,
      bedtime: settings.isBedtime(DateTime.now()) &&
          (_bedtimeOverrideUntil == null || DateTime.now().isAfter(_bedtimeOverrideUntil!)),
    );
  }

  void _tick() {
    if (!_foreground || _active == 0) return;
    _unsaved++;
    state = StudyState(
      secondsToday: state.secondsToday,
      sinceBreak: state.sinceBreak + 1,
      breakDue: state.breakDue,
      limitReached: state.limitReached,
      bedtime: state.bedtime,
    );
    if (_unsaved >= 15) _flush();
    refresh();
  }

  void _flush() {
    final child = _ref.read(activeChildProvider);
    if (child != null && _unsaved > 0) {
      _ref.read(localStoreProvider).addSeconds(child.id, _unsaved);
    }
    _unsaved = 0;
  }

  /// Gọi sau khi bé nghỉ giải lao xong.
  void breakTaken() {
    state = StudyState(
      secondsToday: state.secondsToday,
      sinceBreak: 0,
      breakDue: false,
      limitReached: state.limitReached,
      bedtime: state.bedtime,
    );
  }

  /// Phụ huynh cho thêm thời gian hôm nay.
  Future<void> grantExtra(int minutes) async {
    final child = _ref.read(activeChildProvider);
    if (child == null) return;
    await _ref.read(localStoreProvider).addExtraMinutes(child.id, minutes);
    _bedtimeOverrideUntil = DateTime.now().add(Duration(minutes: minutes));
    refresh();
  }

  @override
  void dispose() {
    _flush();
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final studyTimerProvider = StateNotifierProvider<StudyTimer, StudyState>((ref) => StudyTimer(ref));

// ---------------------------------------------------------------- điều ước gửi bố mẹ
class WishesNotifier extends StateNotifier<List<Wish>> {
  WishesNotifier(this._store) : super(_store.wishes());
  final LocalStore _store;

  void reload() => state = _store.wishes();

  Future<void> save(Wish w) async {
    await _store.saveWish(w);
    reload();
  }

  Future<void> delete(String id) async {
    await _store.deleteWish(id);
    reload();
  }
}

final wishesProvider =
    StateNotifierProvider<WishesNotifier, List<Wish>>((ref) => WishesNotifier(ref.read(localStoreProvider)));

/// Số điều ước bé gửi mà bố mẹ chưa trả lời (hiện dấu 💌 trên nút Góc phụ huynh).
final pendingWishCountProvider = Provider<int>((ref) => ref.watch(wishesProvider).where((w) => w.pending).length);
