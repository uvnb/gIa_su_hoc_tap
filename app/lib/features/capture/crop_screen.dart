import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/image_utils.dart';
import '../../core/providers.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';

/// FR-11: kiểm tra ảnh mờ/tối · FR-12: cắt chọn phần muốn làm · nén ảnh trong isolate.
class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({super.key, required this.bytes, required this.subject});
  final Uint8List bytes;
  final String subject;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  Uint8List? _preview; // ảnh đã xoay đúng chiều + thu nhỏ
  Size? _imgSize;
  Rect _crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95); // tỉ lệ 0..1
  ImageQuality? _quality;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final small = await shrinkInBackground(widget.bytes);
    final img = await decodeImageFromList(small);
    if (!mounted) return;
    setState(() {
      _preview = small;
      _imgSize = Size(img.width.toDouble(), img.height.toDouble());
    });
    final q = await qualityInBackground(small);
    if (!mounted) return;
    setState(() => _quality = q);
    final tts = ref.read(ttsProvider);
    if (q.dark) {
      tts.say('Ảnh hơi tối, mình bật đèn rồi chụp lại nhé!');
    } else if (q.blurry) {
      tts.say('Ảnh hơi mờ, mình chụp lại nhé!');
    } else {
      tts.say('Bạn kéo khung để chọn câu muốn làm, rồi bấm Gửi cho Cú nhé!');
    }
  }

  Future<void> _send({bool whole = false}) async {
    if (_sending) return;
    setState(() => _sending = true);
    final r = whole ? const Rect.fromLTRB(0, 0, 1, 1) : _crop;
    final jpeg = await cropInBackground(CropRequest(widget.bytes, r.left, r.top, r.right, r.bottom));
    if (!mounted) return;
    context.pushReplacement('/tutor', extra: TutorLaunch(jpeg: jpeg, subject: widget.subject));
  }

  @override
  Widget build(BuildContext context) {
    final q = _quality;
    final bad = q != null && !q.ok;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _preview == null || _imgSize == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(builder: (context, box) => _cropper(box)),
              ),
            ),
            Container(
              width: 320,
              color: AppColors.softSky,
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  OwlView(mood: bad ? 'encouraging' : 'asking', size: 150),
                  const SizedBox(height: 8),
                  Text(
                    q == null
                        ? 'Cú đang xem ảnh…'
                        : q.dark
                            ? 'Ảnh hơi tối. Mình chụp lại nhé!'
                            : q.blurry
                                ? 'Ảnh hơi mờ. Mình chụp lại nhé!'
                                : 'Kéo khung vàng để chọn câu muốn làm.',
                    textAlign: TextAlign.center,
                    style: titleStyle(24),
                  ),
                  const Spacer(),
                  if (_sending)
                    const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: bad ? AppColors.orange : Colors.white,
                            foregroundColor: bad ? Colors.white : AppColors.ink),
                        onPressed: () => context.pushReplacement('/capture', extra: widget.subject),
                        child: const Text('📸 Chụp lại'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _preview == null ? null : () => _send(whole: true),
                        child: const Text('📄 Gửi cả trang'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: bad ? Colors.white : AppColors.success,
                            foregroundColor: bad ? AppColors.ink : Colors.white),
                        onPressed: _preview == null ? null : () => _send(),
                        child: const Text('✅ Gửi phần đã chọn'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Ảnh + khung cắt kéo được (4 góc to cho ngón tay trẻ em).
  Widget _cropper(BoxConstraints box) {
    final img = _imgSize!;
    final scale = (box.maxWidth / img.width).clamp(0.0, box.maxHeight / img.height).toDouble();
    final w = img.width * scale, h = img.height * scale;
    final ox = (box.maxWidth - w) / 2, oy = (box.maxHeight - h) / 2;
    final rect = Rect.fromLTRB(ox + _crop.left * w, oy + _crop.top * h, ox + _crop.right * w, oy + _crop.bottom * h);

    void moveCorner(int corner, Offset delta) {
      final dx = delta.dx / w, dy = delta.dy / h;
      var l = _crop.left, t = _crop.top, r = _crop.right, b = _crop.bottom;
      if (corner == 0 || corner == 2) l = (l + dx).clamp(0.0, r - 0.1).toDouble();
      if (corner == 1 || corner == 3) r = (r + dx).clamp(l + 0.1, 1.0).toDouble();
      if (corner == 0 || corner == 1) t = (t + dy).clamp(0.0, b - 0.1).toDouble();
      if (corner == 2 || corner == 3) b = (b + dy).clamp(t + 0.1, 1.0).toDouble();
      setState(() => _crop = Rect.fromLTRB(l, t, r, b));
    }

    void moveAll(Offset delta) {
      final dx = (delta.dx / w).clamp(-_crop.left, 1 - _crop.right).toDouble();
      final dy = (delta.dy / h).clamp(-_crop.top, 1 - _crop.bottom).toDouble();
      setState(() => _crop = _crop.shift(Offset(dx, dy)));
    }

    const handle = 56.0;
    final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
    return Stack(
      children: [
        Positioned(left: ox, top: oy, width: w, height: h, child: Image.memory(_preview!, fit: BoxFit.fill)),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ShadePainter(rect)))),
        Positioned.fromRect(
          rect: rect,
          child: GestureDetector(onPanUpdate: (d) => moveAll(d.delta), child: Container(color: Colors.transparent)),
        ),
        for (var i = 0; i < 4; i++)
          Positioned(
            left: corners[i].dx - handle / 2,
            top: corners[i].dy - handle / 2,
            width: handle,
            height: handle,
            child: GestureDetector(
              onPanUpdate: (d) => moveCorner(i, d.delta),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.sun,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShadePainter extends CustomPainter {
  _ShadePainter(this.rect);
  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()..addRect(Offset.zero & size);
    final inner = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    canvas.drawPath(
        Path.combine(ui.PathOperation.difference, outer, inner), Paint()..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..color = AppColors.sun
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
  }

  @override
  bool shouldRepaint(_ShadePainter old) => old.rect != rect;
}
