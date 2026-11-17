import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/permissions.dart';
import '../core/providers.dart';
import '../core/web_env.dart';
import 'web_help.dart';
import '../theme/app_theme.dart';

/// Nút micro "giữ để nói" (mục 14.6): tròn 96dp, sóng âm khi nghe, trả chữ nhận dạng khi thả tay.
class MicButton extends ConsumerStatefulWidget {
  const MicButton({
    super.key,
    required this.onFinal,
    this.onPartial,
    this.onListening,
    this.size = 96,
    this.label = 'Giữ để nói',
    this.enabled = true,
  });

  final ValueChanged<String> onFinal;
  final ValueChanged<String>? onPartial;
  final ValueChanged<bool>? onListening;
  final double size;
  final String label;
  final bool enabled;

  @override
  ConsumerState<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends ConsumerState<MicButton> {
  bool _held = false;
  bool _done = true;
  String _text = '';
  Timer? _finalizeTimer;
  late final _stt = ref.read(sttProvider);

  Future<void> _down() async {
    if (!widget.enabled) return;
    if (isInsecureWebContext) {
      // Trình duyệt chặn micro trên trang http:// → hướng dẫn bố mẹ bật một lần.
      ref.read(ttsProvider).say('Micro chưa bật. Nhờ bố mẹ bật giúp nhé!');
      if (mounted) showWebPermissionHelp(context);
      return;
    }
    if (!await ensurePermission(Permission.microphone)) {
      ref.read(ttsProvider).say('Cú cần quyền dùng micro. Nhờ bố mẹ bật giúp nhé!');
      return;
    }
    await ref.read(ttsProvider).stop(); // không để Cú tự nghe giọng mình
    _held = true;
    _done = false;
    _text = '';
    setState(() {});
    widget.onListening?.call(true);
    ref.read(soundProvider).pop();
    await _stt.listen((t, isFinal) {
      _text = t;
      widget.onPartial?.call(t);
      if (isFinal && !_held) _finalize();
    });
    if (!_stt.ready) {
      _held = false;
      widget.onListening?.call(false);
      ref.read(ttsProvider).say('Máy chưa nghe được giọng nói. Bạn bấm bàn phím số nhé!');
      setState(() {});
    }
  }

  Future<void> _up() async {
    if (!_held) return;
    _held = false;
    setState(() {});
    await _stt.stop();
    // Kết quả cuối thường tới ngay sau khi dừng; chờ tối đa 1.2 giây.
    _finalizeTimer?.cancel();
    _finalizeTimer = Timer(const Duration(milliseconds: 1200), _finalize);
  }

  void _finalize() {
    if (_done) return;
    _done = true;
    _finalizeTimer?.cancel();
    widget.onListening?.call(false);
    widget.onFinal(_text.trim());
  }

  @override
  void dispose() {
    _finalizeTimer?.cancel();
    if (_held) _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stt = ref.watch(sttProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Listener(
          onPointerDown: (_) => _down(),
          onPointerUp: (_) => _up(),
          onPointerCancel: (_) => _up(),
          child: ValueListenableBuilder<double>(
            valueListenable: stt.level,
            builder: (_, level, __) {
              final ring = _held ? (8 + (level.clamp(0, 10) * 2.2)).toDouble() : 0.0;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: widget.size + ring * 2,
                height: widget.size + ring * 2,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _held ? AppColors.sky.withValues(alpha: 0.25) : Colors.transparent,
                ),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !widget.enabled ? Colors.grey.shade300 : (_held ? AppColors.success : AppColors.sky),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
                  ),
                  child: Text(_held ? '👂' : '🎤', style: TextStyle(fontSize: widget.size * 0.45)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(_held ? 'Cú đang nghe… thả tay khi nói xong' : '👆 ${widget.label}',
            style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
      ],
    );
  }
}
