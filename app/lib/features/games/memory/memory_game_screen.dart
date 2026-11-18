import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game_timer.dart';
import '../../../core/local_store.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/owl_view.dart';
import '../../tutor/widgets/celebration_overlay.dart';
import '../game_session.dart';
import 'memory_logic.dart';

/// 🃏 Lật Thẻ Trí Nhớ: lật 2 thẻ để tìm cặp – hình ↔ chữ, hình ↔ tiếng Anh, phép tính ↔ kết quả.
/// Xong bàn được sao ⭐ theo số lượt lật; bàn sau nhiều thẻ hơn.
class MemoryGameScreen extends ConsumerStatefulWidget {
  const MemoryGameScreen({super.key});

  @override
  ConsumerState<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends ConsumerState<MemoryGameScreen> with GameSession<MemoryGameScreen> {
  final _rnd = math.Random();
  late final LocalStore _store = ref.read(localStoreProvider);

  List<MemCard> _cards = [];
  int? _first;
  bool _lock = false;
  int _moves = 0;
  int _level = 1;
  int _grade = 1;
  int _score = 0;
  int _best = 0;
  String _childId = '';
  String _mood = 'idle';
  String _say = '';
  bool _done = false;
  int _stars = 0;
  int _celebrate = 0;
  String _celebrateText = '';
  bool _c = false;

  @override
  String get musicTrack => 'memory';

  int get _pairs => _cards.length ~/ 2;
  int get _matched => _cards.where((c) => c.matched).length ~/ 2;

  @override
  void initState() {
    super.initState();
    final child = ref.read(activeChildProvider);
    _childId = child?.id ?? '';
    _grade = child?.grade ?? 1;
    _level = _childId.isEmpty ? 1 : _store.gameLevel(_childId, 'memory');
    _best = _childId.isEmpty ? 0 : _store.gameBest(_childId, 'memory');
    _newBoard();
    startGameSession();
  }

  @override
  void onGameStop() => _saveBest();

  @override
  void dispose() {
    _saveBest();
    endGameSession();
    super.dispose();
  }

  void _saveBest() {
    if (_childId.isEmpty || _score <= 0) return;
    _store.submitGameBest(_childId, 'memory', _score);
    if (_score > _best) _best = _score;
  }

  void _newBoard() {
    final theme = themeFor(_grade, _level);
    setState(() {
      _cards = makeBoard(grade: _grade, level: _level, rnd: _rnd);
      _first = null;
      _lock = false;
      _moves = 0;
      _done = false;
      _stars = 0;
      _mood = 'idle';
      _say = 'Bàn ${_level}: ${themeTitle(theme)}. Lật 2 thẻ để tìm cặp nhé!';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ttsProvider).say(_say);
    });
  }

  Future<void> _flip(int i) async {
    final card = _cards[i];
    if (_lock || _done || card.open || card.matched) return;
    ref.read(soundProvider).pop();
    setState(() => card.open = true);
    if (card.speak.isNotEmpty) ref.read(ttsProvider).say(card.speak);
    final first = _first;
    if (first == null) {
      _first = i;
      return;
    }
    _first = null;
    _moves++;
    final a = _cards[first];
    if (a.pair == card.pair) {
      setState(() {
        a.matched = true;
        card.matched = true;
        _mood = 'celebrating';
        _say = 'Đúng cặp rồi! +10';
      });
      _score += 10;
      ref.read(soundProvider).ting();
      await _addPoints(10);
      if (_matched == _pairs) await _finish();
      return;
    }
    _lock = true;
    setState(() {
      _mood = 'thinking';
      _say = 'Chưa đúng cặp. Nhớ vị trí rồi thử lại nhé!';
    });
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    ref.read(soundProvider).oops();
    setState(() {
      a.open = false;
      card.open = false;
      _lock = false;
    });
  }

  Future<void> _finish() async {
    final stars = starsFor(_pairs, _moves);
    final bonus = 10 * stars;
    _score += bonus;
    setState(() {
      _done = true;
      _stars = stars;
      _mood = 'celebrating';
      _celebrateText = '${'⭐' * stars} Xong bàn!';
      _celebrate++;
    });
    ref.read(soundProvider).tada();
    await _addPoints(bonus);
    _level++;
    if (_childId.isNotEmpty) await _store.setGameLevel(_childId, 'memory', _level);
    _saveBest();
    if (stars == 3) {
      parentVoiceOrSay(ref, 'praise', 'Tuyệt vời! Bạn nhớ giỏi quá, được ba ngôi sao!');
    } else {
      ref.read(ttsProvider).say('Xong bàn rồi! Bạn được $stars ngôi sao. Thưởng $bonus điểm!');
    }
  }

  Future<void> _addPoints(int pts) async {
    final goal = await ref.read(gamePointsProvider.notifier).add(pts);
    if (goal && mounted) {
      setState(() {
        _celebrateText = '🎁 Đạt mục tiêu hôm nay!';
        _celebrate++;
      });
      parentVoiceOrSay(ref, 'praise', 'Bạn đạt mục tiêu hôm nay rồi! Chơi xong nhớ viết điều ước gửi bố mẹ nhé!');
    }
  }

