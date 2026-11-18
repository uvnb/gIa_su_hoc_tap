import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Trạng thái thời gian chơi trong ngày của bé đang dùng máy.
class GameTimeState {
  final int secondsToday; // đã chơi hôm nay
  final int limitSeconds; // được chơi (đã cộng phút bố mẹ cho thêm)
  final bool enabled; // bố mẹ có cho chơi không
  final bool bedtime;
  final int studyNeededSeconds; // còn phải học thêm bao nhiêu giây mới mở trò chơi

  const GameTimeState({
    this.secondsToday = 0,
    this.limitSeconds = 3600,
    this.enabled = true,
    this.bedtime = false,
    this.studyNeededSeconds = 0,
  });

  int get remainingSeconds => max(0, limitSeconds - secondsToday);
  bool get timeUp => remainingSeconds <= 0;
  bool get canPlay => enabled && !bedtime && !timeUp && studyNeededSeconds <= 0;

  /// Vì sao chưa chơi được (null = chơi được).
  String? get blockedReason {
    if (!enabled) return 'Bố mẹ đang tắt trò chơi.';
    if (bedtime) return 'Tới giờ đi ngủ rồi!';
    if (studyNeededSeconds > 0) {
      return 'Học thêm ${(studyNeededSeconds / 60).ceil()} phút với Cú để mở trò chơi nhé!';
    }
    if (timeUp) return 'Hết giờ chơi hôm nay rồi. Mai chơi tiếp nhé!';
    return null;
  }

  /// "41:20" – thời gian còn lại.
  String get remainingLabel {
    final r = remainingSeconds;
    return '${r ~/ 60}:${(r % 60).toString().padLeft(2, '0')}';
  }
}

/// Đếm giờ chơi khi bé đang ở màn trò chơi và app ở tiền cảnh (tách riêng với giờ học).
class GameTimer extends StateNotifier<GameTimeState> with WidgetsBindingObserver {
  GameTimer(this._ref) : super(const GameTimeState()) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    refresh();
  }

  final Ref _ref;
  Timer? _timer;
  int _active = 0;
  bool _foreground = true;
  int _unsaved = 0;

  void enter() {
    _active++;
    // không đổi state ngay lúc màn hình đang dựng (initState) – để sau khung hình hiện tại
    Future.microtask(() {
      if (mounted) refresh();
    });
  }

  void leave() {
    _active = max(0, _active - 1);
    _flush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _flush();
  }

  void refresh() {
    final child = _ref.read(activeChildProvider);
    final settings = _ref.read(settingsProvider);
    final store = _ref.read(localStoreProvider);
    if (child == null) {
      state = const GameTimeState(enabled: false);
      return;
    }
    final played = store.gameSecondsToday(child.id) + _unsaved;
    final extra = store.gameExtraMinutesToday(child.id);
    final studied = store.secondsToday(child.id);
    final need = settings.gameNeedStudyMinutes * 60 - studied;
    state = GameTimeState(
      secondsToday: played,
      limitSeconds: (settings.gameMinutes + extra) * 60,
      enabled: settings.gamesEnabled,
      bedtime: _ref.read(studyTimerProvider).bedtime,
      studyNeededSeconds: max(0, need),
    );
  }

  void _tick() {
    if (!_foreground || _active == 0) return;
    _unsaved++;
    if (_unsaved >= 15) _flush();
    refresh();
  }

  void _flush() {
    final child = _ref.read(activeChildProvider);
    if (child != null && _unsaved > 0) {
      _ref.read(localStoreProvider).addGameSeconds(child.id, _unsaved);
    }
    _unsaved = 0;
  }

  /// Bố mẹ cho thêm phút chơi hôm nay.
  Future<void> grantExtra(int minutes) async {
    final child = _ref.read(activeChildProvider);
    if (child == null) return;
    await _ref.read(localStoreProvider).addGameExtraMinutes(child.id, minutes);
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

final gameTimerProvider = StateNotifierProvider<GameTimer, GameTimeState>((ref) => GameTimer(ref));

// ---------------------------------------------------------------- điểm trò chơi
/// Điểm trò chơi của bé đang dùng máy (hôm nay / tổng) – cập nhật ngay khi ghi điểm.
class GamePoints {
  final int today;
  final int total;
  const GamePoints(this.today, this.total);
}

class GamePointsNotifier extends StateNotifier<GamePoints> {
  GamePointsNotifier(this._ref) : super(const GamePoints(0, 0)) {
    reload();
  }
  final Ref _ref;

  void reload() {
    final child = _ref.read(activeChildProvider);
    final store = _ref.read(localStoreProvider);
    state = child == null
        ? const GamePoints(0, 0)
        : GamePoints(store.gamePointsToday(child.id), store.gamePointsTotal(child.id));
  }

  /// Cộng điểm. Trả true nếu lần cộng này vừa giúp bé đạt mục tiêu hôm nay (mở "điều ước").
  Future<bool> add(int n) async {
    final child = _ref.read(activeChildProvider);
    if (child == null || n <= 0) return false;
    final store = _ref.read(localStoreProvider);
    final goal = _ref.read(settingsProvider).gameDailyGoal;
    final before = store.gamePointsToday(child.id);
    await store.addGamePoints(child.id, n);
    reload();
    if (before < goal && before + n >= goal && !store.goalCelebratedToday(child.id)) {
      await store.setGoalCelebratedToday(child.id);
      return true;
    }
    return false;
  }
}

final gamePointsProvider = StateNotifierProvider<GamePointsNotifier, GamePoints>((ref) {
  ref.watch(activeChildProvider.select((c) => c?.id));
  return GamePointsNotifier(ref);
});
