import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  Stroke(this.color, this.width) : points = [];
}

/// Giữ nét vẽ khi đóng/mở lại bảng nháp trong cùng một câu.
class ScratchController extends ChangeNotifier {
  final strokes = <Stroke>[];

  bool get isEmpty => strokes.isEmpty;

  void start(Offset p, Color c, double w) {
    strokes.add(Stroke(c, w)..points.add(p));
    notifyListeners();
  }

  void add(Offset p) {
    if (strokes.isEmpty) return;
    strokes.last.points.add(p);
    notifyListeners();
  }

  void undo() {
    if (strokes.isNotEmpty) strokes.removeLast();
    notifyListeners();
  }

  void clear() {
    strokes.clear();
    notifyListeners();
  }
}

/// FR-23: bảng nháp vẽ tay – 4 màu bút, tẩy, hoàn tác, "Cú xem giúp" (gửi ảnh PNG).
class ScratchPadScreen extends StatefulWidget {
  const ScratchPadScreen({super.key, required this.controller, required this.onSend, this.problem = ''});

  final ScratchController controller;
  final Future<void> Function(Uint8List png) onSend;
  final String problem;

  @override
  State<ScratchPadScreen> createState() => _ScratchPadScreenState();
}

class _ScratchPadScreenState extends State<ScratchPadScreen> {
  static const _colors = [AppColors.ink, AppColors.sky, AppColors.orange, AppColors.success];
  final _key = GlobalKey();
  Color _color = AppColors.ink;
  bool _eraser = false;
  bool _sending = false;

  Future<void> _send() async {
    if (widget.controller.isEmpty || _sending) return;
    setState(() => _sending = true);
    final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      setState(() => _sending = false);
      return;
    }
    await widget.onSend(data.buffer.asUint8List());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Row(
          children: [
            // Thanh công cụ bên trái
            Container(
              width: 120,
              color: AppColors.softSky,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final col in _colors)
                    GestureDetector(
                      onTap: () => setState(() {
                        _color = col;
                        _eraser = false;
                      }),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: !_eraser && _color == col ? AppColors.sun : Colors.white, width: 6),
                        ),
                      ),
                    ),
                  _tool('🧽', 'Tẩy', _eraser, () => setState(() => _eraser = true)),
                  _tool('↩️', 'Lùi lại', false, c.undo),
                  _tool('🗑️', 'Xóa hết', false, () async {
                    if (await confirmWithPicture(context, emoji: '🗑️', question: 'Xóa hết bảng nháp nhé?')) {
                      c.clear();
                    }
                  }),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('← Đóng')),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(widget.problem,
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(20)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                          onPressed: _sending ? null : _send,
                          child: Text(_sending ? 'Cú đang xem…' : '🦉 Cú xem giúp'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: RepaintBoundary(
                          key: _key,
                          child: GestureDetector(
                            onPanStart: (d) => c.start(
                                d.localPosition, _eraser ? Colors.white : _color, _eraser ? 34 : 6),
                            onPanUpdate: (d) => c.add(d.localPosition),
                            child: AnimatedBuilder(
                              animation: c,
                              builder: (_, __) => CustomPaint(
                                painter: _ScratchPainter(c.strokes),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tool(String emoji, String label, bool active, VoidCallback onTap) => Material(
        color: active ? AppColors.sun : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
            width: 92,
            height: 76,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                Text(label, style: bodyStyle(15, AppColors.ink, FontWeight.w800)),
              ],
            ),
          ),
        ),
      );
}

class _ScratchPainter extends CustomPainter {
  _ScratchPainter(this.strokes);
  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    // Nền trắng + dòng kẻ ô li nhạt (ảnh gửi đi có nền trắng)
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final grid = Paint()
      ..color = AppColors.softSky
      ..strokeWidth = 1.5;
    for (double y = 40; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (final s in strokes) {
      final p = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(s.points.first, s.width / 2, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final pt in s.points.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
