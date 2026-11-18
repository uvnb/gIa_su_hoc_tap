import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/game_timer.dart';
import '../../../core/local_store.dart';
import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/owl_view.dart';
import '../../tutor/widgets/celebration_overlay.dart';
import '../blocks/block_game_screen.dart' show candyColors;
import '../game_session.dart';
import 'balloon_logic.dart';

/// 🎈 Bóng Bay Phép Tính: bóng bay lên mang phép tính – bé chạm thật nhanh những quả hợp MỤC TIÊU
/// (vd "Bằng 10", "Số chẵn"). Mỗi ván 60 giây; đủ điểm thì lên cấp (bóng nhanh hơn, phép tính khó hơn).
class BalloonGameScreen extends ConsumerStatefulWidget {
  const BalloonGameScreen({super.key});

  @override
  ConsumerState<BalloonGameScreen> createState() => _BalloonGameScreenState();
}

class _Balloon {
  _Balloon(this.item, this.x, this.y, this.speed, this.color, this.phase);
  final BalloonItem item;
  double x, y;
  final double speed;
  final Color color;
  final double phase;
  TextPainter? label;
}

class _Pop {
  _Pop(this.pos, this.color, this.t0, this.text, this.good);
  final Offset pos;
  final Color color;
  final double t0;
  final String text;
  final bool good;
}

