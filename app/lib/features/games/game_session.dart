import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_timer.dart';
import '../../core/music_service.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';

/// Dùng chung cho các màn trò chơi: đếm giờ chơi, bật nhạc nền, nhắc khi sắp hết giờ,
/// tự chuyển sang màn "hết giờ chơi" khi hết thời gian bố mẹ cho phép.
mixin GameSession<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  GameTimer? _gameTimer;
  MusicService? _music;
  ProviderSubscription<GameTimeState>? _timeSub;
  bool _ended = false;
  bool _leaving = false;

  /// Tên bài nhạc trong assets/music/.
  String get musicTrack;

  /// Gọi khi phải dừng trò chơi ngay (hết giờ) – màn trò chơi tạm dừng vòng lặp.
  void onGameStop() {}

  void startGameSession() {
    final timer = ref.read(gameTimerProvider.notifier);
    final music = ref.read(musicProvider);
    _gameTimer = timer;
    _music = music;
    timer.enter();
    music.play(musicTrack);
    _timeSub = ref.listenManual<GameTimeState>(gameTimerProvider, (prev, next) => _onTime(prev, next));
    final now = ref.read(gameTimerProvider);
    if (!now.canPlay) WidgetsBinding.instance.addPostFrameCallback((_) => _stop(now));
  }

  void endGameSession() {
    if (_ended) return;
    _ended = true;
    _timeSub?.close();
    _gameTimer?.leave();
    _music?.stop();
  }

  void _onTime(GameTimeState? prev, GameTimeState next) {
    if (_leaving || !mounted) return;
    if (!next.canPlay) {
      _stop(next);
      return;
    }
    final before = prev?.remainingSeconds ?? next.remainingSeconds + 1;
    for (final m in const [5, 1]) {
      if (before > m * 60 && next.remainingSeconds <= m * 60) {
        final msg = 'Còn $m phút chơi nữa thôi nhé!';
        ref.read(ttsProvider).say(msg);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          backgroundColor: AppColors.think,
          duration: const Duration(seconds: 4),
          content: Text('⏳ $msg', style: titleStyle(26, Colors.white)),
        ));
      }
    }
  }

  void _stop(GameTimeState s) {
    if (_leaving || !mounted) return;
    _leaving = true;
    onGameStop();
    endGameSession();
    context.go('/sleep', extra: s.bedtime ? 'bedtime' : 'game');
  }

  /// Rời trò chơi về Góc trò chơi.
  void leaveGame() {
    if (_leaving) return;
    _leaving = true;
    onGameStop();
    endGameSession();
    context.go('/games');
  }
}

/// Thanh trên cùng của màn trò chơi: ← về, tên trò, ⏳ giờ còn lại, 🏆 điểm hôm nay, 🎵 nhạc.
class GameTopBar extends ConsumerWidget {
  const GameTopBar({super.key, required this.title, required this.onBack, this.extra = const []});
  final String title;
  final VoidCallback onBack;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = ref.watch(gameTimerProvider);
    final pts = ref.watch(gamePointsProvider);
    final musicOn = ref.watch(settingsProvider.select((s) => s.gameMusic));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          _Pill(
            onTap: onBack,
            color: Colors.white,
            child: Text('← Góc trò chơi', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: titleStyle(32))),
          const Spacer(),
          ...extra,
          _Pill(
            color: time.remainingSeconds <= 300 ? const Color(0xFFFFE0EC) : Colors.white,
            child: Text('⏳ ${time.remainingLabel}', style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          _Pill(
            color: AppColors.sun,
            child: Text('🏆 ${pts.today}', style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          _Pill(
            color: Colors.white,
            onTap: () {
              final s = ref.read(settingsProvider);
              ref.read(settingsProvider.notifier).save(s.copyWith(gameMusic: !s.gameMusic));
            },
            child: Text(musicOn ? '🎵' : '🔇', style: const TextStyle(fontSize: 28)),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.child, required this.color, this.onTap});
  final Widget child;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(30),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56, minWidth: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      );
}

/// Phát lời bố mẹ (nếu có) cho [purpose], không có thì Cú nói [fallback].
Future<void> parentVoiceOrSay(WidgetRef ref, String purpose, String fallback) async {
  final child = ref.read(activeChildProvider);
  final played = await ref.read(parentVoiceProvider).play(purpose, childId: child?.id);
  if (!played) await ref.read(ttsProvider).say(fallback);
}
