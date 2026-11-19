import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/sky_background.dart';
import '../tutor/widgets/celebration_overlay.dart';
import 'vietnam_content.dart';

/// 🇻🇳 Đảo "Việt Nam quê em": Lịch sử · Địa lý · Văn hóa – Cú kể chuyện ngắn rồi đố bé.
/// Tính vào thời gian học; mỗi thẻ trả lời đúng lần đầu được 1 ⭐.
class VietnamIslandScreen extends ConsumerStatefulWidget {
  const VietnamIslandScreen({super.key, this.initialTopic = 'history'});
  final String initialTopic;

  @override
  ConsumerState<VietnamIslandScreen> createState() => _VietnamIslandScreenState();
}

class _VietnamIslandScreenState extends ConsumerState<VietnamIslandScreen> {
  late String _topic = widget.initialTopic;
  late final StudyTimer _timer;
  int _celebrate = 0;

  @override
  void initState() {
    super.initState();
    _timer = ref.read(studyTimerProvider.notifier);
    _timer.enter();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(ttsProvider).say('Chào mừng bạn đến đảo Việt Nam quê em! Chọn một thẻ để Cú kể chuyện nhé.'));
  }

  @override
  void dispose() {
    _timer.leave();
    super.dispose();
  }

  String _key(String cardId) => 'vn|${ref.read(activeChildProvider)?.id ?? ''}|$cardId';
  bool _done(String cardId) => ref.read(localStoreProvider).metaString(_key(cardId)) != null;

  Future<void> _open(VnCard card) async {
    ref.read(soundProvider).pop();
    final correct = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StoryDialog(card: card),
    );
    if (correct == true && !_done(card.id)) {
      await ref.read(localStoreProvider).setMeta(_key(card.id), '1');
      await ref.read(profilesProvider.notifier).addStars(1);
      if (mounted) setState(() => _celebrate++);
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final child = ref.watch(activeChildProvider);
    final topic = vnTopics.firstWhere((t) => t.id == _topic);
    final doneCount = topic.cards.where((c) => _done(c.id)).length;
    return Scaffold(
      body: SkyBackground(
        theme: SkyTheme.morning,
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 14 : 22, 8, compact ? 14 : 22, 10),
              child: Column(children: [
                Row(children: [
                  PressBounce(
                    child: OutlinedButton(
                      onPressed: () => context.go('/home'),
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('← Về nhà'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(compact ? '🇻🇳 Việt Nam' : '🇻🇳 Việt Nam quê em',
                          style: titleStyle(compact ? 28 : 36, const Color(0xFFD62828))),
                    ),
                  ),
                  for (final t in vnTopics)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: PressBounce(
                        child: ChoiceChip(
                          label: Text('${t.emoji} ${t.title}',
                              style: bodyStyle(compact ? 16 : 19, AppColors.ink, FontWeight.w800)),
                          selected: _topic == t.id,
                          selectedColor: AppColors.sun,
                          backgroundColor: Colors.white,
                          onSelected: (_) {
                            ref.read(soundProvider).pop();
                            setState(() => _topic = t.id);
                            ref.read(ttsProvider).say('${t.title}: ${t.subtitle}');
                          },
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  if (child != null) StarBadge(stars: child.stars),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: compact ? 190 : 250,
                      child: Column(children: [
                        Bobbing(child: OwlView(mood: 'asking', size: compact ? 110 : 150)),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                          child: Column(children: [
                            Text('${topic.emoji} ${topic.title}', style: titleStyle(compact ? 24 : 28)),
                            Text(topic.subtitle, style: bodyStyle(compact ? 15 : 18)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: doneCount / topic.cards.length,
                                minHeight: 12,
                                backgroundColor: AppColors.softSky,
                                color: AppColors.success,
                              ),
                            ),
                            Text('Đã học $doneCount/${topic.cards.length} thẻ', style: bodyStyle(compact ? 14 : 16)),
                          ]),
                        ),
                        const Spacer(),
                        PressBounce(
                          child: Material(
                            color: AppColors.sky,
                            borderRadius: BorderRadius.circular(22),
                            elevation: 3,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => context.push('/ask', extra: 'vietnam'),
                              child: SizedBox(
                                width: double.infinity,
                                height: 64,
                                child: Center(
                                  child: Text('🎤 Hỏi Cú về Việt Nam',
                                      style: bodyStyle(compact ? 16 : 18, Colors.white, FontWeight.w800)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                    SizedBox(width: compact ? 12 : 18),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: compact ? 3 : 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.25,
                        ),
                        itemCount: topic.cards.length,
                        itemBuilder: (_, i) {
                          final c = topic.cards[i];
                          return PopIn(
                            key: ValueKey('${_topic}_$i'),
                            delay: 50 * i,
                            child: _CardTile(card: c, done: _done(c.id), index: i, onTap: () => _open(c)),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
            Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: '⭐ Giỏi quá! +1 sao')),
          ]),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.card, required this.done, required this.index, required this.onTap});
  final VnCard card;
  final bool done;
  final int index;
  final VoidCallback onTap;

  static const _colors = [
    [Color(0xFFFFF1D6), Color(0xFFFFD9A0)],
    [Color(0xFFE3F4FF), Color(0xFFBDE3FF)],
    [Color(0xFFFFE6EE), Color(0xFFFFC2D6)],
    [Color(0xFFE6F9EE), Color(0xFFB9EDCF)],
  ];

  @override
  Widget build(BuildContext context) {
    final c = _colors[index % _colors.length];
    return PressBounce(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c),
              border: Border.all(color: done ? AppColors.success : Colors.white, width: 4),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Bobbing(
                        phase: index * 0.13,
                        amplitude: 3,
                        child: Text(card.emoji, style: const TextStyle(fontSize: 48))),
                    SizedBox(
                      width: 190,
                      child: Text(card.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: bodyStyle(19, AppColors.ink, FontWeight.w800)),
                    ),
                  ]),
                ),
              ),
              if (done) const Positioned(right: 8, top: 6, child: Text('⭐', style: TextStyle(fontSize: 22))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Cú kể chuyện (đọc to) → câu đố. Trả về true nếu bé trả lời đúng.
class _StoryDialog extends ConsumerStatefulWidget {
  const _StoryDialog({required this.card});
  final VnCard card;

  @override
  ConsumerState<_StoryDialog> createState() => _StoryDialogState();
}

class _StoryDialogState extends ConsumerState<_StoryDialog> {
  bool _quiz = false;
  final _wrong = <String>{};
  String? _right;
  late final List<String> _opts = [...widget.card.options]..shuffle(math.Random());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  Future<void> _read() => ref.read(ttsProvider).say('${widget.card.title}. ${widget.card.story}');

  void _toQuiz() {
    setState(() => _quiz = true);
    ref.read(ttsProvider).say('Cú đố bạn nhé: ${widget.card.question}');
  }

  Future<void> _pick(String o) async {
    if (_right != null || _wrong.contains(o)) return;
    if (o == widget.card.answer) {
      setState(() => _right = o);
      ref.read(soundProvider).ting();
      await ref.read(ttsProvider).say('Đúng rồi! ${widget.card.fact}');
      if (mounted) Navigator.of(context).pop(_wrong.isEmpty);
    } else {
      setState(() => _wrong.add(o));
      ref.read(soundProvider).oops();
      ref.read(ttsProvider).say('Chưa đúng rồi. Bạn nghe lại câu chuyện rồi thử tiếp nhé!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final compact = isCompact(context);
    return Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 18 : 26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(c.emoji, style: TextStyle(fontSize: compact ? 44 : 56)),
              const SizedBox(width: 12),
              Expanded(child: Text(c.title, style: titleStyle(compact ? 28 : 34))),
              IconButton(onPressed: _read, icon: const Text('🔊', style: TextStyle(fontSize: 30))),
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Đóng')),
            ]),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !_quiz
                  ? Column(key: const ValueKey('story'), children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        child: Text(c.story, style: bodyStyle(compact ? 20 : 23, AppColors.ink, FontWeight.w600)),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(onPressed: _toQuiz, child: const Text('🦉 Cú đố bạn nè!')),
                    ])
                  : Column(key: const ValueKey('quiz'), children: [
                      Text(c.question, textAlign: TextAlign.center, style: titleStyle(compact ? 26 : 30)),
                      const SizedBox(height: 14),
                      for (final o in _opts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: PressBounce(
                            enabled: !_wrong.contains(o) && _right == null,
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _right == o
                                      ? AppColors.success
                                      : (_wrong.contains(o) ? Colors.grey.shade300 : AppColors.sky),
                                ),
                                onPressed: () => _pick(o),
                                child: Text(_right == o ? '✅ $o' : (_wrong.contains(o) ? '🤔 $o' : o)),
                              ),
                            ),
                          ),
                        ),
                      if (_wrong.isNotEmpty && _right == null)
                        TextButton(
                          onPressed: () => setState(() => _quiz = false),
                          child: const Text('📖 Nghe lại câu chuyện'),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}
