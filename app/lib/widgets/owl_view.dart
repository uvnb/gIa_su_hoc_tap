import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Linh vật Cú Tò Mò vẽ bằng CustomPainter (mục 6.1) – nhẹ, không cần file Rive/ảnh.
///
/// mood: idle | listening | thinking | asking | encouraging | celebrating | sleepy
/// stage (FR-41): 0 trứng · 1 cú con · 2 cú biết bay · 3 cú thông thái (linh vật gia sư).
class OwlView extends StatefulWidget {
  const OwlView({super.key, this.mood = 'idle', this.size = 200, this.stage = 3, this.waving = false});

  final String mood;
  final double size;
  final int stage;
  final bool waving;

  @override
  State<OwlView> createState() => _OwlViewState();
}

class _OwlViewState extends State<OwlView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.1,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: OwlPainter(mood: widget.mood, t: _c.value, stage: widget.stage, waving: widget.waving),
          ),
        ),
      ),
    );
  }
}

class OwlPainter extends CustomPainter {
  OwlPainter({required this.mood, required this.t, required this.stage, required this.waving});

  final String mood;
  final double t; // 0..1 lặp lại
  final int stage;
  final bool waving;

  static const _faceDisc = Color(0xFFE9C79E);
  static const _beak = AppColors.orange;
  static const _cheek = Color(0x66FF9E8A);

  double get _wave => math.sin(t * 2 * math.pi);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 200;
    canvas.save();
    canvas.scale(s, s);

