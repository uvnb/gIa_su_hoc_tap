import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/sky_background.dart';
import '../tutor/widgets/celebration_overlay.dart';
import 'english_content.dart';
import 'english_progress.dart';

/// Một chủ đề tiếng Anh với 4 cách học: 📖 Học từ · 👂 Nghe chọn · 🔤 Ghép chữ · 🗣️ Nói to.
/// Tính vào thời gian HỌC (mở khóa Góc trò chơi nếu bố mẹ đặt "phải học trước").
class EnglishTopicScreen extends ConsumerStatefulWidget {
  const EnglishTopicScreen({super.key, required this.topicId});
  final String topicId;

  @override
  ConsumerState<EnglishTopicScreen> createState() => _EnglishTopicScreenState();
}

class _EnglishTopicScreenState extends ConsumerState<EnglishTopicScreen> {
  late final EnTopic topic = topicById(widget.topicId);
  late final StudyTimer _timer;
  String _mode = 'learn';
  int _celebrate = 0;
  String _celebrateText = '';

  List<(String, String, String)> get _modes => [
        ('learn', '📖', 'Học từ'),
        ('listen', '👂', 'Nghe chọn'),
        if (!topic.phrases) ('spell', '🔤', 'Ghép chữ'),
        ('speak', '🗣️', 'Nói to'),
      ];

  @override
  void initState() {
    super.initState();
    _timer = ref.read(studyTimerProvider.notifier);
    _timer.enter();
  }

  @override
  void dispose() {
    _timer.leave();
    super.dispose();
  }

  /// Một lượt chơi xong: lưu tiến độ, cộng sao nỗ lực, pháo giấy.
  Future<void> _roundDone(String mode, double score) async {
    final child = ref.read(activeChildProvider);
    final store = ref.read(localStoreProvider);
    if (child != null) {
      final p = EnProgress.load(store, child.id, topic.id);
      await EnProgress.save(store, child.id, topic.id, p.withScore(mode, score));
    }
    final stars = score >= 0.9 ? 3 : (score >= 0.7 ? 2 : 1);
    await ref.read(profilesProvider.notifier).addStars(stars);
    if (!mounted) return;
    setState(() {
      _celebrateText = '${'⭐' * stars} Great job!';
      _celebrate++;
    });
    ref.read(soundProvider).tada();
    await ref.read(ttsProvider).sayEnglish(score >= 0.7 ? 'Great job!' : 'Good try!');
    await ref.read(ttsProvider).say(score >= 0.7
        ? 'Giỏi quá! Bạn được $stars ngôi sao!'
        : 'Bạn cố gắng lắm! Được $stars ngôi sao. Mình luyện thêm nhé!');
  }