class _BalloonGameScreenState extends ConsumerState<BalloonGameScreen>
    with SingleTickerProviderStateMixin, GameSession<BalloonGameScreen> {
  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  final _rnd = math.Random();
  late final LocalStore _store = ref.read(localStoreProvider);

  Size _size = const Size(960, 520);
  Duration _last = Duration.zero;
  double _t = 0;
  double _nextSpawn = 0;
  final _balloons = <_Balloon>[];
  final _pops = <_Pop>[];

  late BalloonGoal _goal;
  int _goodHit = 0; // số bóng đúng của mục tiêu hiện tại
  int _score = 0;
  int _combo = 0;
  int _hits = 0;
  int _misses = 0;
  int _level = 1;
  int _grade = 1;
  int _best = 0;
  String _childId = '';
  bool _started = false;
  bool _over = false;
  bool _leveledUp = false;
  String _mood = 'idle';
  int _celebrate = 0;
  String _celebrateText = '';
  bool _c = false;

  @override
  String get musicTrack => 'balloon';

  BalloonLevel get _cfg => BalloonLevel(_level);
  double get _timeLeft => math.max(0, _cfg.roundSeconds - _t);
  double get _bw => _c ? 104 : 124;
  double get _bh => _bw * 1.2;

  @override
  void initState() {
    super.initState();
    final child = ref.read(activeChildProvider);
    _childId = child?.id ?? '';
    _grade = child?.grade ?? 1;
    _level = _childId.isEmpty ? 1 : _store.gameLevel(_childId, 'balloon');
    _best = _childId.isEmpty ? 0 : _store.gameBest(_childId, 'balloon');
    _goal = makeGoal(grade: _grade, level: _level, rnd: _rnd);
    startGameSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsProvider).say('Bóng bay phép tính! Chạm thật nhanh những quả bóng đúng mục tiêu nhé!');
    });
  }

  @override
  void onGameStop() {
    _ticker.stop();
    _saveBest();
  }

  @override
  void dispose() {
    _saveBest();
    endGameSession();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _saveBest() {
    if (_childId.isEmpty || _score <= 0) return;
    _store.submitGameBest(_childId, 'balloon', _score);
    if (_score > _best) _best = _score;
  }

  void _start() {
    setState(() {
      _started = true;
      _over = false;
      _leveledUp = false;
      _t = 0;
      _nextSpawn = 0.3;
      _score = 0;
      _combo = 0;
      _hits = 0;
      _misses = 0;
      _goodHit = 0;
      _balloons.clear();
      _pops.clear();
      _goal = makeGoal(grade: _grade, level: _level, rnd: _rnd);
    });
    ref.read(ttsProvider).say(_goal.spoken);
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  // ------------------------------------------------------------------ vòng lặp
  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (!_started || _over) return;
    _t += dt;
    if (_t >= _nextSpawn) {
      _spawn();
      _nextSpawn = _t + _cfg.spawnEvery * (0.75 + _rnd.nextDouble() * 0.5);
    }
    for (final b in _balloons) {
      b.y -= b.speed * dt;
    }
    _balloons.removeWhere((b) => b.y < -_bh - 60);
    _pops.removeWhere((p) => _t - p.t0 > 1.3);
    if (_timeLeft <= 0) _endRound();
    _frame.value++;
  }

  void _spawn() {
    // ~45% bóng đúng; bảo đảm luôn có bóng đúng trên màn
    final hasGood = _balloons.any((b) => b.item.good);
    final good = !hasGood || _rnd.nextDouble() < 0.45;
    final item = makeBalloon(_goal, good: good, grade: _grade, level: _level, rnd: _rnd);
    final w = _size.width;
    var x = _bw / 2 + 10 + _rnd.nextDouble() * (w - _bw - 20);
    // tránh đè lên quả vừa thả
    for (var k = 0; k < 6 && _balloons.any((b) => (b.x - x).abs() < _bw && b.y > _size.height - _bh); k++) {
      x = _bw / 2 + 10 + _rnd.nextDouble() * (w - _bw - 20);
    }
    final b = _Balloon(item, x, _size.height + _bh / 2 + 10, _cfg.riseSpeed * (0.85 + _rnd.nextDouble() * 0.3),
        candyColors[_rnd.nextInt(candyColors.length)], _rnd.nextDouble() * 6);
    b.label = TextPainter(
      text: TextSpan(
        text: item.label,
        style: titleStyle(
                item.label.length > 7 ? _bw * 0.2 : (item.label.length > 4 ? _bw * 0.25 : _bw * 0.32), Colors.white)
            .copyWith(shadows: const [Shadow(color: Color(0x55000000), offset: Offset(1.5, 1.5))]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _balloons.add(b);
  }

  Offset _posOf(_Balloon b) => Offset(b.x + math.sin(_t * 1.6 + b.phase) * 10, b.y);

  void _tap(Offset p) {
    if (!_started || _over) return;
    _Balloon? hit;
    for (final b in _balloons.reversed) {
      final c = _posOf(b);
      final dx = (p.dx - c.dx) / (_bw / 2 + 8), dy = (p.dy - c.dy) / (_bh / 2 + 8);
      if (dx * dx + dy * dy <= 1) {
        hit = b;
        break;
      }
    }
    if (hit == null) return;
    _balloons.remove(hit);
    final pos = _posOf(hit);
    final sound = ref.read(soundProvider);
    sound.pop();
    if (hit.item.good) {
      _combo++;
      _hits++;
      final pts = 10 + (_combo >= 3 ? 5 : 0);
      _score += pts;
      _goodHit++;
      _pops.add(_Pop(pos, hit.color, _t, _combo >= 3 ? '+$pts 🔥' : '+$pts', true));
      sound.ting();
      _mood = 'celebrating';
      _addPoints(pts);
      if (_goodHit >= goodPerGoal) _newGoal();
    } else {
      _combo = 0;
      _misses++;
      _pops.add(_Pop(pos, hit.color, _t, _explain(hit.item), false));
      sound.oops();
      _mood = 'encouraging';
    }
    setState(() {});
  }

  /// Giải thích vì sao bóng chưa đúng – bé học được ngay.
  String _explain(BalloonItem it) {
    final v = it.value;
    final head = it.label == '$v' ? '$v' : '${it.label} = $v';
    return switch (_goal.kind) {
      'even' => '$head là số lẻ',
      'odd' => '$head là số chẵn',
      'greater' => '$head không lớn hơn ${_goal.target}',
      'less' => '$head không nhỏ hơn ${_goal.target}',
      'div' => '$head không chia hết cho ${_goal.target}',
      _ => '$head ≠ ${_goal.target}',
    };
  }

  void _newGoal() {
    _goodHit = 0;
    var g = makeGoal(grade: _grade, level: _level, rnd: _rnd);
    for (var k = 0; k < 5 && g.title == _goal.title; k++) {
      g = makeGoal(grade: _grade, level: _level, rnd: _rnd);
    }
    _goal = g;
    // bóng cũ trên màn đổi theo mục tiêu mới → bay đi, thả bóng mới
    _balloons.clear();
    _nextSpawn = _t + 0.4;
    ref.read(soundProvider).unlock();
    ref.read(ttsProvider).say('Mục tiêu mới! ${g.spoken}');
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

  Future<void> _endRound() async {
    if (_over) return;
    _saveBest();
    final pass = _score >= _cfg.passScore;
    setState(() {
      _over = true;
      _leveledUp = pass;
      _balloons.clear();
      _mood = pass ? 'celebrating' : 'encouraging';
      if (pass) {
        _celebrateText = 'Lên cấp ${_level + 1}! 🎉';
        _celebrate++;
      }
    });
    if (pass) {
      _level++;
      if (_childId.isNotEmpty) await _store.setGameLevel(_childId, 'balloon', _level);
      ref.read(soundProvider).tada();
      ref.read(ttsProvider).say('Hết giờ! Bạn bắn trúng $_hits quả bóng. Giỏi quá, lên cấp $_level!');
    } else {
      parentVoiceOrSay(ref, 'encourage',
          'Hết giờ! Bạn bắn trúng $_hits quả bóng. Cần ${_cfg.passScore} điểm để lên cấp, mình thử lại nhé!');
    }
  }

  // ------------------------------------------------------------------ giao diện
  @override
  Widget build(BuildContext context) {
    _c = isCompact(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFD4EEFF),
              child: GameTopBar(
                title: '🎈 Bóng Bay Phép Tính',
                onBack: leaveGame,
                extra: [
                  ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (_, __, ___) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _timeLeft <= 10 && _started ? const Color(0xFFFFE0EC) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text('⏱️ ${_timeLeft.ceil()}s',
                          style: bodyStyle(_c ? 18 : 22, AppColors.ink, FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                _size = Size(box.maxWidth, box.maxHeight);
                return Stack(children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) => _tap(d.localPosition),
                      child: RepaintBoundary(child: CustomPaint(painter: _SkyPainter(this, repaint: _frame))),
                    ),
                  ),
                  if (_started && !_over) Positioned(top: 8, left: 0, right: 0, child: Center(child: _goalBanner())),
                  Positioned(
                    left: 8,
                    bottom: 4,
                    child: IgnorePointer(child: OwlView(mood: _mood, size: _c ? 90 : 120)),
                  ),
                  Positioned(right: 12, bottom: 10, child: IgnorePointer(child: _hud())),
                  Positioned.fill(child: CelebrationOverlay(tick: _celebrate, text: _celebrateText)),
                  if (!_started) Positioned.fill(child: _startCard()),
                  if (_over) Positioned.fill(child: _endCard()),
                ]);
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalBanner() => Container(
        padding: EdgeInsets.symmetric(horizontal: _c ? 20 : 28, vertical: _c ? 6 : 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.orange, width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('🎯 Chạm bóng: ', style: bodyStyle(_c ? 20 : 24, AppColors.ink, FontWeight.w800)),
          Text(_goal.title, style: titleStyle(_c ? 32 : 40, AppColors.orange)),
          const SizedBox(width: 12),
          Text('${'●' * _goodHit}${'○' * (goodPerGoal - _goodHit)}',
              style: bodyStyle(_c ? 18 : 22, AppColors.success, FontWeight.w900)),
          GestureDetector(
            onTap: () => ref.read(ttsProvider).say(_goal.spoken),
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text('🔊', style: TextStyle(fontSize: _c ? 24 : 28)),
            ),
          ),
        ]),
      );

  Widget _hud() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(24)),
        child: Text('Cấp $_level · ⭐ $_score / ${_cfg.passScore}${_combo >= 3 ? ' · 🔥×$_combo' : ''}',
            style: bodyStyle(_c ? 18 : 22, AppColors.ink, FontWeight.w800)),
      );

  Widget _card({required List<Widget> children, Color border = AppColors.sky}) => Container(
        color: Colors.black.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Container(
            width: 640,
            padding: EdgeInsets.all(_c ? 18 : 28),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: border, width: 6),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      );

  Widget _startCard() => _card(children: [
        Text('🎈', style: TextStyle(fontSize: _c ? 56 : 72)),
        Text('Bóng Bay Phép Tính', style: titleStyle(_c ? 32 : 40)),
        const SizedBox(height: 8),
        for (final line in [
          '🎯 Nhìn MỤC TIÊU ở trên (vd "Bằng 10").',
          '👆 Chạm nhanh những quả bóng có kết quả đúng mục tiêu.',
          '🔥 Trúng liên tiếp 3 quả: mỗi quả +15 điểm!',
          '⏱️ Mỗi ván ${_cfg.roundSeconds} giây · đủ ${_cfg.passScore} điểm là lên cấp.',
        ])
          Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(line, style: bodyStyle(_c ? 18 : 21))),
        SizedBox(height: _c ? 10 : 18),
        ElevatedButton(
          onPressed: _start,
          style: ElevatedButton.styleFrom(minimumSize: Size(260, _c ? 68 : 84), backgroundColor: AppColors.success),
          child: Text('▶️ Bắt đầu', style: titleStyle(_c ? 28 : 32, Colors.white)),
        ),
      ]);

  Widget _endCard() => _card(border: AppColors.sun, children: [
        Text(_leveledUp ? '🎉' : '⏱️', style: TextStyle(fontSize: _c ? 52 : 64)),
        Text(_leveledUp ? 'Lên cấp $_level!' : 'Hết giờ rồi!', style: titleStyle(_c ? 32 : 38)),
        const SizedBox(height: 8),
        Text('Trúng $_hits quả · nhầm $_misses · ⭐ $_score điểm',
            style: bodyStyle(_c ? 21 : 24, AppColors.ink, FontWeight.w800)),
        Text(
            _leveledUp
                ? 'Bóng sẽ bay nhanh hơn một chút đấy!'
                : 'Cần ${_cfg.passScore} điểm để lên cấp. Kỷ lục: ${math.max(_best, _score)}',
            style: bodyStyle(_c ? 17 : 20)),
        SizedBox(height: _c ? 12 : 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(onPressed: _start, child: Text(_leveledUp ? '▶️ Chơi cấp $_level' : '🔄 Chơi lại')),
          const SizedBox(width: 14),
          OutlinedButton(onPressed: leaveGame, child: const Text('🏠 Góc trò chơi')),
        ]),
      ]);
}

