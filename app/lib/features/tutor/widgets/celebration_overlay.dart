import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Pháo giấy + sao bay khi bé tự tìm ra đáp án (mục 3.4). Chạy mỗi khi `tick` tăng.
/// Hiệu ứng đơn giản (không blur) để mượt trên GPU yếu.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({super.key, required this.tick, this.text = 'Bạn tự tìm ra rồi! 🎉'});
  final int tick;
  final String text;

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _rnd = math.Random();
  List<_Piece> _pieces = [];

  @override
  void didUpdateWidget(CelebrationOverlay old) {
    super.didUpdateWidget(old);
    if (widget.tick != old.tick && widget.tick > 0) _play();
  }

  void _play() {
    const colors = [AppColors.sun, AppColors.sky, AppColors.success, AppColors.orange, AppColors.think];
    _pieces = List.generate(
      70,
      (i) => _Piece(
        x: _rnd.nextDouble(),
        speed: 0.6 + _rnd.nextDouble() * 0.8,
        drift: (_rnd.nextDouble() - 0.5) * 0.3,
        spin: _rnd.nextDouble() * 10,
        color: colors[i % colors.length],
        star: i % 7 == 0,
      ),
    );
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (!_c.isAnimating) return const SizedBox.shrink();
          final t = _c.value;
          final textOpacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _ConfettiPainter(_pieces, t))),
              Center(
                child: Opacity(
                  opacity: textOpacity.clamp(0, 1).toDouble(),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * math.sin(math.min(t * 3, 1) * math.pi / 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(color: AppColors.sun, width: 6),
                      ),
                      child: Text(widget.text, style: titleStyle(44, AppColors.success)),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Piece {
  final double x, speed, drift, spin;
  final Color color;
  final bool star;
  _Piece({required this.x, required this.speed, required this.drift, required this.spin, required this.color, required this.star});
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = (t * p.speed * 1.3 - 0.15) * size.height;
      final x = (p.x + p.drift * t) * size.width;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      final paint = Paint()..color = p.color;
      if (p.star) {
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? 16.0 : 7.0;
          final a = -math.pi / 2 + i * math.pi / 5;
          final pt = Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), paint);
      } else {
        canvas.drawRect(const Rect.fromLTWH(-7, -4, 14, 8), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