  Future<void> _learnedAll(int n) async {
    final child = ref.read(activeChildProvider);
    final store = ref.read(localStoreProvider);
    if (child == null) return;
    final p = EnProgress.load(store, child.id, topic.id);
    if (p.learned < n) {
      await EnProgress.save(store, child.id, topic.id, p.withLearned(n));
      await ref.read(profilesProvider.notifier).addStars(1);
      if (!mounted) return;
      setState(() {
        _celebrateText = '📖 Học hết thẻ rồi! +1 ⭐';
        _celebrate++;
      });
      ref.read(soundProvider).ting();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final grade = ref.watch(activeChildProvider)?.grade ?? 1;
    return Scaffold(
      body: SkyBackground(
        theme: SkyTheme.ocean,
        child: SafeArea(
          child: Stack(children: [
            Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 8, compact ? 12 : 20, 4),
                child: Row(children: [
                  PressBounce(
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('← Đảo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(topic.emoji, style: TextStyle(fontSize: compact ? 30 : 36)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text('${topic.en} · ${topic.vi}',
                        overflow: TextOverflow.ellipsis, style: titleStyle(compact ? 24 : 30, const Color(0xFF1E6FB8))),
                  ),
                  const Spacer(),
                  for (final (id, emoji, label) in _modes)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: PressBounce(
                        child: ChoiceChip(
                          label: Text('$emoji $label',
                              style: bodyStyle(compact ? 15 : 18, AppColors.ink, FontWeight.w800)),
                          selected: _mode == id,
                          selectedColor: AppColors.sun,
                          backgroundColor: Colors.white,
                          onSelected: (_) {
                            ref.read(soundProvider).pop();
                            setState(() => _mode = id);
                          },
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(_mode),
                    child: switch (_mode) {
                      'listen' => _ListenView(topic: topic, onDone: (s) => _roundDone('listen', s)),
                      'spell' => _SpellView(topic: topic, grade: grade, onDone: (s) => _roundDone('spell', s)),
                      'speak' => _SpeakView(topic: topic, onDone: (s) => _roundDone('speak', s)),
                      _ => _LearnView(topic: topic, onLearnedAll: _learnedAll),
                    },
                  ),
                ),
              ),
            ]),
            Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: _celebrateText)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================ 📖 Học từ
class _LearnView extends ConsumerStatefulWidget {
  const _LearnView({required this.topic, required this.onLearnedAll});
  final EnTopic topic;
  final Future<void> Function(int n) onLearnedAll;

  @override
  ConsumerState<_LearnView> createState() => _LearnViewState();
}

class _LearnViewState extends ConsumerState<_LearnView> {
  late final PageController _pc = PageController(viewportFraction: 0.5);
  int _page = 0;
  final _seen = <int>{0};
  final _flipped = <int>{};
  final _spoken = <int>{};
  String _heard = '';

  List<EnWord> get words => widget.topic.words;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak(0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _speak(int i, {bool slow = false}) => ref.read(ttsProvider).sayEnglish(words[i].en, slow: slow);

  void _onPage(int i) {
    setState(() {
      _page = i;
      _seen.add(i);
      _heard = '';
    });
    _speak(i);
    if (_seen.length == words.length) widget.onLearnedAll(words.length);
  }

  void _go(int d) {
    final n = (_page + d).clamp(0, words.length - 1);
    _pc.animateToPage(n, duration: const Duration(milliseconds: 380), curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final w = words[_page];
    return Column(children: [
      Expanded(
        child: PageView.builder(
          controller: _pc,
          itemCount: words.length,
          onPageChanged: _onPage,
          itemBuilder: (_, i) => AnimatedBuilder(
            animation: _pc,
            builder: (_, child) {
              var d = 0.0;
              if (_pc.hasClients && _pc.position.haveDimensions) d = (_pc.page ?? 0) - i;
              final scale = (1 - d.abs() * 0.22).clamp(0.75, 1.0);
              return Transform.scale(
                  scale: scale, child: Opacity(opacity: (1 - d.abs() * 0.45).clamp(0.4, 1.0), child: child));
            },
            child: GestureDetector(
              onTap: () {
                ref.read(soundProvider).pop();
                setState(() => _flipped.contains(i) ? _flipped.remove(i) : _flipped.add(i));
                if (_flipped.contains(i)) ref.read(ttsProvider).say(words[i].vi);
              },
              child: _FlashCard(
                  word: words[i], flipped: _flipped.contains(i), done: _spoken.contains(i), compact: compact),
            ),
          ),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, compact ? 8 : 14),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _round('◀', () => _go(-1), enabled: _page > 0),
          const SizedBox(width: 10),
          _pill('🔊 Nghe', () => _speak(_page)),
          const SizedBox(width: 8),
          _pill('🐢 Chậm', () => _speak(_page, slow: true)),
          const SizedBox(width: 14),
          MicButton(
            size: compact ? 64 : 78,
            english: true,
            label: 'Giữ & nói theo',
            onFinal: (t) {
              setState(() => _heard = t);
              if (matchEnglish(t, w.en)) {
                setState(() => _spoken.add(_page));
                ref.read(soundProvider).ting();
                ref.read(ttsProvider).sayEnglish('Excellent!');
              } else if (t.isNotEmpty) {
                ref.read(soundProvider).oops();
                ref.read(ttsProvider).say('Gần đúng rồi! Nghe lại rồi nói theo nhé.');
              }
            },
          ),
          const SizedBox(width: 14),
          Text('${_page + 1}/${words.length}', style: titleStyle(compact ? 22 : 26)),
          const SizedBox(width: 10),
          _round('▶', () => _go(1), enabled: _page < words.length - 1),
        ]),
      ),
      if (_heard.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Cú nghe được: “$_heard”', style: bodyStyle(16, const Color(0xFF7A5CFF), FontWeight.w700)),
        ),
    ]);
  }

  Widget _round(String t, VoidCallback onTap, {bool enabled = true}) => PressBounce(
        enabled: enabled,
        child: Material(
          color: enabled ? Colors.white : Colors.white54,
          shape: const CircleBorder(),
          elevation: enabled ? 3 : 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(width: 60, height: 60, child: Center(child: Text(t, style: titleStyle(26, AppColors.sky)))),
          ),
        ),
      );

  Widget _pill(String t, VoidCallback onTap) => PressBounce(
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(t, style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
            ),
          ),
        ),
      );
}

/// Thẻ học từ – chạm để lật xem nghĩa tiếng Việt (lật 3D).
class _FlashCard extends StatelessWidget {
  const _FlashCard({required this.word, required this.flipped, required this.done, required this.compact});
  final EnWord word;
  final bool flipped;
  final bool done;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutBack,
      builder: (_, v, __) {
        final angle = v * math.pi;
        final back = angle > math.pi / 2;
        final face = Container(
          margin: EdgeInsets.symmetric(vertical: compact ? 6 : 14, horizontal: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: back ? const Color(0xFFFFF6D6) : Colors.white,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(
                color: done ? AppColors.success : (back ? AppColors.sun : const Color(0xFFBFE3FF)), width: 6),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 6))
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: back
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(word.emoji, style: const TextStyle(fontSize: 70)),
                    Text(word.vi, textAlign: TextAlign.center, style: titleStyle(44, AppColors.ink)),
                    if (word.hint.isNotEmpty)
                      Text('Đọc gần giống: “${word.hint}”',
                          style: bodyStyle(22, Colors.grey.shade700, FontWeight.w700)),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(word.emoji, style: const TextStyle(fontSize: 110)),
                    Text(word.en, textAlign: TextAlign.center, style: titleStyle(56, const Color(0xFF1E6FB8))),
                    Text(done ? '✅ Nói đúng rồi!' : 'Chạm để xem nghĩa',
                        style: bodyStyle(20, done ? AppColors.success : Colors.grey.shade600, FontWeight.w800)),
                  ]),
          ),
        );
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: back
              ? Transform(alignment: Alignment.center, transform: Matrix4.identity()..rotateY(math.pi), child: face)
              : face,
        );
      },
    );
  }
}

