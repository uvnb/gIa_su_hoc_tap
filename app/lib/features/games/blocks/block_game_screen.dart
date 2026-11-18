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
import 'block_logic.dart';
import 'block_math.dart';

/// Màu kẹo ngọt cho khối.
const candyColors = [
  Color(0xFFFF8FB1), // hồng
  Color(0xFFFFB547), // cam
  Color(0xFFFFD84D), // vàng
  Color(0xFF6BD49A), // xanh lá
  Color(0xFF5EB8FF), // xanh trời
  Color(0xFFB08CFF), // tím
  Color(0xFF4FD1C5), // ngọc
  Color(0xFFFF7A6B), // san hô
];

/// 🧩 Xếp Khối Toán: kéo khối vào bảng 8×8, xếp đầy hàng ngang/dọc để nổ hàng.
/// Khối bí ẩn 🔒 cần giải đố toán mới dùng được – khi nổ, ô có sao ⭐ nhân đôi điểm.
class BlockGameScreen extends ConsumerStatefulWidget {
  const BlockGameScreen({super.key});

  @override
  ConsumerState<BlockGameScreen> createState() => _BlockGameScreenState();
}

class _BlockGameScreenState extends ConsumerState<BlockGameScreen>
    with TickerProviderStateMixin, GameSession<BlockGameScreen> {
  static const _pad = 10.0; // lề trong của bảng

  late BlockGame _game;
  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();
  final _clock = Stopwatch()..start();
  late final AnimationController _fx = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  // kéo thả
  int? _dragIdx;
  Offset _finger = Offset.zero;
  Offset _fingerStart = Offset.zero;
  Offset _pieceTopLeft = Offset.zero;
  (int, int)? _hover;
  List<int> _hlRows = const [], _hlCols = const [];
  double _cell = 70;

  // hiệu ứng
  final _bursts = <_Burst>[];
  final _floats = <_FloatText>[];

  String _owlSay = 'Kéo khối vào bảng nhé!';
  String _mood = 'idle';
  int _celebrate = 0;
  String _celebrateText = '';
  bool _busy = false; // đang chuyển cấp
  bool _over = false;
  int _best = 0;
  String _childId = '';
  late final LocalStore _store = ref.read(localStoreProvider); // giữ sẵn: không dùng ref trong dispose

  @override
  String get musicTrack => 'blocks';

  @override
  void initState() {
    super.initState();
    final child = ref.read(activeChildProvider);
    final store = _store;
    _childId = child?.id ?? '';
    final level = child == null ? 1 : store.gameLevel(child.id, 'blocks');
    _best = child == null ? 0 : store.gameBest(child.id, 'blocks');
    _game = BlockGame(grade: child?.grade ?? 1, level: level);
    startGameSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final first = store.metaString('blocks_intro') == null;
      if (first) store.setMeta('blocks_intro', '1');
      _say(first
          ? 'Kéo khối vào bảng. Xếp đầy một hàng ngang hoặc hàng dọc để nổ hàng nhé! Khối có ổ khóa thì giải đố để mở.'
          : 'Cấp ${_game.level}! Mình chơi nào!');
    });
  }

  @override
  void onGameStop() {
    _saveBest();
  }

  @override
  void dispose() {
    _saveBest();
    endGameSession();
    _fx.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _saveBest() {
    if (_childId.isEmpty || _game.runScore <= 0) return;
    _store.submitGameBest(_childId, 'blocks', _game.runScore);
    if (_game.runScore > _best) _best = _game.runScore;
  }

  void _say(String text, {bool speak = true}) {
    if (!mounted) return;
    setState(() => _owlSay = text);
    if (speak) ref.read(ttsProvider).say(text);
  }

  int get _now => _clock.elapsedMilliseconds;

  void _kickFx() {
    if (!_fx.isAnimating) _fx.repeat();
  }

  void _pruneFx() {
    final now = _now;
    _bursts.removeWhere((b) => now - b.start > 900);
    _floats.removeWhere((f) => now - f.start > 1400);
    if (_bursts.isEmpty && _floats.isEmpty && _fx.isAnimating) _fx.stop();
  }

  // ------------------------------------------------------------------ toạ độ
  RenderBox? get _stackBox => _stackKey.currentContext?.findRenderObject() as RenderBox?;

  Offset _toStack(Offset global) => _stackBox?.globalToLocal(global) ?? global;

  /// Góc trên trái ô (0,0) của bảng, theo toạ độ Stack.
  Offset _boardOrigin() {
    final b = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final s = _stackBox;
    if (b == null || s == null) return Offset.zero;
    return b.localToGlobal(const Offset(_pad, _pad), ancestor: s);
  }

  // ------------------------------------------------------------------ kéo thả
  void _dragStart(int i, Offset global) {
    final p = _game.tray[i];
    if (p == null || p.locked || _busy || _over) return;
    ref.read(soundProvider).pop();
    setState(() {
      _dragIdx = i;
      _finger = _toStack(global);
      _fingerStart = _finger;
      _updateHover();
    });
  }

  void _dragUpdate(Offset global) {
    if (_dragIdx == null) return;
    setState(() {
      _finger = _toStack(global);
      _updateHover();
    });
  }

  void _updateHover() {
    final p = _game.tray[_dragIdx!];
    if (p == null) return;
    final s = p.shape;
    // Khối nổi phía trên ngón tay để bé nhìn thấy chỗ đặt.
    _pieceTopLeft = _finger - Offset(s.cols * _cell / 2, s.rows * _cell / 2 + _cell * 0.9);
    final o = _boardOrigin();
    final fr = (_pieceTopLeft.dy - o.dy) / _cell, fc = (_pieceTopLeft.dx - o.dx) / _cell;
    // Thử ô gần nhất và các ô kề (dung sai cho tay bé).
    final cands = <(int, int)>{
      (fr.round(), fc.round()),
      (fr.floor(), fc.floor()),
      (fr.floor(), fc.ceil()),
      (fr.ceil(), fc.floor()),
      (fr.ceil(), fc.ceil()),
    }.toList()
      ..sort((a, b) {
        double d((int, int) x) => math.pow(x.$1 - fr, 2) + math.pow(x.$2 - fc, 2).toDouble();
        return d(a).compareTo(d(b));
      });
    _hover = null;
    _hlRows = const [];
    _hlCols = const [];
    for (final (r, c) in cands) {
      if (math.pow(r - fr, 2) + math.pow(c - fc, 2) > 0.8) continue;
      if (_game.board.canPlace(s, r, c)) {
        _hover = (r, c);
        final (rows, cols) = _game.board.wouldClear(s, r, c);
        _hlRows = rows;
        _hlCols = cols;
        break;
      }
    }
  }

  Future<void> _dragEnd() async {
    final i = _dragIdx;
    final h = _hover;
    setState(() {
      _dragIdx = null;
      _hover = null;
      _hlRows = const [];
      _hlCols = const [];
    });
    if (i == null) return;
    if (h == null) {
      // chỉ chạm nhẹ (không kéo) thì im lặng; kéo mà thả sai chỗ thì "ơ" nhẹ
      if ((_finger - _fingerStart).distance > 30) ref.read(soundProvider).oops();
      return;
    }
    final out = _game.place(i, h.$1, h.$2);
    if (out == null) return;
    await _afterPlace(out, h);
  }

  Future<void> _afterPlace(PlaceOutcome out, (int, int) at) async {
    final sound = ref.read(soundProvider);
    final now = _now;
    _floats.add(_FloatText('+${out.placed}', Offset((at.$2 + 0.5) * _cell, (at.$1 + 0.3) * _cell), now,
        const Color(0xFF7A5CFF), 26));
    if (out.lines > 0) {
      sound.clear();
      for (final (r, c, cell) in out.cleared) {
        _bursts.add(_Burst(r, c, cell, now));
      }
      // phép tính hiện giữa vùng nổ
      final rs = out.rows.isNotEmpty ? out.rows : [for (final e in out.cleared) e.$1];
      final cs = out.cols.isNotEmpty ? out.cols : [for (final e in out.cleared) e.$2];
      final cy = rs.reduce((a, b) => a + b) / rs.length, cx = cs.reduce((a, b) => a + b) / cs.length;
      _floats.add(_FloatText('+${out.points - out.placed}  (${out.expression})',
          Offset((cx + 0.5) * _cell, (cy + 0.5) * _cell), now + 120, AppColors.orange, 34));
      final cheer = switch (out.lines) {
        1 => 'Bùm! Nổ 1 hàng!',
        2 => 'Tuyệt vời! Nổ 2 hàng cùng lúc!',
        _ => 'Siêu đỉnh! Nổ ${out.lines} hàng!',
      };
      _mood = 'celebrating';
      _say(out.starBonus ? '$cheer Có sao nên điểm nhân đôi!' : cheer, speak: out.lines >= 2 || out.starBonus);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _mood == 'celebrating') setState(() => _mood = 'idle');
      });
    } else {
      sound.pop();
    }
    _kickFx();
    setState(() {});
    await _addPoints(out.points);
    _checkProgress();
  }

  Future<void> _addPoints(int pts) async {
    final reachedGoal = await ref.read(gamePointsProvider.notifier).add(pts);
    if (reachedGoal && mounted) {
      setState(() {
        _celebrateText = '🎁 Đạt mục tiêu hôm nay!';
        _celebrate++;
      });
      ref.read(soundProvider).tada();
      parentVoiceOrSay(ref, 'praise',
          'Bạn đạt mục tiêu hôm nay rồi! Ra Góc trò chơi để viết điều ước gửi bố mẹ nhé!');
    }
  }

  void _checkProgress() {
    if (_game.levelDone) {
      _levelUp();
    } else if (_game.gameOver) {
      _gameOver();
    }
  }

  Future<void> _levelUp() async {
    _busy = true;
    final next = _game.level + 1;
    setState(() {
      _celebrateText = 'Lên cấp $next! 🎉';
      _celebrate++;
      _mood = 'celebrating';
    });
    ref.read(soundProvider).tada();
    if (_childId.isNotEmpty) await ref.read(localStoreProvider).setGameLevel(_childId, 'blocks', next);
    await ref.read(ttsProvider).say('Giỏi quá! Lên cấp $next rồi!');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _game.nextLevel();
    final news = switch (next) {
      2 => 'Có thêm khối chữ L và thanh dài!',
      3 => 'Có đá cản trên bảng rồi đấy! Nổ hàng để phá đá nhé.',
      4 => 'Khối to xuất hiện! Câu đố cũng khó hơn.',
      5 => 'Có khối dấu cộng và chữ L to!',
      6 => 'Mỗi lượt có hai khối bí ẩn!',
      _ => 'Cấp $next! Cố lên nào!',
    };
    setState(() {
      _busy = false;
      _mood = 'idle';
    });
    _say(news);
  }

  void _gameOver() {
    _saveBest();
    setState(() {
      _over = true;
      _mood = 'encouraging';
    });
    ref.read(soundProvider).bump();
    parentVoiceOrSay(ref, 'encourage', 'Hết chỗ đặt khối rồi! Không sao, mình chơi lại nhé!');
  }

  void _restart() {
    setState(() {
      _over = false;
      _mood = 'idle';
      _bursts.clear();
      _floats.clear();
      _game.restart();
    });
    _say('Chơi lại cấp ${_game.level} nào!');
  }

  // ------------------------------------------------------------------ khối bí ẩn
  Future<void> _ask(int i) async {
    final p = _game.tray[i];
    if (p == null || !p.locked || p.question == null || _busy || _over) return;
    ref.read(soundProvider).pop();
    final tries = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MathQuestionDialog(q: p.question!, shape: p.shape, color: candyColors[p.color]),
    );
    if (tries == null || !mounted) return;
    p.tries = tries;
    final bonus = _game.unlockBonus(tries);
    _game.unlock(i);
    ref.read(soundProvider).unlock();
    _say(tries <= 1 ? 'Đúng ngay lần đầu! Thưởng $bonus điểm!' : 'Bạn tự tìm ra rồi! Thưởng $bonus điểm!',
        speak: false);
    setState(() {});
    await _addPoints(bonus);
    _checkProgress();
  }

  void _howTo() {
    const text = 'Kéo khối vào bảng. Xếp đầy một hàng ngang hoặc hàng dọc thì hàng đó nổ. '
        'Nổ nhiều hàng cùng lúc được nhiều điểm hơn. Khối có ổ khóa: chạm vào và giải đố toán để mở. '
        'Khối đã mở có ngôi sao, khi nổ được nhân đôi điểm!';
    ref.read(ttsProvider).say(text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        title: Text('❓ Cách chơi', style: titleStyle(32)),
        content: SizedBox(
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final line in const [
              '👆 Kéo khối từ khay bên phải vào bảng.',
              '💥 Xếp đầy 1 hàng ngang hoặc dọc → hàng nổ, được 10 điểm.',
              '🔥 Nổ 2 hàng cùng lúc: 2 × 20 = 40 điểm!',
              '🔒 Khối có ổ khóa: chạm vào, giải đố toán để mở.',
              '⭐ Khối đã mở có sao: nổ hàng có sao → điểm × 2.',
              '🪨 Đá cản: nổ hàng có đá để phá đá.',
              '🏆 Đủ điểm thì lên cấp – khối to hơn, đố khó hơn!',
            ])
              Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(line, style: bodyStyle(21))),
          ]),
        ),
        actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chơi thôi!'))],
      ),
    );
  }

  // ------------------------------------------------------------------ giao diện
  @override
  Widget build(BuildContext context) {
    ref.watch(gameTimerProvider.select((s) => s.remainingSeconds ~/ 60)); // làm mới khi đổi phút
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBFE4FF), Color(0xFFFFEEF6)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            key: _stackKey,
            children: [
              const Positioned(left: 300, top: 60, child: _Cloud(size: 90)),
              const Positioned(right: 280, top: 110, child: _Cloud(size: 70)),
              const Positioned(left: 40, bottom: 30, child: _Cloud(size: 60)),
              Column(
                children: [
                  GameTopBar(title: '🧩 Xếp Khối Toán', onBack: leaveGame),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(width: 270, child: _sidePanel()),
                        Expanded(child: _boardArea()),
                        SizedBox(width: 250, child: _trayPanel()),
                      ],
                    ),
                  ),
                ],
              ),
              if (_dragIdx != null) _draggedPiece(),
              Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: _celebrateText)),
              if (_over) Positioned.fill(child: _gameOverCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sidePanel() {
    final cfg = _game.cfg;
    final progress = (_game.levelScore / cfg.target).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 14),
      child: Column(
        children: [
          OwlView(mood: _mood, size: 130),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Text(_owlSay, style: bodyStyle(19, AppColors.ink, FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cấp ${_game.level}', style: titleStyle(30, AppColors.sky)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 18,
                    backgroundColor: AppColors.softSky,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                    _game.levelDone
                        ? 'Lên cấp!'
                        : 'Còn ${cfg.target - _game.levelScore} điểm nữa lên cấp',
                    style: bodyStyle(17)),
                const SizedBox(height: 6),
                Text('Điểm ván này: ${_game.runScore}', style: bodyStyle(19, AppColors.ink, FontWeight.w800)),
                Text('Kỷ lục: ${math.max(_best, _game.runScore)}', style: bodyStyle(17)),
              ],
            ),
          ),
          const Spacer(),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _howTo,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  textStyle: bodyStyle(18, AppColors.ink, FontWeight.w800),
                ),
                child: const Text('❓ Cách chơi'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _restart,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  textStyle: bodyStyle(18, AppColors.ink, FontWeight.w800),
                ),
                child: const Text('🔄 Chơi lại'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _boardArea() {
    return LayoutBuilder(builder: (context, box) {
      final size = math.min(box.maxWidth - 20, box.maxHeight - 20).clamp(200.0, 2000.0).toDouble();
      _cell = (size - 2 * _pad) / BlockBoard.n;
      final dragging = _dragIdx == null ? null : _game.tray[_dragIdx!];
      return Center(
        child: SizedBox(
          key: _boardKey,
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _fx,
            builder: (_, __) {
              _pruneFx();
              return CustomPaint(
                painter: _BoardPainter(
                  board: _game.board,
                  cell: _cell,
                  pad: _pad,
                  ghost: dragging == null || _hover == null ? null : (dragging, _hover!),
                  hlRows: _hlRows,
                  hlCols: _hlCols,
                  bursts: _bursts,
                  floats: _floats,
                  now: _now,
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Widget _trayPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 14),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _traySlot(i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _traySlot(int i) {
    final p = _game.tray[i];
    final hidden = p == null || _dragIdx == i;
    final fits = p != null && _game.board.fitsAnywhere(p.shape);
    final body = LayoutBuilder(builder: (context, box) {
      if (hidden) return const SizedBox.expand();
      final s = p.shape;
      final c = math.min(40.0, math.min(box.maxWidth * 0.78 / s.cols, box.maxHeight * 0.7 / s.rows));
      Widget piece = CustomPaint(
        size: Size(s.cols * c, s.rows * c),
        painter: _PiecePainter(s, candyColors[p.color], c, star: p.star && !p.locked, dim: !fits && !p.locked),
      );
      if (p.locked) {
        piece = AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(opacity: 0.45, child: child),
              Transform.scale(
                scale: 1 + 0.08 * _pulse.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.think,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.think.withValues(alpha: 0.5), blurRadius: 10)],
                  ),
                  child: Text('🔒 ?', style: titleStyle(28, Colors.white)),
                ),
              ),
            ],
          ),
          child: piece,
        );
      }
      return Center(child: piece);
    });
    final locked = p != null && p.locked;
    return Material(
      color: locked ? const Color(0xFFF1EBFF) : Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(26),
      elevation: hidden ? 0 : 2,
      child: locked
          ? InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => _ask(i),
              child: Column(children: [
                Expanded(child: body),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('Chạm để giải đố', style: bodyStyle(16, const Color(0xFF7A5CFF), FontWeight.w800)),
                ),
              ]),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanDown: (d) => _dragStart(i, d.globalPosition),
              onPanUpdate: (d) => _dragUpdate(d.globalPosition),
              onPanEnd: (_) => _dragEnd(),
              onPanCancel: () => _dragEnd(),
              child: body,
            ),
    );
  }

  Widget _draggedPiece() {
    final p = _game.tray[_dragIdx!];
    if (p == null) return const SizedBox.shrink();
    final s = p.shape;
    return Positioned(
      left: _pieceTopLeft.dx,
      top: _pieceTopLeft.dy,
      child: IgnorePointer(
        child: Opacity(
          opacity: _hover == null ? 0.85 : 0.35, // có bóng trên bảng thì khối nổi mờ đi
          child: CustomPaint(
            size: Size(s.cols * _cell, s.rows * _cell),
            painter: _PiecePainter(s, candyColors[p.color], _cell, star: p.star),
          ),
        ),
      ),
    );
  }

  Widget _gameOverCard() {
    final best = math.max(_best, _game.runScore);
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.sun, width: 6),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const OwlView(mood: 'encouraging', size: 140),
          Text('Hết chỗ đặt khối rồi!', style: titleStyle(36)),
          const SizedBox(height: 8),
          Text('Ván này: ${_game.runScore} điểm · Kỷ lục: $best', style: bodyStyle(24, AppColors.ink, FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Điểm đã được cộng vào 🏆 hôm nay.', style: bodyStyle(19)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(onPressed: _restart, child: Text('🔄 Chơi lại cấp ${_game.level}')),
            const SizedBox(width: 14),
            OutlinedButton(onPressed: leaveGame, child: const Text('🏠 Góc trò chơi')),
          ]),
        ]),
      ),
    );
  }
}

