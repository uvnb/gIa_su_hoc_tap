import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/game_timer.dart';
import '../../core/local_store.dart';
import '../../core/providers.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';
import '../tutor/widgets/celebration_overlay.dart';

/// 🎁 Phần thưởng đặc biệt: bé đạt mục tiêu điểm trong ngày → tự viết (hoặc nói) điều ước gửi bố mẹ.
/// Bố mẹ xem và trả lời trong Góc phụ huynh → thẻ "Trò chơi".
class WishScreen extends ConsumerStatefulWidget {
  const WishScreen({super.key});

  @override
  ConsumerState<WishScreen> createState() => _WishScreenState();
}

class _WishScreenState extends ConsumerState<WishScreen> {
  final _text = TextEditingController();
  String _emoji = '🎁';
  bool _sent = false;
  int _celebrate = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsProvider).say('Hôm nay bạn giỏi quá! Bạn muốn bố mẹ thưởng gì? Chọn hình hoặc tự viết nhé!');
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pick(WishSticker s) {
    ref.read(soundProvider).pop();
    final cur = _text.text.trim();
    final isStickerText = cur.isEmpty || wishStickers.any((w) => w.label == cur);
    setState(() {
      _emoji = s.emoji;
      if (isStickerText) _text.text = s.label;
    });
    ref.read(ttsProvider).say(s.label);
  }

  Future<void> _send() async {
    final child = ref.read(activeChildProvider);
    final text = _text.text.trim();
    if (child == null || _sent) return;
    if (text.isEmpty) {
      ref.read(ttsProvider).say('Bạn chọn một hình, hoặc viết điều ước vào ô nhé!');
      return;
    }
    setState(() {
      _sent = true;
      _celebrate++;
    });
    final w = Wish(
      id: const Uuid().v4(),
      childId: child.id,
      day: LocalStore.dayKey(DateTime.now()),
      emoji: _emoji,
      text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await ref.read(wishesProvider.notifier).save(w);
    ref.read(soundProvider).tada();
    await ref.read(ttsProvider).say('Cú đã gửi điều ước tới bố mẹ rồi! Chờ bố mẹ trả lời nhé!');
    if (mounted) context.go('/games');
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final store = ref.read(localStoreProvider);
    final pts = ref.watch(gamePointsProvider);
    final goal = ref.watch(settingsProvider.select((s) => s.gameDailyGoal));
    final already = child == null ? null : store.wishToday(child.id);
    final allowed = child != null && pts.today >= goal && (already == null || _sent);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F7),
      body: SafeArea(
        child: Stack(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
            child: Column(children: [
              Row(children: [
                OutlinedButton(
                  onPressed: () => context.go('/games'),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                  child: const Text('← Góc trò chơi'),
                ),
                const SizedBox(width: 16),
                Text('🎁 Điều ước gửi bố mẹ', style: titleStyle(36, const Color(0xFFE0457B))),
              ]),
              const SizedBox(height: 10),
              Expanded(
                child: !allowed
                    ? Center(
                        child: Text(
                          already != null
                              ? 'Hôm nay bạn đã gửi điều ước rồi. Mai mình viết tiếp nhé! 💌'
                              : 'Đạt $goal điểm trò chơi trong ngày để mở điều ước nhé!',
                          style: titleStyle(30),
                        ),
                      )
                    : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(
                          width: 260,
                          child: Column(children: [
                            const OwlView(mood: 'celebrating', size: 200),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
                              child: Text('Hôm nay bạn giỏi quá! Bạn muốn bố mẹ thưởng gì?',
                                  style: bodyStyle(21, AppColors.ink, FontWeight.w700)),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 20),
                        Expanded(child: _form()),
                      ]),
              ),
            ]),
          ),
          Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: 'Đã gửi bố mẹ! 💌')),
        ]),
      ),
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('1️⃣ Chọn một hình', style: titleStyle(26)),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final s in wishStickers)
            GestureDetector(
              onTap: () => _pick(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 196,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                decoration: BoxDecoration(
                  color: _emoji == s.emoji ? AppColors.sun : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _emoji == s.emoji ? AppColors.orange : const Color(0xFFFFC2D6), width: 3),
                ),
                child: Column(children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 46)),
                  Text(s.label.replaceFirst('Con muốn ', ''),
                      textAlign: TextAlign.center, maxLines: 2, style: bodyStyle(17, AppColors.ink, FontWeight.w800)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        Text('2️⃣ Viết hoặc nói điều ước của bạn', style: titleStyle(26)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: TextField(
              controller: _text,
              maxLines: 2,
              maxLength: 120,
              style: titleStyle(28),
              decoration: InputDecoration(hintText: 'Con muốn…', hintStyle: titleStyle(28, Colors.grey.shade400)),
            ),
          ),
          const SizedBox(width: 12),
          MicButton(
            size: 84,
            label: 'Giữ để nói',
            onFinal: (t) {
              if (t.isEmpty) return;
              final cur = _text.text.trim();
              final isStickerText = cur.isEmpty || wishStickers.any((w) => w.label == cur);
              setState(() => _text.text = isStickerText ? t : '$cur $t');
            },
          ),
        ]),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: _sent ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0457B), minimumSize: const Size(300, 84)),
            child: Text(_sent ? 'Đã gửi 💌' : '📨 Gửi bố mẹ', style: titleStyle(30, Colors.white)),
          ),
        ),
      ]),
    );
  }
}
