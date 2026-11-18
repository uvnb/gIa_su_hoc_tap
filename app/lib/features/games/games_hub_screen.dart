import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_timer.dart';
import '../../core/local_store.dart';
import '../../core/providers.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';

/// 🎮 Góc trò chơi: chọn trò, xem giờ chơi còn lại, điểm hôm nay và "điều ước" gửi bố mẹ.
class GamesHubScreen extends ConsumerStatefulWidget {
  const GamesHubScreen({super.key});

  @override
  ConsumerState<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends ConsumerState<GamesHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(gameTimerProvider.notifier).refresh();
      ref.read(gamePointsProvider.notifier).reload();
      ref.read(wishesProvider.notifier).reload();
      await _readReplies();
    });
  }

  /// Bố mẹ đã trả lời điều ước → Cú đọc cho bé nghe (một lần).
  Future<void> _readReplies() async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    final unseen = ref.read(wishesProvider).where((w) => w.childId == child.id && !w.pending && !w.replySeen).toList();
    if (unseen.isEmpty) {
      final st = ref.read(gameTimerProvider);
      ref.read(ttsProvider).say(st.canPlay ? 'Góc trò chơi! Bạn muốn chơi trò nào?' : (st.blockedReason ?? ''));
      return;
    }
    final w = unseen.first;
    final ok = w.status == 'approved';
    final msg = ok
        ? 'Bố mẹ đồng ý điều ước của bạn rồi!${w.reply.isEmpty ? '' : ' Bố mẹ nhắn: ${w.reply}'}'
        : 'Bố mẹ hẹn dịp khác nhé.${w.reply.isEmpty ? '' : ' Bố mẹ nhắn: ${w.reply}'}';
    for (final u in unseen) {
      await ref.read(wishesProvider.notifier).save(u.copyWith(replySeen: true));
    }
    if (ok) ref.read(soundProvider).tada();
    ref.read(ttsProvider).say(msg);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(ok ? '🎉' : '⏳', style: const TextStyle(fontSize: 72)),
            Text(ok ? 'Bố mẹ đồng ý rồi!' : 'Bố mẹ hẹn dịp khác', style: titleStyle(34)),
            const SizedBox(height: 10),
            Text('${w.emoji} ${w.text}', textAlign: TextAlign.center, style: bodyStyle(24)),
            if (w.reply.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('💌 “${w.reply}”', textAlign: TextAlign.center, style: titleStyle(26, const Color(0xFFE0457B))),
            ],
          ]),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Yeah! 💖'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final time = ref.watch(gameTimerProvider);
    final pts = ref.watch(gamePointsProvider);
    ref.watch(wishesProvider);
    final settings = ref.watch(settingsProvider);
    final store = ref.read(localStoreProvider);
    if (child == null) {
      return Scaffold(body: Center(child: ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Về'))));
    }
    final canPlay = time.canPlay;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF1F7), Color(0xFFE6F4FF), Color(0xFFFFF8E1)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 14),
            child: Column(
              children: [
                Row(children: [
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('← Về nhà'),
                  ),
                  const SizedBox(width: 16),
                  Text('🎮 Góc trò chơi', style: titleStyle(38)),
                  const Spacer(),
                  _chip(time.canPlay ? '⏳ Còn ${time.remainingLabel}' : '⏳ ${_short(time)}',
                      time.canPlay ? Colors.white : const Color(0xFFFFE0EC)),
                  const SizedBox(width: 10),
                  _chip('🏆 Hôm nay ${pts.today}', AppColors.sun),
                  const SizedBox(width: 10),
                  _chip('💰 Tổng ${pts.total}', Colors.white),
                ]),
                const SizedBox(height: 12),
                if (!canPlay) _blocked(time),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _GameCard(
                          emoji: '🧩',
                          title: 'Xếp Khối Toán',
                          desc: 'Kéo khối, nổ hàng, giải đố toán để mở khối bí ẩn!',
                          colors: const [Color(0xFFFF8FB1), Color(0xFFFFB547)],
                          stats: 'Cấp ${store.gameLevel(child.id, 'blocks')} · Kỷ lục ${store.gameBest(child.id, 'blocks')}',
                          onPlay: canPlay ? () => context.go('/games/blocks') : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _GameCard(
                          emoji: '🦉',
                          title: 'Cú Từ Ngữ',
                          desc: 'Đọc to từ trên màn hình để Cú nhảy qua chướng ngại vật!',
                          colors: const [Color(0xFF5EB8FF), Color(0xFF6BD49A)],
                          stats: 'Cấp ${store.gameLevel(child.id, 'runner')} · Kỷ lục ${store.gameBest(child.id, 'runner')}',
                          onPlay: canPlay ? () => context.go('/games/runner') : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _wishCard(child.id, pts, settings.gameDailyGoal, store),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _short(GameTimeState t) {
    if (!t.enabled) return 'Đang tắt';
    if (t.bedtime) return 'Giờ ngủ';
    if (t.studyNeededSeconds > 0) return 'Học thêm ${(t.studyNeededSeconds / 60).ceil()}′';
    return 'Hết giờ';
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
        ),
        child: Text(text, style: bodyStyle(21, AppColors.ink, FontWeight.w800)),
      );

  Widget _blocked(GameTimeState t) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          const OwlView(mood: 'sleepy', size: 64),
          const SizedBox(width: 12),
          Expanded(child: Text(t.blockedReason ?? '', style: titleStyle(26))),
          if (t.studyNeededSeconds > 0)
            ElevatedButton(onPressed: () => context.go('/home'), child: const Text('📚 Đi học với Cú')),
          if (t.timeUp && t.enabled && !t.bedtime)
            OutlinedButton(
              onPressed: () async {
                final ok = await context.push<bool>('/parent', extra: 'grantGame15');
                if (ok == true) ref.read(gameTimerProvider.notifier).refresh();
              },
              child: const Text('👨‍👩‍👧 Bố mẹ cho thêm 15 phút'),
            ),
        ]),
      );

  Widget _wishCard(String childId, GamePoints pts, int goal, LocalStore store) {
    final wish = store.wishToday(childId);
    final reached = pts.today >= goal;
    final progress = (pts.today / goal).clamp(0.0, 1.0).toDouble();
    Widget right;
    if (wish != null) {
      final status = switch (wish.status) {
        'approved' => '🎉 Bố mẹ đồng ý rồi!',
        'later' => '⏳ Bố mẹ hẹn dịp khác',
        _ => '💌 Đã gửi – chờ bố mẹ xem nhé!',
      };
      right = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(status, style: titleStyle(26, wish.status == 'approved' ? AppColors.success : AppColors.ink)),
        Text('${wish.emoji} ${wish.text}', maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(20)),
        if (wish.reply.isNotEmpty) Text('Bố mẹ nhắn: “${wish.reply}”', style: bodyStyle(18, const Color(0xFFE0457B))),
      ]);
    } else if (reached) {
      right = Row(children: [
        Expanded(child: Text('Bạn đạt mục tiêu hôm nay rồi! 🎉', style: titleStyle(26, AppColors.success))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0457B), minimumSize: const Size(300, 76)),
          onPressed: () => context.go('/wish'),
          child: const Text('✍️ Viết điều ước gửi bố mẹ'),
        ),
      ]);
    } else {
      right = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Còn ${goal - pts.today} điểm nữa để mở 🎁 Phần thưởng đặc biệt', style: titleStyle(24)),
        const SizedBox(height: 4),
        Text('Đạt $goal điểm trong ngày → bạn được tự viết điều ước gửi bố mẹ!', style: bodyStyle(18)),
      ]);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFC2D6), width: 4),
      ),
      child: Row(children: [
        SizedBox(
          width: 120,
          height: 110,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 104,
              height: 104,
              child: CircularProgressIndicator(
                value: wish != null ? 1 : progress,
                strokeWidth: 12,
                backgroundColor: const Color(0xFFFFE0EC),
                color: const Color(0xFFE0457B),
              ),
            ),
            Text(wish != null ? '💌' : '🎁', style: const TextStyle(fontSize: 46)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(child: right),
      ]),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.colors,
    required this.stats,
    required this.onPlay,
  });
  final String emoji, title, desc, stats;
  final List<Color> colors;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final enabled = onPlay != null;
    return Material(
      borderRadius: BorderRadius.circular(36),
      elevation: enabled ? 6 : 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(36),
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: enabled ? colors : [Colors.grey.shade300, Colors.grey.shade400],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 110)),
                    Text(title, style: titleStyle(44, Colors.white)),
                    const SizedBox(height: 6),
                    Text(desc, textAlign: TextAlign.center, style: bodyStyle(22, Colors.white, FontWeight.w700)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(stats, style: bodyStyle(20, Colors.white, FontWeight.w800)),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                      child: Text(enabled ? '▶️ Chơi' : '🔒 Chưa mở',
                          style: titleStyle(30, enabled ? colors.first : Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nhãn ngắn của trạng thái điều ước (dùng ở Góc phụ huynh).
String wishStatusLabel(Wish w) => switch (w.status) {
      'approved' => '✅ Đã đồng ý',
      'later' => '⏳ Hẹn dịp khác',
      _ => '💌 Chờ bố mẹ',
    };
