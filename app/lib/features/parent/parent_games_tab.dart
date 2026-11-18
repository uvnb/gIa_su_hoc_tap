import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game_timer.dart';
import '../../core/local_store.dart';
import '../../core/providers.dart';
import '../../models/app_settings.dart';
import '../../models/child_profile.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../games/games_hub_screen.dart';

/// Góc phụ huynh → 🎮 Trò chơi: duyệt điều ước của bé, đặt giờ chơi mỗi ngày, xem điểm & cấp độ.
class ParentGamesTab extends ConsumerStatefulWidget {
  const ParentGamesTab({super.key});

  @override
  ConsumerState<ParentGamesTab> createState() => _ParentGamesTabState();
}

class _ParentGamesTabState extends ConsumerState<ParentGamesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(wishesProvider.notifier).reload());
  }

  Future<void> _save(AppSettings s) async {
    await ref.read(settingsProvider.notifier).save(s);
    ref.read(gameTimerProvider.notifier).refresh();
  }

  Future<void> _answer(Wish w, String status) async {
    final ctl = TextEditingController(text: w.reply);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'approved' ? '✅ Đồng ý điều ước' : '⏳ Hẹn bé dịp khác', style: titleStyle(26)),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${w.emoji} ${w.text}', style: bodyStyle(21)),
            const SizedBox(height: 12),
            TextField(
              controller: ctl,
              maxLength: 120,
              style: bodyStyle(19),
              decoration: InputDecoration(
                labelText: 'Nhắn lại cho bé (không bắt buộc) – Cú sẽ đọc cho bé nghe',
                hintText: status == 'approved' ? 'Cuối tuần mình đi ăn kem nhé!' : 'Tuần sau mình đi nhé con!',
              ),
            ),
            if (status == 'approved' && w.emoji == extraTimeWishEmoji)
              Text('Bé sẽ được cộng thêm 15 phút chơi hôm nay.', style: bodyStyle(17, AppColors.success)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi cho bé')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(wishesProvider.notifier).save(w.copyWith(status: status, reply: ctl.text.trim(), replySeen: false));
    if (status == 'approved' && w.emoji == extraTimeWishEmoji && w.day == LocalStore.dayKey(DateTime.now())) {
      await ref.read(localStoreProvider).addGameExtraMinutes(w.childId, 15);
      ref.read(gameTimerProvider.notifier).refresh();
    }
  }

  Widget _row(String label, Widget control, {String? note}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 330,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
              if (note != null) Text(note, style: bodyStyle(15, Colors.grey.shade700, FontWeight.w500)),
            ]),
          ),
          Expanded(child: control),
        ]),
      );

  Widget _choices<T>(T value, Map<T, String> options, ValueChanged<T> onChanged) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value, style: bodyStyle(18)),
              selected: e.key == value,
              onSelected: (_) => onChanged(e.key),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final wishes = ref.watch(wishesProvider);
    final profiles = ref.watch(profilesProvider).list;
    final active = ref.watch(activeChildProvider);
    final store = ref.read(localStoreProvider);
    ChildProfile? byId(String id) {
      for (final p in profiles) {
        if (p.id == id) return p;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ------------------------------------------------ điều ước
        Text('💌 Điều ước của bé', style: titleStyle(28)),
        Text(
            'Khi bé đạt ${s.gameDailyGoal} điểm trò chơi trong ngày, bé được tự viết một điều ước gửi bố mẹ. '
            'Bố mẹ đồng ý hoặc hẹn dịp khác, có thể nhắn lại – Cú sẽ đọc lời nhắn cho bé.',
            style: bodyStyle(17, Colors.grey.shade700, FontWeight.w500)),
        const SizedBox(height: 8),
        if (wishes.isEmpty)
          _card(Text('Chưa có điều ước nào.', style: bodyStyle(19)))
        else
          for (final w in wishes.take(30))
            _card(Row(children: [
              Text(w.emoji, style: const TextStyle(fontSize: 46)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.text, style: titleStyle(24)),
                  Text(
                      '${byId(w.childId)?.avatar ?? '👧'} ${byId(w.childId)?.nickname ?? 'Bé'} · ${w.day} · ${wishStatusLabel(w)}',
                      style: bodyStyle(17)),
                  if (w.reply.isNotEmpty) Text('Bố mẹ nhắn: “${w.reply}”', style: bodyStyle(17, const Color(0xFFE0457B))),
                ]),
              ),
              if (w.pending) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: () => _answer(w, 'approved'),
                  child: const Text('✅ Đồng ý'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => _answer(w, 'later'), child: const Text('⏳ Dịp khác')),
              ] else
                TextButton(
                  onPressed: () => _answer(w, w.status),
                  child: const Text('Sửa lời nhắn'),
                ),
              IconButton(
                tooltip: 'Xóa',
                onPressed: () => ref.read(wishesProvider.notifier).delete(w.id),
                icon: const Text('🗑️', style: TextStyle(fontSize: 24)),
              ),
            ])),
        const Divider(height: 36),

        // ------------------------------------------------ cài đặt giờ chơi
        Text('⏱️ Giờ chơi trò chơi', style: titleStyle(28)),
        _row('Cho phép chơi trò chơi', Align(
          alignment: Alignment.centerLeft,
          child: Switch(value: s.gamesEnabled, onChanged: (v) => _save(s.copyWith(gamesEnabled: v))),
        )),
        _row(
          'Thời gian chơi mỗi ngày',
          _choices<int>(s.gameMinutes, {15: '15 phút', 30: '30 phút', 45: '45 phút', 60: '1 tiếng', 90: '1,5 tiếng', 120: '2 tiếng'},
              (v) => _save(s.copyWith(gameMinutes: v))),
          note: 'Tính riêng, không trừ vào giờ học',
        ),
        _row(
          'Phải học trước khi chơi',
          _choices<int>(s.gameNeedStudyMinutes, {0: 'Không cần', 10: '10 phút', 20: '20 phút', 30: '30 phút'},
              (v) => _save(s.copyWith(gameNeedStudyMinutes: v))),
          note: 'Học đủ số phút với Cú trong ngày mới mở trò chơi',
        ),
        _row(
          'Điểm để mở điều ước',
          _choices<int>(s.gameDailyGoal, {150: '150', 300: '300', 500: '500', 800: '800'},
              (v) => _save(s.copyWith(gameDailyGoal: v))),
          note: 'Phần thưởng đặc biệt mỗi ngày',
        ),
        _row('Nhạc nền trò chơi', Align(
          alignment: Alignment.centerLeft,
          child: Switch(value: s.gameMusic, onChanged: (v) => _save(s.copyWith(gameMusic: v))),
        )),
        if (active != null)
          _row(
            'Cho ${active.nickname} thêm giờ hôm nay',
            Wrap(spacing: 10, children: [
              for (final m in const [15, 30])
                OutlinedButton(
                  onPressed: () async {
                    await ref.read(gameTimerProvider.notifier).grantExtra(m);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Đã cho ${active.nickname} thêm $m phút chơi hôm nay.')));
                    }
                  },
                  child: Text('+$m phút'),
                ),
            ]),
          ),
        const Divider(height: 36),

        // ------------------------------------------------ thống kê
        Text('📈 Hôm nay', style: titleStyle(28)),
        for (final p in profiles)
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p.avatar} ${p.nickname}', style: titleStyle(24)),
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _kpi('🎮', '${(store.gameSecondsToday(p.id) / 60).round()}/${s.gameMinutes + store.gameExtraMinutesToday(p.id)}′',
                  'phút chơi hôm nay'),
              _kpi('🏆', '${store.gamePointsToday(p.id)}', 'điểm hôm nay'),
              _kpi('💰', '${store.gamePointsTotal(p.id)}', 'tổng điểm'),
              _kpi('🧩', 'Cấp ${store.gameLevel(p.id, 'blocks')}', 'Xếp Khối Toán (kỷ lục ${store.gameBest(p.id, 'blocks')})'),
              _kpi('🦉', 'Cấp ${store.gameLevel(p.id, 'runner')}', 'Cú Từ Ngữ (kỷ lục ${store.gameBest(p.id, 'runner')})'),
            ]),
            const SizedBox(height: 10),
            Text('Phút chơi 7 ngày', style: bodyStyle(17, AppColors.ink, FontWeight.w800)),
            SizedBox(
              height: 90,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final e in store.lastWeekGameMinutes(p.id).entries)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${e.value}′', style: bodyStyle(14)),
                      Container(
                        height: (e.value.clamp(0, 120) / 120 * 50).toDouble() + 2,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: AppColors.success,
                      ),
                      Text(e.key.substring(5), style: bodyStyle(13)),
                    ]),
                  ),
              ]),
            ),
          ])),
      ],
    );
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );

  Widget _kpi(String emoji, String value, String label) => Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$emoji $value', style: titleStyle(26)),
          Text(label, style: bodyStyle(15)),
        ]),
      );
}