    // bóng dưới chân
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 212), width: 110, height: 14),
        Paint()..color = Colors.black.withValues(alpha: 0.08));

    if (stage == 0) {
      _egg(canvas);
      canvas.restore();
      return;
    }

    final bounce = switch (mood) {
      'celebrating' => -(math.sin(t * 4 * math.pi).abs()) * 16,
      'sleepy' => 2.0,
      _ => _wave * 2,
    };
    final tilt = switch (mood) {
      'idle' => math.sin(t * 2 * math.pi) * 0.04,
      'asking' => 0.06,
      'thinking' => -0.05,
      _ => 0.0,
    };
    final scale = stage == 1 ? 0.82 : 1.0;

    canvas.save();
    canvas.translate(100, 210 + bounce);
    canvas.scale(scale, scale);
    canvas.rotate(tilt);
    canvas.translate(-100, -210);

    _feet(canvas);
    _wings(canvas);
    _body(canvas);
    _face(canvas);
    if (stage == 2) _scarf(canvas);
    if (stage == 3 || mood == 'sleepy') _hat(canvas);
    if (stage == 3 && mood != 'sleepy' && mood != 'celebrating') _pencil(canvas);
    canvas.restore();

    _extras(canvas);
    canvas.restore();
  }

  // ------------------------------------------------------------------ các bộ phận
  void _egg(Canvas c) {
    final wobble = math.sin(t * 2 * math.pi * 2) * 0.06;
    c.save();
    c.translate(100, 200);
    c.rotate(wobble);
    c.translate(-100, -200);
    final egg = Path()
      ..moveTo(100, 40)
      ..cubicTo(150, 40, 170, 140, 160, 170)
      ..cubicTo(150, 205, 50, 205, 40, 170)
      ..cubicTo(30, 140, 50, 40, 100, 40)
      ..close();
    c.drawPath(egg, Paint()..color = AppColors.owlBelly);
    c.drawPath(
        egg,
        Paint()
          ..color = AppColors.owlBody
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4);
    final spot = Paint()..color = AppColors.sky.withValues(alpha: 0.35);
    c.drawCircle(const Offset(70, 150), 9, spot);
    c.drawCircle(const Offset(132, 160), 7, spot);
    c.drawCircle(const Offset(118, 70), 6, spot);
    // vết nứt + đôi mắt nhìn ra
    final crack = Path()
      ..moveTo(52, 112)
      ..lineTo(68, 100)
      ..lineTo(82, 114)
      ..lineTo(100, 98)
      ..lineTo(118, 114)
      ..lineTo(132, 100)
      ..lineTo(148, 112);
    c.drawPath(
        crack,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final blink = t > 0.93;
    for (final x in [84.0, 116.0]) {
      if (blink) {
        c.drawLine(Offset(x - 7, 125), Offset(x + 7, 125), Paint()..color = AppColors.ink..strokeWidth = 3);
      } else {
        c.drawCircle(Offset(x, 125), 8, Paint()..color = AppColors.ink);
        c.drawCircle(Offset(x + 2.5, 122), 2.5, Paint()..color = Colors.white);
      }
    }
    c.restore();
  }

  void _feet(Canvas c) {
    final p = Paint()..color = _beak;
    for (final x in [82.0, 118.0]) {
      final f = Path()
        ..moveTo(x - 12, 206)
        ..quadraticBezierTo(x, 192, x + 12, 206)
        ..close();
      c.drawPath(f, p);
    }
  }

  void _wing(Canvas c, Offset pivot, double angle, {bool left = true}) {
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(angle);
    final w = stage == 2 ? 30.0 : 22.0;
    final h = stage == 2 ? 92.0 : 78.0;
    final rect = Rect.fromLTWH(left ? -w : 0, -6, w, h);
    c.drawOval(rect, Paint()..color = const Color(0xFF9C6A3D));
    c.restore();
  }

  void _wings(Canvas c) {
    var l = 0.25, r = -0.25;
    switch (mood) {
      case 'celebrating':
        final up = math.sin(t * 4 * math.pi) * 0.3;
        l = 2.3 + up;
        r = -2.3 - up;
      case 'asking':
        r = -1.7; // cánh chỉ vào bài
      case 'encouraging':
        l = 0.35 + _wave * 0.18;
        r = -0.35 - _wave * 0.18;
      case 'listening':
        l = 0.5;
        r = -0.5;
      default:
        break;
    }
    if (waving) r = -2.2 + math.sin(t * 6 * math.pi) * 0.45;
    if (stage == 2 && mood == 'idle' && !waving) {
      l = 0.9 + _wave * 0.3;
      r = -0.9 - _wave * 0.3;
    }
    _wing(c, const Offset(40, 112), l, left: true);
    _wing(c, const Offset(160, 112), r, left: false);
  }

  void _body(Canvas c) {
    c.drawOval(Rect.fromCenter(center: const Offset(100, 130), width: 140, height: 156),
        Paint()..color = AppColors.owlBody);
    // tai lông
    final tuft = mood == 'listening' ? 18.0 : 30.0;
    final ear = Paint()..color = AppColors.owlBody;
    c.drawPath(
        Path()
          ..moveTo(44, 78)
          ..lineTo(42, tuft)
          ..lineTo(78, 58)
          ..close(),
        ear);
    c.drawPath(
        Path()
          ..moveTo(156, 78)
          ..lineTo(158, tuft)
          ..lineTo(122, 58)
          ..close(),
        ear);
    // bụng
    c.drawOval(Rect.fromCenter(center: const Offset(100, 158), width: 92, height: 92),
        Paint()..color = AppColors.owlBelly);
    final v = Paint()
      ..color = AppColors.owlBody.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final o in const [Offset(86, 146), Offset(114, 146), Offset(100, 164), Offset(86, 180), Offset(114, 180)]) {
      c.drawPath(
          Path()
            ..moveTo(o.dx - 6, o.dy)
            ..lineTo(o.dx, o.dy + 5)
            ..lineTo(o.dx + 6, o.dy),
          v);
    }
  }

  void _face(Canvas c) {
    final disc = Paint()..color = _faceDisc;
    c.drawCircle(const Offset(74, 100), 31, disc);
    c.drawCircle(const Offset(126, 100), 31, disc);

    final ink = Paint()..color = AppColors.ink;
    final line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final blink = mood != 'sleepy' && t > 0.94;
    for (final cx in [74.0, 126.0]) {
      final center = Offset(cx, 100);
      if (mood == 'sleepy') {
        c.drawArc(Rect.fromCenter(center: center, width: 30, height: 20), 0.2, math.pi - 0.4, false, line);
        continue;
      }
      if (mood == 'encouraging' || mood == 'celebrating') {
        c.drawCircle(center, 22, Paint()..color = Colors.white);
        c.drawArc(Rect.fromCenter(center: center.translate(0, 4), width: 26, height: 22), math.pi + 0.25,
            math.pi - 0.5, false, line);
        continue;
      }
      if (blink) {
        c.drawLine(center.translate(-14, 0), center.translate(14, 0), line);
        continue;
      }
      c.drawCircle(center, 22, Paint()..color = Colors.white);
      var look = Offset.zero;
      if (mood == 'thinking') look = Offset(-5 + math.sin(t * 2 * math.pi) * 3, -8);
      if (mood == 'asking') look = const Offset(7, 2);
      if (mood == 'listening') look = const Offset(0, -2);
      c.drawCircle(center + look, 11, ink);
      c.drawCircle(center + look + const Offset(4, -4), 3.5, Paint()..color = Colors.white);
    }
    if (mood == 'encouraging' || mood == 'celebrating') {
      c.drawCircle(const Offset(58, 128), 9, Paint()..color = _cheek);
      c.drawCircle(const Offset(142, 128), 9, Paint()..color = _cheek);
    }
    // mỏ
    final beak = Path()
      ..moveTo(100, 112)
      ..lineTo(91, 124)
      ..lineTo(100, 138)
      ..lineTo(109, 124)
      ..close();
    c.drawPath(beak, Paint()..color = _beak);
  }

  void _scarf(Canvas c) {
    final p = Paint()..color = AppColors.sky;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(54, 136, 92, 14), const Radius.circular(7)), p);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(118, 142, 14, 34), const Radius.circular(6)), p);
  }

  void _hat(Canvas c) {
    if (mood == 'sleepy') {
      // mũ ngủ
      final cap = Path()
        ..moveTo(50, 62)
        ..quadraticBezierTo(100, 30, 150, 62)
        ..lineTo(176, 22)
        ..quadraticBezierTo(110, 6, 50, 62)
        ..close();
      c.drawPath(cap, Paint()..color = AppColors.think);
      c.drawCircle(const Offset(178, 22), 9, Paint()..color = Colors.white);
      return;
    }
    // mũ tốt nghiệp đội lệch
    c.save();
    c.translate(104, 46);
    c.rotate(-0.12);
    final navy = Paint()..color = AppColors.ink;
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-28, -4, 56, 18), const Radius.circular(4)), navy);
    final board = Path()
      ..moveTo(0, -24)
      ..lineTo(52, -8)
      ..lineTo(0, 8)
      ..lineTo(-52, -8)
      ..close();
    c.drawPath(board, navy);
    // tua rua đung đưa
    final swing = math.sin(t * 2 * math.pi) * 4;
    final tassel = Paint()
      ..color = AppColors.sun
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    c.drawLine(const Offset(0, -8), Offset(40 + swing, 2), tassel);
    c.drawLine(Offset(40 + swing, 2), Offset(42 + swing, 22), tassel);
    c.drawCircle(Offset(42 + swing, 24), 5, Paint()..color = AppColors.sun);
    c.drawCircle(const Offset(0, -8), 4, Paint()..color = AppColors.sun);
    c.restore();
  }

  void _pencil(Canvas c) {
    c.save();
    c.translate(34, 172);
    c.rotate(-0.6);
    c.drawRect(const Rect.fromLTWH(-5, -38, 10, 40), Paint()..color = AppColors.sun);
    c.drawRect(const Rect.fromLTWH(-5, -46, 10, 8), Paint()..color = const Color(0xFFFF9EB5));
    c.drawPath(
        Path()
          ..moveTo(-5, 2)
          ..lineTo(5, 2)
          ..lineTo(0, 14)
          ..close(),
        Paint()..color = const Color(0xFFF2D2A9));
    c.drawCircle(const Offset(0, 12), 2, Paint()..color = AppColors.ink);
    c.restore();
  }

  void _extras(Canvas c) {
    switch (mood) {
      case 'listening':
        for (var i = 0; i < 3; i++) {
          final phase = (t * 2 + i / 3) % 1.0;
          final p = Paint()
            ..color = AppColors.sky.withValues(alpha: 1 - phase)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round;
          final r = 14 + phase * 26;
          c.drawArc(Rect.fromCircle(center: const Offset(178, 96), radius: r), -0.7, 1.4, false, p);
          c.drawArc(Rect.fromCircle(center: const Offset(22, 96), radius: r), math.pi - 0.7, 1.4, false, p);
        }
      case 'thinking':
        final glow = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
        c.drawCircle(const Offset(172, 30), 22, Paint()..color = AppColors.sun.withValues(alpha: 0.25 * glow));
        c.drawCircle(const Offset(172, 30), 13, Paint()..color = AppColors.sun);
        c.drawRect(const Rect.fromLTWH(166, 42, 12, 8), Paint()..color = Colors.grey.shade500);
      case 'celebrating':
        final rnd = math.Random(7);
        const colors = [AppColors.sun, AppColors.sky, AppColors.success, AppColors.orange, AppColors.think];
        for (var i = 0; i < 14; i++) {
          final x = rnd.nextDouble() * 200;
          final y = ((rnd.nextDouble() + t) % 1.0) * 200 - 10;
          c.save();
          c.translate(x, y);
          c.rotate(t * 6 + i);
          c.drawRect(const Rect.fromLTWH(-4, -2, 8, 4), Paint()..color = colors[i % colors.length]);
          c.restore();
        }
        _star(c, Offset(28, 40 - math.sin(t * 2 * math.pi) * 6), 12);
        _star(c, Offset(176, 56 + math.sin(t * 2 * math.pi) * 6), 9);
      case 'sleepy':
        for (var i = 0; i < 2; i++) {
          final phase = (t + i * 0.5) % 1.0;
          final tp = TextPainter(
            text: TextSpan(
                text: 'Z',
                style: TextStyle(
                    fontSize: 18 + i * 8,
                    fontWeight: FontWeight.w900,
                    color: AppColors.think.withValues(alpha: 1 - phase))),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(c, Offset(150 + phase * 20 + i * 14, 40 - phase * 30 - i * 10));
        }
      default:
        break;
    }
  }

  void _star(Canvas c, Offset center, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = AppColors.sun);
  }

  @override
  bool shouldRepaint(OwlPainter old) =>
      old.t != t || old.mood != mood || old.stage != stage || old.waving != waving;
}