// ============================================================================ khung chung cho 1 lượt
/// Khung lượt chơi: thanh tiến độ + Cú + nội dung câu hỏi; hết câu thì gọi [onDone] với tỉ lệ đúng.
class _RoundFrame extends StatelessWidget {
  const _RoundFrame({required this.index, required this.total, required this.mood, required this.child});
  final int index, total;
  final String mood;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 4, compact ? 12 : 20, compact ? 8 : 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: compact ? 120 : 170,
          child: Column(children: [
            Bobbing(child: OwlView(mood: mood, size: compact ? 100 : 140)),
            const SizedBox(height: 8),
            Text('${math.min(index + 1, total)}/$total', style: titleStyle(compact ? 24 : 28)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: index / total,
                minHeight: 12,
                backgroundColor: Colors.white,
                color: AppColors.success,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.score, required this.onAgain});
  final double score;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final stars = score >= 0.9 ? 3 : (score >= 0.7 ? 2 : 1);
    return Center(
      child: PopIn(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(34),
            border: Border.all(color: AppColors.sun, width: 6),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${'⭐' * stars}${'☆' * (3 - stars)}', style: const TextStyle(fontSize: 52)),
            Text(score >= 0.7 ? 'Great job! 🎉' : 'Good try! 💪', style: titleStyle(36)),
            Text('Đúng ${(score * 100).round()}%', style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onAgain, child: const Text('🔄 Chơi lại')),
          ]),
        ),
      ),
    );
  }
}