// ============================================================================ vẽ
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);
  final _BalloonGameScreenState g;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD4EEFF), Color(0xFFFFF1F7)],
        ).createShader(Offset.zero & size),
    );
    // mây trôi
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      final span = size.width + 240;
      final x = ((i * 300 + 80 + g._t * 14) % span) - 120;
      final y = 90.0 + i * 95 % (size.height * 0.6);
      canvas.drawCircle(Offset(x, y), 26, cloud);
      canvas.drawCircle(Offset(x + 30, y - 10), 32, cloud);
      canvas.drawCircle(Offset(x + 62, y), 24, cloud);
    }
    // cỏ dưới đáy
    canvas.drawRect(Rect.fromLTWH(0, size.height - 26, size.width, 26), Paint()..color = const Color(0xFF9EDB8A));

    final bw = g._bw, bh = g._bh;
    for (final b in g._balloons) {
      final c = g._posOf(b);
      _balloon(canvas, c, bw, bh, b.color, b.label);
    }

    // hiệu ứng nổ + chữ bay
    for (final p in g._pops) {
      final t = ((g._t - p.t0) / 1.3).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: 1 - t);
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5 + p.pos.dx * 0.01;
        final d = 20 + 90 * t;
        canvas.drawCircle(p.pos + Offset(math.cos(a) * d, math.sin(a) * d + 40 * t * t), 7 * (1 - t) + 2, paint);
      }
      final tp = TextPainter(
        text: TextSpan(
          text: p.text,
          style: titleStyle(
                  p.good ? 36 : 26, (p.good ? AppColors.success : const Color(0xFF7A5CFF)).withValues(alpha: 1 - t * t))
              .copyWith(shadows: [Shadow(color: Colors.white.withValues(alpha: 1 - t), offset: const Offset(2, 2))]),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 420);
      final x = (p.pos.dx - tp.width / 2).clamp(4.0, size.width - tp.width - 4).toDouble();
      tp.paint(canvas, Offset(x, p.pos.dy - 40 - 60 * t));
    }
  }

  void _balloon(Canvas canvas, Offset c, double w, double h, Color color, TextPainter? label) {
    // dây
    final string = Path()
      ..moveTo(c.dx, c.dy + h / 2 + 6)
      ..quadraticBezierTo(c.dx - 12, c.dy + h / 2 + 30, c.dx + 4, c.dy + h / 2 + 62);
    canvas.drawPath(
        string,
        Paint()
          ..color = const Color(0x88505A7A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    // nút buộc
    final knot = Path()
      ..moveTo(c.dx, c.dy + h / 2 - 2)
      ..lineTo(c.dx - 8, c.dy + h / 2 + 9)
      ..lineTo(c.dx + 8, c.dy + h / 2 + 9)
      ..close();
    canvas.drawPath(knot, Paint()..color = Color.lerp(color, Colors.black, 0.15)!);
    // thân bóng
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 0.95,
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.12)!],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    // vệt bóng
    canvas.drawOval(Rect.fromLTWH(c.dx - w * 0.3, c.dy - h * 0.36, w * 0.18, h * 0.22),
        Paint()..color = Colors.white.withValues(alpha: 0.55));
    // mặt cười nhỏ
    final eye = Paint()..color = const Color(0xCC23305A);
    canvas.drawCircle(Offset(c.dx - w * 0.13, c.dy - h * 0.24), w * 0.035, eye);
    canvas.drawCircle(Offset(c.dx + w * 0.13, c.dy - h * 0.24), w * 0.035, eye);
    canvas.drawArc(
        Rect.fromCenter(center: Offset(c.dx, c.dy - h * 0.2), width: w * 0.14, height: h * 0.08),
        0.2,
        2.7,
        false,
        Paint()
          ..color = const Color(0xCC23305A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round);
    // chữ
    if (label != null) {
      label.paint(canvas, Offset(c.dx - label.width / 2, c.dy - label.height / 2 + h * 0.08));
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