// ============================================================================ hộp đố toán
/// Hộp đố của khối bí ẩn: chọn đúng thì mở khóa (trả về số lần thử); sai thì thử lại – không lộ đáp án.
class MathQuestionDialog extends ConsumerStatefulWidget {
  const MathQuestionDialog({super.key, required this.q, required this.shape, required this.color});
  final MathQ q;
  final Shape shape;
  final Color color;

  @override
  ConsumerState<MathQuestionDialog> createState() => _MathQuestionDialogState();
}

class _MathQuestionDialogState extends ConsumerState<MathQuestionDialog> {
  final _wrong = <String>{};
  String? _right;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsProvider).say(widget.q.spoken));
  }

  Future<void> _choose(String o) async {
    if (_right != null || _wrong.contains(o)) return;
    _tries++;
    if (o == widget.q.answer) {
      setState(() => _right = o);
      ref.read(soundProvider).ting();
      ref.read(ttsProvider).say('Đúng rồi! Mở khóa!');
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(_tries);
    } else {
      setState(() => _wrong.add(o));
      ref.read(soundProvider).oops();
      const msgs = ['Chưa đúng rồi, bạn thử lại nhé!', 'Gần rồi! Bạn nghĩ thêm chút nữa nhé!', 'Bình tĩnh, mình tính lại nào!'];
      ref.read(ttsProvider).say(msgs[(_tries - 1) % msgs.length]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final s = widget.shape;
    final cell = math.min(54.0, 200 / s.rows); // khối cao (5 ô) thu nhỏ để hộp đố không tràn
    const optColors = [AppColors.sky, AppColors.orange, AppColors.success, Color(0xFFFF8FB1)];
    return Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('🔒 Khối bí ẩn', style: titleStyle(30, const Color(0xFF7A5CFF))),
                const Spacer(),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Để sau')),
              ]),
              const SizedBox(height: 8),
              if (q.showShape) ...[
                CustomPaint(
                  size: Size(s.cols * cell, s.rows * cell),
                  painter: _PiecePainter(s, widget.color, cell, grid: true),
                ),
                if (q.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(q.note, style: bodyStyle(18, Colors.grey.shade700)),
                  ),
                const SizedBox(height: 10),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(
                  child: Text(q.text, textAlign: TextAlign.center, style: titleStyle(q.showShape ? 32 : 52)),
                ),
                IconButton(
                  onPressed: () => ref.read(ttsProvider).say(q.spoken),
                  icon: const Text('🔊', style: TextStyle(fontSize: 32)),
                ),
              ]),
              const SizedBox(height: 18),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < q.options.length; i++)
                    _option(q.options[i], optColors[i % optColors.length], q.options[i].length > 6),
                ],
              ),
              const SizedBox(height: 8),
              if (_wrong.isNotEmpty && _right == null)
                Text('🤔 Thử đáp án khác nhé!', style: bodyStyle(20, const Color(0xFF7A5CFF), FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _option(String o, Color color, bool wide) {
    final wrong = _wrong.contains(o);
    final right = _right == o;
    return Material(
      color: right ? AppColors.success : (wrong ? Colors.grey.shade300 : color),
      borderRadius: BorderRadius.circular(26),
      elevation: wrong ? 0 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: wrong ? null : () => _choose(o),
        child: SizedBox(
          width: wide ? 250 : 150,
          height: 96,
          child: Center(
            child: Text(
              right ? '✅ $o' : (wrong ? '🤔' : o),
              textAlign: TextAlign.center,
              style: titleStyle(wide ? 28 : 42, Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================ vẽ
class _Burst {
  final int r, c;
  final BCell cell;
  final int start;
  _Burst(this.r, this.c, this.cell, this.start);
}

class _FloatText {
  final String text;
  final Offset pos; // toạ độ trong bảng (đã trừ lề)
  final int start;
  final Color color;
  final double size;
  _FloatText(this.text, this.pos, this.start, this.color, this.size);
}

/// Vẽ một ô kẹo: bóng đáy đậm, mặt trên sáng, vệt bóng trắng, có thể kèm ngôi sao.
void paintCandy(Canvas canvas, Rect rect, Color color, {bool star = false, double alpha = 1}) {
  final r = Radius.circular(rect.width * 0.24);
  final dark = Color.lerp(color, Colors.black, 0.2)!;
  final light = Color.lerp(color, Colors.white, 0.35)!;
  canvas.drawRRect(RRect.fromRectAndRadius(rect, r), Paint()..color = dark.withValues(alpha: alpha));
  final top = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.9);
  canvas.drawRRect(
    RRect.fromRectAndRadius(top, r),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [light.withValues(alpha: alpha), color.withValues(alpha: alpha)],
      ).createShader(top),
  );
  canvas.drawOval(
    Rect.fromLTWH(rect.left + rect.width * 0.16, rect.top + rect.height * 0.12, rect.width * 0.32, rect.height * 0.18),
    Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha),
  );
  if (star) {
    _starPath(canvas, rect.center + Offset(0, rect.height * 0.04), rect.width * 0.26,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha));
  }
}

void _starPath(Canvas canvas, Offset c, double r, Paint paint) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * 0.45;
    final a = -math.pi / 2 + i * math.pi / 5;
    final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  canvas.drawPath(path..close(), paint);
}

void _paintRock(Canvas canvas, Rect rect) {
  final r = Radius.circular(rect.width * 0.3);
  canvas.drawRRect(RRect.fromRectAndRadius(rect, r), Paint()..color = const Color(0xFF8C8FA3));
  canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(rect.width * 0.08).shift(Offset(0, -rect.height * 0.04)), r),
      Paint()..color = const Color(0xFFB4B7C9));
  final spot = Paint()..color = const Color(0xFF9497AD);
  canvas.drawCircle(rect.center + Offset(-rect.width * 0.15, rect.height * 0.05), rect.width * 0.09, spot);
  canvas.drawCircle(rect.center + Offset(rect.width * 0.18, -rect.height * 0.1), rect.width * 0.06, spot);
  canvas.drawCircle(rect.center + Offset(rect.width * 0.1, rect.height * 0.2), rect.width * 0.05, spot);
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.shape, this.color, this.cell, {this.star = false, this.dim = false, this.grid = false});
  final Shape shape;
  final Color color;
  final double cell;
  final bool star;
  final bool dim;
  final bool grid;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = cell * 0.06;
    for (final (r, c) in shape.cells) {
      final rect = Rect.fromLTWH(c * cell + gap, r * cell + gap, cell - 2 * gap, cell - 2 * gap);
      paintCandy(canvas, rect, color, star: star, alpha: dim ? 0.45 : 1);
    }
    if (grid) {
      // viền ô rõ ràng để bé đếm cạnh khi tính chu vi
      final p = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final (r, c) in shape.cells) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(c * cell + gap, r * cell + gap, cell - 2 * gap, cell - 2 * gap),
                Radius.circular(cell * 0.24)),
            p);
      }
    }
  }

  @override
  bool shouldRepaint(_PiecePainter old) =>
      old.shape != shape || old.color != color || old.cell != cell || old.star != star || old.dim != dim;
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.board,
    required this.cell,
    required this.pad,
    required this.ghost,
    required this.hlRows,
    required this.hlCols,
    required this.bursts,
    required this.floats,
    required this.now,
  });

  final BlockBoard board;
  final double cell;
  final double pad;
  final (TrayPiece, (int, int))? ghost;
  final List<int> hlRows, hlCols;
  final List<_Burst> bursts;
  final List<_FloatText> floats;
  final int now;

  Rect _cellRect(int r, int c, [double inset = 0.05]) {
    final g = cell * inset;
    return Rect.fromLTWH(pad + c * cell + g, pad + r * cell + g, cell - 2 * g, cell - 2 * g);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(30));
    canvas.drawRRect(bg.shift(const Offset(0, 6)), Paint()..color = const Color(0x22000000));
    canvas.drawRRect(bg, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawRRect(
        bg,
        Paint()
          ..color = const Color(0xFFD9CCFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);

    final empty = Paint()..color = const Color(0xFFF0EBFF);
    for (var r = 0; r < BlockBoard.n; r++) {
      for (var c = 0; c < BlockBoard.n; c++) {
        final rect = _cellRect(r, c);
        final cellV = board.at(r, c);
        if (cellV == null) {
          canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.2)), empty);
        } else if (cellV.rock) {
          _paintRock(canvas, rect);
        } else {
          paintCandy(canvas, rect, candyColors[cellV.color % candyColors.length], star: cellV.star);
        }
      }
    }

    // bóng chỗ sẽ đặt + tô sáng hàng sắp nổ
    final g = ghost;
    if (g != null) {
      final (piece, (gr, gc)) = g;
      final hl = Paint()..color = AppColors.sun.withValues(alpha: 0.45);
      for (final r in hlRows) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(pad, pad + r * cell, cell * BlockBoard.n, cell), Radius.circular(cell * 0.25)),
            hl);
      }
      for (final c in hlCols) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(pad + c * cell, pad, cell, cell * BlockBoard.n), Radius.circular(cell * 0.25)),
            hl);
      }
      for (final (r, c) in piece.shape.cells) {
        paintCandy(canvas, _cellRect(gr + r, gc + c), candyColors[piece.color], star: piece.star, alpha: 0.55);
      }
    }

    // hiệu ứng nổ: ô co lại + hạt sao bay ra
    for (final b in bursts) {
      final age = now - b.start;
      if (age < 0) continue;
      final color = b.cell.rock ? const Color(0xFFB4B7C9) : candyColors[b.cell.color % candyColors.length];
      final center = _cellRect(b.r, b.c).center;
      if (age < 260) {
        final s = 1 - age / 260;
        final rect = Rect.fromCenter(center: center, width: cell * 0.9 * s, height: cell * 0.9 * s);
        paintCandy(canvas, rect, color, star: b.cell.star);
      }
      final t = (age / 900).clamp(0.0, 1.0);
      final paint = Paint()..color = color.withValues(alpha: 1 - t);
      for (var i = 0; i < 5; i++) {
        final a = (i * 72 + (b.r * 31 + b.c * 17) % 72) * math.pi / 180;
        final d = cell * (0.2 + 1.1 * t);
        final p = center + Offset(math.cos(a) * d, math.sin(a) * d + cell * 0.8 * t * t);
        if (i.isEven) {
          _starPath(canvas, p, cell * 0.16 * (1 - t * 0.5), paint);
        } else {
          canvas.drawCircle(p, cell * 0.08 * (1 - t * 0.5), paint);
        }
      }
    }

    // chữ điểm bay lên
    for (final f in floats) {
      final age = now - f.start;
      if (age < 0) continue;
      final t = (age / 1400).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: f.text,
          style: titleStyle(f.size, f.color.withValues(alpha: 1 - t * t)).copyWith(
            shadows: [Shadow(color: Colors.white.withValues(alpha: 1 - t), blurRadius: 0, offset: const Offset(2, 2))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      var x = pad + f.pos.dx - tp.width / 2;
      x = x.clamp(4.0, size.width - tp.width - 4).toDouble();
      final y = pad + f.pos.dy - tp.height / 2 - 70 * t;
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) => true;
}

class _Cloud extends StatelessWidget {
  const _Cloud({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Opacity(opacity: 0.7, child: Text('☁️', style: TextStyle(fontSize: size)));
}