List<EnWord> _pick(List<EnWord> src, int n, math.Random rnd) => ([...src]..shuffle(rnd)).take(n).toList();

// ============================================================================ 👂 Nghe chọn
class _ListenView extends ConsumerStatefulWidget {
  const _ListenView({required this.topic, required this.onDone});
  final EnTopic topic;
  final void Function(double score) onDone;

  @override
  ConsumerState<_ListenView> createState() => _ListenViewState();
}

class _ListenViewState extends ConsumerState<_ListenView> {
  final _rnd = math.Random();
  late List<EnWord> _qs;
  int _i = 0;
  int _firstTry = 0;
  final _wrong = <String>{};
  String? _right;
  late List<EnWord> _opts;
  bool _done = false;
  String _mood = 'asking';

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _qs = _pick(widget.topic.words, math.min(8, widget.topic.words.length), _rnd);
    _i = 0;
    _firstTry = 0;
    _done = false;
    _next();
  }

  void _next() {
    final q = _qs[_i];
    final others = widget.topic.words.where((w) => w.en != q.en && w.emoji != q.emoji).toList()..shuffle(_rnd);
    _opts = [q, ...others.take(3)]..shuffle(_rnd);
    _wrong.clear();
    _right = null;
    _mood = 'asking';
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsProvider).sayEnglish(q.en));
  }

  Future<void> _tap(EnWord w) async {
    final q = _qs[_i];
    if (_right != null || _wrong.contains(w.en)) return;
    if (w.en == q.en) {
      if (_wrong.isEmpty) _firstTry++;
      setState(() {
        _right = w.en;
        _mood = 'celebrating';
      });
      ref.read(soundProvider).ting();
      await ref.read(ttsProvider).sayEnglish(q.en);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      if (_i + 1 >= _qs.length) {
        setState(() => _done = true);
        widget.onDone(_firstTry / _qs.length);
      } else {
        _i++;
        _next();
      }
    } else {
      setState(() {
        _wrong.add(w.en);
        _mood = 'thinking';
      });
      ref.read(soundProvider).oops();
      ref.read(ttsProvider).sayEnglish(q.en);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _ResultCard(score: _firstTry / _qs.length, onAgain: () => setState(_start));
    final compact = isCompact(context);
    return _RoundFrame(
      index: _i,
      total: _qs.length,
      mood: _mood,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('👂 Nghe và chạm đúng hình', style: titleStyle(compact ? 24 : 30)),
          const SizedBox(width: 12),
          PressBounce(
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.sky),
              onPressed: () => ref.read(ttsProvider).sayEnglish(_qs[_i].en),
              icon: const Text('🔊', style: TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 6),
          PressBounce(
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () => ref.read(ttsProvider).sayEnglish(_qs[_i].en, slow: true),
              icon: const Text('🐢', style: TextStyle(fontSize: 30)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: compact ? 2.1 : 2.3,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var k = 0; k < _opts.length; k++)
                PopIn(
                  key: ValueKey('${_i}_$k'),
                  delay: 70 * k,
                  child: _OptionCard(
                    emoji: _opts[k].emoji,
                    // chủ đề có câu (chào hỏi…): hình dễ trùng → kèm nghĩa tiếng Việt
                    caption: widget.topic.words.any((w) => w.isPhrase) ? _opts[k].vi : '',
                    state: _right == _opts[k].en ? 1 : (_wrong.contains(_opts[k].en) ? 2 : 0),
                    onTap: () => _tap(_opts[k]),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.emoji, required this.caption, required this.state, required this.onTap});
  final String emoji, caption;
  final int state; // 0 thường · 1 đúng · 2 sai
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = state == 1 ? const Color(0xFFDDF7E8) : (state == 2 ? Colors.grey.shade200 : Colors.white);
    final border = state == 1 ? AppColors.success : (state == 2 ? Colors.grey.shade400 : const Color(0xFFBFE3FF));
    return PressBounce(
      enabled: state == 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border, width: 5),
          boxShadow: [
            if (state == 0)
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: state == 0 ? onTap : null,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(state == 2 ? '🤔' : emoji, style: const TextStyle(fontSize: 56)),
                    if (caption.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(caption, style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
                    ],
                    if (state == 1) const Text(' ✅', style: TextStyle(fontSize: 34)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================ 🔤 Ghép chữ
class _SpellView extends ConsumerStatefulWidget {
  const _SpellView({required this.topic, required this.grade, required this.onDone});
  final EnTopic topic;
  final int grade;
  final void Function(double score) onDone;

  @override
  ConsumerState<_SpellView> createState() => _SpellViewState();
}

class _SpellViewState extends ConsumerState<_SpellView> {
  final _rnd = math.Random();
  late List<EnWord> _qs;
  int _i = 0;
  int _clean = 0; // ghép đúng không cần gợi ý
  bool _usedHelp = false;
  late List<String> _tiles; // chữ cái trên khay
  late List<int?> _slots; // chỉ số tile đặt ở từng ô
  bool _done = false;
  bool _shake = false;
  String _mood = 'asking';

  EnWord get _q => _qs[_i];
  String get _target => _q.spell.replaceAll(' ', '');

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    var pool = widget.topic.words.where((w) => !w.isPhrase).toList();
    if (widget.grade <= 2) {
      final short = pool.where((w) => w.en.length <= 5).toList();
      if (short.length >= 4) pool = short;
    }
    _qs = _pick(pool, math.min(6, pool.length), _rnd);
    _i = 0;
    _clean = 0;
    _done = false;
    if (_qs.isEmpty) return;
    _next();
  }

  void _next() {
    final letters = _target.split('');
    if (widget.grade >= 3) {
      const abc = 'abcdefghijklmnoprstuwy';
      for (var k = 0; k < 2; k++) {
        letters.add(abc[_rnd.nextInt(abc.length)]);
      }
    }
    letters.shuffle(_rnd);
    _tiles = letters;
    _slots = List<int?>.filled(_target.length, null);
    _usedHelp = false;
    _mood = 'asking';
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsProvider).sayEnglish(_q.en));
  }

  bool _used(int tile) => _slots.contains(tile);

  void _tapTile(int k) {
    if (_used(k)) return;
    final free = _slots.indexOf(null);
    if (free < 0) return;
    ref.read(soundProvider).pop();
    setState(() => _slots[free] = k);
    if (!_slots.contains(null)) _check();
  }

  void _tapSlot(int s) {
    if (_slots[s] == null) return;
    setState(() => _slots[s] = null);
  }

  void _hint() {
    // đặt đúng chữ tiếp theo còn thiếu
    for (var s = 0; s < _slots.length; s++) {
      final want = _target[s];
      final cur = _slots[s];
      if (cur != null && _tiles[cur] == want) continue;
      final k = List.generate(_tiles.length, (i) => i)
          .firstWhere((i) => _tiles[i] == want && (!_used(i) || _slots[s] == i), orElse: () => -1);
      if (k < 0) return;
      _usedHelp = true;
      setState(() {
        final at = _slots.indexOf(k);
        if (at >= 0) _slots[at] = null;
        _slots[s] = k;
      });
      ref.read(ttsProvider).sayEnglish(want);
      if (!_slots.contains(null)) _check();
      return;
    }
  }

  Future<void> _check() async {
    final word = _slots.map((k) => _tiles[k!]).join();
    if (word == _target) {
      if (!_usedHelp) _clean++;
      setState(() => _mood = 'celebrating');
      ref.read(soundProvider).ting();
      await ref.read(ttsProvider).sayEnglish(_q.en);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (_i + 1 >= _qs.length) {
        setState(() => _done = true);
        widget.onDone(_clean / _qs.length);
      } else {
        _i++;
        _next();
      }
    } else {
      ref.read(soundProvider).oops();
      setState(() {
        _shake = true;
        _mood = 'thinking';
        // bỏ các chữ đặt sai, giữ chữ đúng
        for (var s = 0; s < _slots.length; s++) {
          if (_tiles[_slots[s]!] != _target[s]) _slots[s] = null;
        }
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _shake = false);
      });
      ref.read(ttsProvider).say('Gần đúng rồi! Các chữ đúng được giữ lại, bạn thử tiếp nhé.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_qs.isEmpty) return Center(child: Text('Chủ đề này học bằng câu, không có ghép chữ.', style: titleStyle(24)));
    if (_done) return _ResultCard(score: _clean / _qs.length, onAgain: () => setState(_start));
    final compact = isCompact(context);
    final slot = compact ? 56.0 : 66.0;
    return _RoundFrame(
      index: _i,
      total: _qs.length,
      mood: _mood,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Bobbing(child: Text(_q.emoji, style: TextStyle(fontSize: compact ? 56 : 72))),
          const SizedBox(width: 12),
          Text(_q.vi, style: titleStyle(compact ? 28 : 34)),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => ref.read(ttsProvider).sayEnglish(_q.en, slow: true),
            icon: const Text('🔊', style: TextStyle(fontSize: 30)),
          ),
        ]),
        const SizedBox(height: 8),
        // các ô chữ
        TweenAnimationBuilder<double>(
          tween: Tween(end: _shake ? 1 : 0),
          duration: const Duration(milliseconds: 300),
          builder: (_, v, child) =>
              Transform.translate(offset: Offset(math.sin(v * math.pi * 6) * 10, 0), child: child),
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (var s = 0; s < _slots.length; s++)
              GestureDetector(
                onTap: () => _tapSlot(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: slot,
                  height: slot,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _slots[s] == null ? Colors.white.withValues(alpha: 0.6) : AppColors.sun,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E6FB8), width: 3),
                  ),
                  child: Text(_slots[s] == null ? '' : _tiles[_slots[s]!], style: titleStyle(slot * 0.55)),
                ),
              ),
          ]),
        ),
        const Spacer(),
        // khay chữ cái
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var k = 0; k < _tiles.length; k++)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _used(k) ? 0.2 : 1,
              child: PressBounce(
                enabled: !_used(k),
                child: Material(
                  color: const Color(0xFF5EB8FF),
                  borderRadius: BorderRadius.circular(18),
                  elevation: _used(k) ? 0 : 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _tapTile(k),
                    child: SizedBox(
                      width: slot + 4,
                      height: slot + 4,
                      child: Center(child: Text(_tiles[k], style: titleStyle(slot * 0.6, Colors.white))),
                    ),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        TextButton(onPressed: _hint, child: const Text('💡 Gợi ý 1 chữ')),
      ]),
    );
  }
}