  // ------------------------------------------------------------------ giao diện
  @override
  Widget build(BuildContext context) {
    _c = isCompact(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3ECFF), Color(0xFFFFF4E0)],
          ),
        ),
        child: SafeArea(
          child: Stack(children: [
            Column(children: [
              GameTopBar(title: '🃏 Lật Thẻ Trí Nhớ', onBack: leaveGame),
              Expanded(
                child: Row(children: [
                  SizedBox(width: _c ? 180 : 240, child: _side()),
                  Expanded(child: _grid()),
                ]),
              ),
            ]),
            Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: _celebrateText)),
            if (_done) Positioned(left: 0, right: 0, bottom: 16, child: Center(child: _doneBar())),
          ]),
        ),
      ),
    );
  }

  Widget _side() => Padding(
        padding: EdgeInsets.fromLTRB(_c ? 10 : 14, 4, 4, 10),
        child: Column(children: [
          OwlView(mood: _mood, size: _c ? 92 : 130),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Text(_say,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: bodyStyle(_c ? 16 : 19, AppColors.ink, FontWeight.w700)),
          ),
          SizedBox(height: _c ? 8 : 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bàn $_level', style: titleStyle(_c ? 24 : 30, const Color(0xFF7A5CFF))),
              Text(themeTitle(themeFor(_grade, _level)), style: bodyStyle(_c ? 14 : 17)),
              const SizedBox(height: 4),
              Text('Cặp: $_matched/$_pairs', style: bodyStyle(_c ? 16 : 19, AppColors.ink, FontWeight.w800)),
              Text('Lượt lật: $_moves', style: bodyStyle(_c ? 16 : 19, AppColors.ink, FontWeight.w800)),
              Text('⭐⭐⭐ nếu ≤ ${_pairs + 2} lượt', style: bodyStyle(_c ? 13 : 16, Colors.grey.shade700)),
              Text('Điểm: $_score · Kỷ lục ${math.max(_best, _score)}', style: bodyStyle(_c ? 14 : 17)),
            ]),
          ),
        ]),
      );

  Widget _grid() => LayoutBuilder(builder: (context, box) {
        final cols = columnsFor(_pairs);
        final rows = (_cards.length / cols).ceil();
        final gap = _c ? 8.0 : 12.0;
        final pad = _c ? 10.0 : 16.0;
        var w = (box.maxWidth - 2 * pad - gap * (cols - 1)) / cols;
        var h = (box.maxHeight - 2 * pad - gap * (rows - 1) - (_done ? 90 : 0)) / rows;
        w = math.min(w, h * 1.25);
        h = math.min(h, w * 1.1);
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : gap),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var c = 0; c < cols; c++)
                        if (r * cols + c < _cards.length)
                          Padding(
                            padding: EdgeInsets.only(right: c == cols - 1 ? 0 : gap),
                            child: _FlipCard(
                              card: _cards[r * cols + c],
                              width: w,
                              height: h,
                              onTap: () => _flip(r * cols + c),
                            ),
                          ),
                    ],
                  ),
                ),
            ],
          ),
        );
      });

  Widget _doneBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.sun, width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${'⭐' * _stars}${'☆' * (3 - _stars)}  $_moves lượt', style: titleStyle(_c ? 24 : 30)),
          const SizedBox(width: 16),
          ElevatedButton(onPressed: _newBoard, child: Text('▶️ Bàn $_level')),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: leaveGame, child: const Text('🏠')),
        ]),
      );
}

/// Thẻ lật 3D: mặt sau có Cú, mặt trước là hình / chữ / phép tính.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.width, required this.height, required this.onTap});
  final MemCard card;
  final double width, height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = card.open || card.matched;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        builder: (context, v, _) {
          final angle = v * math.pi;
          final front = angle > math.pi / 2;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angle),
            child: front
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _front(),
                  )
                : _back(),
          );
        },
      ),
    );
  }

  Widget _back() => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB08CFF), Color(0xFF5EB8FF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 3))
          ],
        ),
        child: Stack(alignment: Alignment.center, children: [
          Positioned(
              left: 8, top: 6, child: Text('✦', style: TextStyle(color: Colors.white70, fontSize: height * 0.12))),
          Positioned(
              right: 10, bottom: 6, child: Text('✦', style: TextStyle(color: Colors.white70, fontSize: height * 0.1))),
          Text('🦉', style: TextStyle(fontSize: math.min(width, height) * 0.42)),
        ]),
      );

  Widget _front() => Container(
        width: width,
        height: height,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: card.matched ? const Color(0xFFE6F9EE) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: card.matched ? AppColors.success : AppColors.sun, width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              card.face,
              textAlign: TextAlign.center,
              style: card.picture
                  ? TextStyle(fontSize: math.min(width, height) * 0.55)
                  : titleStyle(math.min(width * 0.22, height * 0.3), AppColors.ink),
            ),
          ),
        ),
      );
}
