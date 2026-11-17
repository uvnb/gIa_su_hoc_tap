import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/permissions.dart';
import '../../core/providers.dart';
import '../../core/web_env.dart';
import '../../widgets/web_help.dart';
import '../../theme/app_theme.dart';

/// FR-10: chụp bài bằng camera sau, có khung "đặt vở vào khung". Tắt camera ngay sau khi chụp (tiết kiệm pin).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key, required this.subject});
  final String subject;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _torch = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    ref.read(ttsProvider).say('Bạn đặt trang vở vào trong khung nhé!');
  }

  Future<void> _init() async {
    if (isInsecureWebContext) {
      setState(() => _error = 'Camera chưa bật. Nhờ bố mẹ bấm nút vàng "Bật micro & camera" ở màn chính nhé!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showWebPermissionHelp(context);
      });
      return;
    }
    if (!await ensurePermission(Permission.camera)) {
      setState(() => _error = 'Cú cần quyền dùng camera. Nhờ bố mẹ bật quyền Camera cho ứng dụng nhé!');
      return;
    }
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.veryHigh,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      await _flash(c, FlashMode.off);
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } catch (e) {
      setState(() => _error = 'Không mở được camera. Bạn thử lại nhé!');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cam = null;
      c?.dispose();
    } else if (state == AppLifecycleState.resumed && _cam == null && !_busy) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  /// Bật/tắt đèn; trả false nếu máy (hoặc webcam trên trình duyệt) không hỗ trợ.
  Future<bool> _flash(CameraController c, FlashMode mode) async {
    try {
      await c.setFlashMode(mode);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleTorch() async {
    final c = _cam;
    if (c == null) return;
    _torch = !_torch;
    if (!await _flash(c, _torch ? FlashMode.torch : FlashMode.off)) {
      _torch = false; // máy không có đèn flash (bản 2021) hoặc webcam
    }
    setState(() {});
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || _busy) return;
    setState(() => _busy = true);
    ref.read(soundProvider).pop();
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      await _flash(c, FlashMode.off);
      _cam = null;
      await c.dispose(); // tắt camera ngay
      if (!mounted) return;
      context.pushReplacement('/crop', extra: (bytes, widget.subject));
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Chụp chưa được. Bạn thử lại nhé!';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cam;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: c != null && c.value.isInitialized
                  ? GestureDetector(
                      onTapDown: (d) {
                        final box = context.size;
                        if (box == null) return;
                        c
                            .setFocusPoint(Offset(d.localPosition.dx / box.width, d.localPosition.dy / box.height))
                            .catchError((_) {}); // webcam/máy không hỗ trợ lấy nét chạm
                      },
                      child: Center(
                        child: AspectRatio(aspectRatio: c.value.aspectRatio, child: CameraPreview(c)),
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(_error ?? 'Đang mở camera…',
                            textAlign: TextAlign.center, style: titleStyle(28, Colors.white)),
                      ),
                    ),
            ),
            // Khung hướng dẫn bo góc
            const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _FramePainter()))),
            Positioned(
              top: 8,
              left: 8,
              child: _roundButton('←', 'Về', () => context.pop()),
            ),
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
                  child: Text('Đặt trang vở vào khung nhé!', style: titleStyle(28, Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _roundButton('🔦', _torch ? 'Tắt đèn' : 'Bật đèn', _toggleTorch),
            ),
            Positioned(
              right: 36,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _busy ? Colors.grey : Colors.white,
                      border: Border.all(color: AppColors.orange, width: 8),
                    ),
                    alignment: Alignment.center,
                    child: Text(_busy ? '⏳' : 'Chụp', style: titleStyle(26)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundButton(String emoji, String label, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text('$emoji  $label', style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
          ),
        ),
      );
}

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(size.width * 0.12, size.height * 0.16, size.width * 0.80, size.height * 0.92);
    final p = Paint()
      ..color = AppColors.sun
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 56.0;
    for (final (c, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomLeft, 1.0, -1.0),
      (r.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(c, c.translate(l * dx, 0), p);
      canvas.drawLine(c, c.translate(0, l * dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