// ============================================================================ 🗣️ Nói to
class _SpeakView extends ConsumerStatefulWidget {
  const _SpeakView({required this.topic, required this.onDone});
  final EnTopic topic;
  final void Function(double score) onDone;

  @override
  ConsumerState<_SpeakView> createState() => _SpeakViewState();
}

class _SpeakViewState extends ConsumerState<_SpeakView> {
  final _rnd = math.Random();
  late List<EnWord> _qs;
  int _i = 0;
  int _ok = 0;
  int _tries = 0;
  String _heard = '';
  String _mood = 'listening';
  bool _done = false;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _qs = _pick(widget.topic.words, math.min(6, widget.topic.words.length), _rnd);
    _i = 0;
    _ok = 0;
    _done = false;
    _next();
  }

  void _next() {
    _tries = 0;
    _heard = '';
    _passed = false;
    _mood = 'listening';
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsProvider).sayEnglish(_qs[_i].en));
  }

  Future<void> _advance() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_i + 1 >= _qs.length) {
      setState(() => _done = true);
      widget.onDone(_ok / _qs.length);
    } else {
      _i++;
      _next();
    }
  }

  Future<void> _onHeard(String t) async {
    if (_passed) return;
    final q = _qs[_i];
    setState(() => _heard = t);
    if (t.isEmpty) {
      ref.read(ttsProvider).say('Cú chưa nghe rõ. Bạn giữ nút micro rồi nói to hơn nhé!');
      return;
    }
    _tries++;
    if (matchEnglish(t, q.en)) {
      _ok++;
      setState(() {
        _passed = true;
        _mood = 'celebrating';
      });
      ref.read(soundProvider).ting();
      await ref.read(ttsProvider).sayEnglish(_tries == 1 ? 'Perfect!' : 'Well done!');
      _advance();
    } else if (_tries >= 3) {
      setState(() {
        _passed = true;
        _mood = 'encouraging';
      });
      await ref.read(ttsProvider).say('Không sao! Nghe Cú đọc lại nhé.');
      await ref.read(ttsProvider).sayEnglish(q.en, slow: true);
      _advance();
    } else {
      setState(() => _mood = 'thinking');
      ref.read(soundProvider).oops();
      await ref.read(ttsProvider).say('Gần đúng rồi! Nghe lại rồi nói nhé.');
      await ref.read(ttsProvider).sayEnglish(q.en, slow: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _ResultCard(score: _ok / _qs.length, onAgain: () => setState(_start));
    final compact = isCompact(context);
    final q = _qs[_i];
    return _RoundFrame(
      index: _i,
      total: _qs.length,
      mood: _mood,
      child: Column(children: [
        Text('🗣️ Nghe Cú đọc rồi nói to theo', style: titleStyle(compact ? 24 : 30)),
        Expanded(
          child: Center(
            child: PopIn(
              key: ValueKey(_i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                decoration: BoxDecoration(
                  color: _passed ? const Color(0xFFDDF7E8) : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: _passed ? AppColors.success : const Color(0xFFBFE3FF), width: 5),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(q.emoji, style: TextStyle(fontSize: compact ? 64 : 84)),
                    Text(q.en,
                        textAlign: TextAlign.center, style: titleStyle(compact ? 42 : 52, const Color(0xFF1E6FB8))),
                    Text(q.vi, style: bodyStyle(compact ? 18 : 22, Colors.grey.shade700, FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          PressBounce(
            child: OutlinedButton(
              onPressed: () => ref.read(ttsProvider).sayEnglish(q.en),
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('🔊 Nghe mẫu'),
            ),
          ),
          const SizedBox(width: 20),
          MicButton(
            size: compact ? 72 : 88,
            english: true,
            label: 'Giữ để nói',
            enabled: !_passed,
            onFinal: _onHeard,
          ),
          const SizedBox(width: 20),
          Text('Lần thử: $_tries/3', style: bodyStyle(compact ? 16 : 19, AppColors.ink, FontWeight.w800)),
        ]),
        if (_heard.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Cú nghe được: “$_heard”', style: bodyStyle(16, const Color(0xFF7A5CFF), FontWeight.w700)),
          ),
      ]),
    );
  }
}
