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
      return Scaffold(
          body: Center(child: ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Về'))));
    }
    final canPlay = time.canPlay;
    final compact = isCompact(context);
    Widget card(String id) {
      final g = gameInfos.firstWhere((e) => e.id == id);
      return _GameCard(
        info: g,
        stats: 'Cấp ${store.gameLevel(child.id, id)} · Kỷ lục ${store.gameBest(child.id, id)}',
        onPlay: canPlay ? () => context.go('/games/$id') : null,
      );
    }

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
            padding: EdgeInsets.fromLTRB(compact ? 14 : 22, 8, compact ? 14 : 22, compact ? 10 : 14),
            child: Column(
              children: [
                Row(children: [
                  OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('← Về nhà'),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child:
                        Text('🎮 Góc trò chơi', overflow: TextOverflow.ellipsis, style: titleStyle(compact ? 27 : 38)),
                  ),
                  const Spacer(),
                  _chip(time.canPlay ? '⏳ Còn ${time.remainingLabel}' : '⏳ ${_short(time)}',
                      time.canPlay ? Colors.white : const Color(0xFFFFE0EC), compact),
                  const SizedBox(width: 8),
                  _chip(compact ? '🏆 ${pts.today}' : '🏆 Hôm nay ${pts.today}', AppColors.sun, compact),
                  const SizedBox(width: 8),
                  _chip('💰 ${pts.total}', Colors.white, compact),
                ]),
                const SizedBox(height: 12),
                if (!canPlay) _blocked(time),
                // 4 trò chơi – lưới 2 × 2
                Expanded(
                  child: Column(children: [
                    Expanded(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: card('blocks')),
                        SizedBox(width: compact ? 12 : 18),
                        Expanded(child: card('runner')),
                      ]),
                    ),
                    SizedBox(height: compact ? 10 : 14),
                    Expanded(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: card('balloon')),
                        SizedBox(width: compact ? 12 : 18),
                        Expanded(child: card('memory')),
                      ]),
                    ),
                  ]),
                ),
                SizedBox(height: compact ? 10 : 14),
                _wishCard(child.id, pts, settings.gameDailyGoal, store, compact),
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

  Widget _chip(String text, Color color, bool compact) => Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
        ),
        child: Text(text, style: bodyStyle(compact ? 17 : 21, AppColors.ink, FontWeight.w800)),
      );

  Widget _blocked(GameTimeState t) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          const OwlView(mood: 'sleepy', size: 64),
          const SizedBox(width: 12),
          Expanded(child: Text(t.blockedReason ?? '', style: titleStyle(22))),
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

  Widget _wishCard(String childId, GamePoints pts, int goal, LocalStore store, bool compact) {
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
        Text(status,
            style: titleStyle(compact ? 22 : 26, wish.status == 'approved' ? AppColors.success : AppColors.ink)),
        Text('${wish.emoji} ${wish.text}', maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(20)),
        if (wish.reply.isNotEmpty) Text('Bố mẹ nhắn: “${wish.reply}”', style: bodyStyle(18, const Color(0xFFE0457B))),
      ]);
    } else if (reached) {
      right = Row(children: [
        Expanded(
            child: Text('Bạn đạt mục tiêu hôm nay rồi! 🎉', style: titleStyle(compact ? 22 : 26, AppColors.success))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0457B), minimumSize: Size(compact ? 240 : 300, compact ? 64 : 76)),
          onPressed: () => context.go('/wish'),
          child: const Text('✍️ Viết điều ước gửi bố mẹ'),
        ),
      ]);
    } else {
      right = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('Còn ${goal - pts.today} điểm nữa để mở 🎁 Phần thưởng đặc biệt', style: titleStyle(compact ? 21 : 24)),
        const SizedBox(height: 4),
        Text('Đạt $goal điểm trong ngày → bạn được tự viết điều ước gửi bố mẹ!', style: bodyStyle(compact ? 16 : 18)),
      ]);
    }
    final ring = compact ? 80.0 : 104.0;
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFC2D6), width: 4),
      ),
      child: Row(children: [
        SizedBox(
          width: ring + 12,
          height: ring + 6,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: ring,
              height: ring,
              child: CircularProgressIndicator(
                value: wish != null ? 1 : progress,
                strokeWidth: 12,
                backgroundColor: const Color(0xFFFFE0EC),
                color: const Color(0xFFE0457B),
              ),
            ),
            Text(wish != null ? '💌' : '🎁', style: TextStyle(fontSize: compact ? 36 : 46)),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(child: right),
      ]),
    );
  }
}

/// Thông tin 4 trò chơi (dùng ở Góc trò chơi và Góc phụ huynh).
class GameInfo {
  final String id, emoji, title, desc;
  final List<Color> colors;
  const GameInfo(this.id, this.emoji, this.title, this.desc, this.colors);
}

const gameInfos = [
  GameInfo('blocks', '🧩', 'Xếp Khối Toán', 'Xếp khối, nổ hàng, giải đố toán mở khối bí ẩn!',
      [Color(0xFFFF8FB1), Color(0xFFFFB547)]),
  GameInfo('runner', '🦉', 'Cú Từ Ngữ', 'Đọc to từ trên màn hình để Cú nhảy qua chướng ngại!',
      [Color(0xFF5EB8FF), Color(0xFF6BD49A)]),
  GameInfo('balloon', '🎈', 'Bóng Bay Phép Tính', 'Chạm thật nhanh những quả bóng đúng mục tiêu!',
      [Color(0xFFFFB547), Color(0xFFFF7A6B)]),
  GameInfo('memory', '🃏', 'Lật Thẻ Trí Nhớ', 'Lật thẻ tìm cặp: hình – chữ, phép tính – kết quả!',
      [Color(0xFFB08CFF), Color(0xFF4FD1C5)]),
];

/// Thẻ trò chơi nằm ngang: hình to bên trái, tên + mô tả + cấp ở giữa, nút ▶️ bên phải.
class _GameCard extends StatelessWidget {
  const _GameCard({required this.info, required this.stats, required this.onPlay});
  final GameInfo info;
  final String stats;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final enabled = onPlay != null;
    final colors = enabled ? info.colors : [Colors.grey.shade300, Colors.grey.shade400];
    return Material(
      borderRadius: BorderRadius.circular(30),
      elevation: enabled ? 5 : 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 540,
                height: 200,
                child: Row(children: [
                  Text(info.emoji, style: const TextStyle(fontSize: 96)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // tên dài (vd "Bóng Bay Phép Tính") tự thu nhỏ cho vừa, không bị cắt
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(info.title, maxLines: 1, style: titleStyle(40, Colors.white)),
                        ),
                        const SizedBox(height: 4),
                        Text(info.desc, maxLines: 2, style: bodyStyle(21, Colors.white, FontWeight.w700)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(stats, style: bodyStyle(19, Colors.white, FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 92,
                    height: 92,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(enabled ? '▶️' : '🔒', style: const TextStyle(fontSize: 44)),
                  ),
                ]),
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
