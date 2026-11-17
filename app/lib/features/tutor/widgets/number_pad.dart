import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../theme/app_theme.dart';

/// Bàn phím số to (mục 14.6): phím 0–9 cỡ 80dp, ⌫ và ✅. Lớp 4–5 có thêm "," và "/".
class BigNumberPad extends ConsumerStatefulWidget {
  const BigNumberPad({super.key, required this.onSubmit, this.grade = 1, this.onClose, this.onTypeText});

  final ValueChanged<String> onSubmit;
  final int grade;
  final VoidCallback? onClose;
  final VoidCallback? onTypeText; // FR-14: chuyển sang gõ chữ (lớp 3–5)

  @override
  ConsumerState<BigNumberPad> createState() => _BigNumberPadState();
}

class _BigNumberPadState extends ConsumerState<BigNumberPad> {
  String _value = '';

  void _key(String k) {
    ref.read(soundProvider).pop();
    setState(() {
      if (k == '⌫') {
        if (_value.isNotEmpty) _value = _value.substring(0, _value.length - 1);
      } else if (_value.length < 10) {
        _value += k;
      }
    });
    if (k != '⌫') ref.read(ttsProvider).say(k == ',' ? 'phẩy' : (k == '/' ? 'phần' : k));
  }

  void _submit() {
    if (_value.isEmpty) return;
    widget.onSubmit(_value);
    setState(() => _value = '');
  }

  Widget _btn(String k, {Color? color, double width = 80}) => Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          width: width,
          height: 72,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? Colors.white,
              foregroundColor: AppColors.ink,
              padding: EdgeInsets.zero,
              elevation: 1,
            ),
            onPressed: k == '✅' ? _submit : () => _key(k),
            child: Text(k, style: titleStyle(32, k == '✅' ? Colors.white : AppColors.ink)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final extra = widget.grade >= 4;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.softSky,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 200,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Text(_value.isEmpty ? '…' : _value, style: titleStyle(38)),
              ),
              if (widget.onTypeText != null)
                IconButton(
                  tooltip: 'Gõ chữ',
                  onPressed: widget.onTypeText,
                  icon: const Text('⌨️', style: TextStyle(fontSize: 30)),
                ),
              if (widget.onClose != null)
                IconButton(
                  tooltip: 'Đóng',
                  onPressed: widget.onClose,
                  icon: const Text('✖️', style: TextStyle(fontSize: 26)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [_btn('1'), _btn('2'), _btn('3')]),
          Row(mainAxisSize: MainAxisSize.min, children: [_btn('4'), _btn('5'), _btn('6')]),
          Row(mainAxisSize: MainAxisSize.min, children: [_btn('7'), _btn('8'), _btn('9')]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _btn('⌫', color: AppColors.softThink),
            _btn('0'),
            _btn('✅', color: AppColors.success),
          ]),
          if (extra)
            Row(mainAxisSize: MainAxisSize.min, children: [_btn(',', width: 124), _btn('/', width: 124)]),
        ],
      ),
    );
  }
}
