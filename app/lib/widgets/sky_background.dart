import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bảng màu nền theo từng khu.
class SkyTheme {
  final List<Color> gradient;
  final Color cloud;
  final List<Color> sparkles;
  final bool waves; // vẽ sóng biển dưới đáy (đảo)
  const SkyTheme(this.gradient, this.cloud, this.sparkles, {this.waves = false});

  static const morning = SkyTheme(
    [Color(0xFFCFEBFF), Color(0xFFFFF4E3)],
    Colors.white,
    [Color(0xFFFFD23F), Color(0xFFFF8FB1), Color(0xFF6BD49A)],
  );
  static const ocean = SkyTheme(
    [Color(0xFFBFE8FF), Color(0xFFE6FBFF)],
    Colors.white,
    [Color(0xFFFFD23F), Color(0xFF5EB8FF), Color(0xFFB08CFF)],
    waves: true,
  );
  static const candy = SkyTheme(
    [Color(0xFFFFE8F3), Color(0xFFE6F4FF)],
    Colors.white,
    [Color(0xFFFF8FB1), Color(0xFFFFB547), Color(0xFFB08CFF)],
  );
}

/// Nền "sống": mây trôi chậm, lấp lánh nhấp nháy, bong bóng bay lên, (tuỳ chọn) sóng biển.
/// Một AnimationController + RepaintBoundary → nhẹ cho máy tính bảng.
class SkyBackground extends StatefulWidget {
  const SkyBackground({super.key, required this.child, this.theme = SkyTheme.morning});
  final Widget child;
  final SkyTheme theme;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: CustomPaint(painter: _SkyPainter(_c, widget.theme)),
        ),
      ),
      widget.child,
    ]);
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.anim, this.theme) : super(repaint: anim);
  final Animation<double> anim;
  final SkyTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value; // 0..1 trong 40 giây
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: theme.gradient,
        ).createShader(Offset.zero & size),
    );

    // mây trôi
    final cloud = Paint()..color = theme.cloud.withValues(alpha: 0.75);
    for (var i = 0; i < 4; i++) {
      final speed = 0.6 + i * 0.25;
      final span = w + 260;
      final x = ((i * 0.31 + t * speed) % 1.0) * span - 160;
      final y = h * (0.08 + 0.13 * i) + math.sin(t * 2 * math.pi * 2 + i) * 6;
      final s = 0.7 + (i % 3) * 0.25;
      _cloud(canvas, Offset(x, y), s, cloud);
    }

    // bong bóng bay lên
    for (var i = 0; i < 9; i++) {
      final seed = i * 0.137;
      final p = (t * (1.4 + (i % 3) * 0.4) + seed) % 1.0;
      final x = w * ((i * 0.113 + 0.05) % 1.0) + math.sin((p + i) * 2 * math.pi) * 14;
      final y = h * (1.05 - p * 1.15);
      final r = 6.0 + (i % 4) * 3;
      final a = (math.sin(p * math.pi)).clamp(0.0, 1.0) * 0.35;
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Colors.white.withValues(alpha: a)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(
          Offset(x - r * 0.35, y - r * 0.35), r * 0.22, Paint()..color = Colors.white.withValues(alpha: a));
    }

    // lấp lánh
    for (var i = 0; i < 14; i++) {
      final x = w * ((i * 0.071 + 0.03) % 1.0);
      final y = h * ((i * 0.193 + 0.07) % 0.85);
      final tw = (math.sin(t * 2 * math.pi * (3 + i % 4) + i * 1.7) + 1) / 2;
      if (tw < 0.25) continue;
      final c = theme.sparkles[i % theme.sparkles.length].withValues(alpha: 0.25 + 0.55 * tw);
      _sparkle(canvas, Offset(x, y), 3 + 6 * tw, Paint()..color = c);
    }

    if (theme.waves) {
      for (var k = 0; k < 2; k++) {
        final path = Path()..moveTo(0, h);
        final base = h - 22 - k * 16;
        for (double x = 0; x <= w + 8; x += 8) {
          path.lineTo(x, base + math.sin(x / 70 + t * 2 * math.pi * (3 + k) + k) * 7);
        }
        path
          ..lineTo(w, h)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF5EB8FF).withValues(alpha: 0.18 + k * 0.12));
      }
    }
  }

  void _cloud(Canvas c, Offset o, double s, Paint p) {
    c.drawCircle(o + Offset(0, 0) * s, 26 * s, p);
    c.drawCircle(o + const Offset(30, -12) * s, 32 * s, p);
    c.drawCircle(o + const Offset(62, 0) * s, 24 * s, p);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 12 * s, o.dy, 96 * s, 24 * s), Radius.circular(12 * s)), p);
  }

  void _sparkle(Canvas c, Offset o, double r, Paint p) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.theme != theme;
}

/// Nhún nhẹ lên xuống mãi (cho emoji, linh vật…). [phase] để các phần tử không nhún cùng nhịp.
class Bobbing extends StatefulWidget {
  const Bobbing({super.key, required this.child, this.amplitude = 5, this.phase = 0, this.period = 1800});
  final Widget child;
  final double amplitude;
  final double phase;
  final int period; // ms

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.period))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, math.sin((_c.value + widget.phase) * 2 * math.pi) * widget.amplitude),
          child: child,
        ),
        child: widget.child,
      );
}

/// Bấm vào thì lún xuống rồi nảy lên (cảm giác "bấm được" cho trẻ).
class PressBounce extends StatefulWidget {
  const PressBounce({super.key, required this.child, this.enabled = true, this.scale = 0.93});
  final Widget child;
  final bool enabled;
  final double scale;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: widget.enabled ? (_) => setState(() => _down = true) : null,
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: Duration(milliseconds: _down ? 90 : 260),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      );
}

/// Hiện lên bằng hiệu ứng "bật" (scale + mờ dần) khi xuất hiện, có độ trễ để các phần tử lần lượt xuất hiện.
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay; // ms

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
          return Opacity(
            opacity: _c.value.clamp(0.0, 1.0),
            child: Transform.scale(scale: 0.6 + 0.4 * v, child: child),
          );
        },
        child: widget.child,
      );
}
