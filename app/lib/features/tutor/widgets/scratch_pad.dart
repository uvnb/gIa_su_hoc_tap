import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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

  /// Chiều cao tờ nháp (tự dài thêm khi viết gần mép dưới); giữ lại khi đóng/mở bảng nháp.
  double height = 0;

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
    height = 0;
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
  static const _maxPages = 10;
  final _scroll = ScrollController();
  Color _color = AppColors.ink;
  bool _eraser = false;
  bool _sending = false;
  bool _handMode = false; // "✋ Kéo giấy": một ngón tay để cuộn thay vì viết
  bool _scrolling = false; // cử chỉ hiện tại đang cuộn (2 ngón hoặc chế độ kéo giấy)
  bool _drawing = false;
  double _viewport = 600;
  double _width = 800;

  ScratchController get c => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Viết gần mép dưới → tờ giấy tự dài thêm một trang.
  void _maybeGrow(double y) {
    if (y > c.height - _viewport * 0.4 && c.height < _viewport * _maxPages) {
      setState(() => c.height += _viewport);
    }
  }

  void _scrollBy(double dy, {bool animate = false}) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + dy).clamp(0.0, _scroll.position.maxScrollExtent).toDouble();
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  /// Xuất CẢ tờ nháp (đến chỗ đã viết) thành ảnh PNG – không chỉ phần đang hiện trên màn hình.
  Future<Uint8List?> _exportPng() async {
    var used = 0.0;
    for (final s in c.strokes) {
      for (final p in s.points) {
        if (p.dy > used) used = p.dy;
      }
    }
    final h = (used + 80).clamp(300.0, c.height).toDouble();
    final rec = ui.PictureRecorder();
    _ScratchPainter(c.strokes).paint(Canvas(rec), Size(_width, h));
    final img = await rec.endRecording().toImage(_width.round(), h.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _send() async {
    if (c.isEmpty || _sending) return;
    setState(() => _sending = true);
    final png = await _exportPng();
    if (png == null) {
      setState(() => _sending = false);
      return;
    }
    await widget.onSend(png);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
                        _handMode = false;
                      }),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: !_eraser && !_handMode && _color == col ? AppColors.sun : Colors.white, width: 6),
                        ),
                      ),
                    ),
                  _tool(
                      '🧽',
                      'Tẩy',
                      _eraser && !_handMode,
                      () => setState(() {
                            _eraser = true;
                            _handMode = false;
                          })),
                  _tool('✋', 'Kéo giấy', _handMode, () => setState(() => _handMode = !_handMode)),
                  _tool('↩️', 'Lùi lại', false, c.undo),
                  _tool('🗑️', 'Xóa hết', false, () async {
                    if (await confirmWithPicture(context, emoji: '🗑️', question: 'Xóa hết bảng nháp nhé?')) {
                      c.clear();
                      setState(() => c.height = _viewport * 2);
                      if (_scroll.hasClients) _scroll.jumpTo(0);
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
                          child:
                              Text(widget.problem, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(20)),
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 8, 16),
                      child: Row(
                        children: [
                          Expanded(child: _paper()),
                          const SizedBox(width: 8),
                          _scrollBar(),
                        ],
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

  /// Tờ giấy dài: 1 ngón viết · 2 ngón (hoặc chế độ ✋) kéo giấy lên xuống.
  Widget _paper() {
    return LayoutBuilder(builder: (context, box) {
      _viewport = box.maxHeight;
      _width = box.maxWidth;
      if (c.height < _viewport * 2) c.height = _viewport * 2; // mặc định 2 trang
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          controller: _scroll,
          physics: const NeverScrollableScrollPhysics(), // cuộn do mình điều khiển để không lẫn với nét viết
          child: GestureDetector(
            onScaleStart: (d) {
              _scrolling = _handMode || d.pointerCount >= 2;
              _drawing = !_scrolling;
              if (_drawing) {
                c.start(d.localFocalPoint, _eraser ? Colors.white : _color, _eraser ? 34 : 6);
              }
            },
            onScaleUpdate: (d) {
              if (d.pointerCount >= 2 && _drawing) {
                // ngón thứ hai chạm vào → chuyển sang cuộn, bỏ nét vừa chớm vẽ
                _drawing = false;
                _scrolling = true;
                if (c.strokes.isNotEmpty && c.strokes.last.points.length < 4) c.undo();
              }
              if (_scrolling) {
                _scrollBy(-d.focalPointDelta.dy);
              } else if (_drawing) {
                c.add(d.localFocalPoint);
                _maybeGrow(d.localFocalPoint.dy);
              }
            },
            onScaleEnd: (_) {
              _scrolling = false;
              _drawing = false;
            },
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) => CustomPaint(
                painter: _ScratchPainter(c.strokes),
                size: Size(box.maxWidth, c.height),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// Thanh cuộn to cho ngón tay trẻ em: ⬆️ · kéo · ⬇️, kèm số trang.
  Widget _scrollBar() {
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          _arrow('⬆️', () => _scrollBy(-_viewport * 0.6, animate: true)),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              return GestureDetector(
                onVerticalDragUpdate: (d) {
                  if (!_scroll.hasClients) return;
                  final max = _scroll.position.maxScrollExtent;
                  _scrollBy(d.delta.dy * (max + _viewport) / box.maxHeight);
                },
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scroll, c]),
                  builder: (_, __) {
                    final total = c.height <= 0 ? 1.0 : c.height;
                    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                    final thumbH = (box.maxHeight * _viewport / total).clamp(40.0, box.maxHeight).toDouble();
                    final top = ((box.maxHeight - thumbH) * (offset / (total - _viewport).clamp(1, double.infinity)))
                        .clamp(0.0, box.maxHeight - thumbH)
                        .toDouble();
                    final page = ((offset + _viewport / 2) / _viewport).floor() + 1;
                    final pages = (total / _viewport).ceil();
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.softSky,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                        Positioned(
                          top: top,
                          left: 6,
                          right: 6,
                          height: thumbH,
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.sky,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text('$page/$pages',
                                textAlign: TextAlign.center, style: bodyStyle(15, Colors.white, FontWeight.w800)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          _arrow('⬇️', () {
            // Ở cuối giấy mà bấm xuống → thêm trang mới để viết tiếp.
            if (_scroll.hasClients &&
                _scroll.offset >= _scroll.position.maxScrollExtent - 4 &&
                c.height < _viewport * _maxPages) {
              setState(() => c.height += _viewport);
              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollBy(_viewport * 0.6, animate: true));
            } else {
              _scrollBy(_viewport * 0.6, animate: true);
            }
          }),
        ],
      ),
    );
  }

  Widget _arrow(String emoji, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child:
              SizedBox(width: 76, height: 72, child: Center(child: Text(emoji, style: const TextStyle(fontSize: 32)))),
        ),
      );

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
