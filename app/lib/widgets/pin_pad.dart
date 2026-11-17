import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bàn phím mã PIN 4 số (FR-04, ParentGate).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.length = 4, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final int length;
  final bool enabled;

  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> {
  String _pin = '';

  void clear() => setState(() => _pin = '');

  void _press(String k) {
    if (!widget.enabled) return;
    setState(() {
      if (k == '⌫') {
        if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
      } else if (_pin.length < widget.length) {
        _pin += k;
      }
    });
    if (_pin.length == widget.length) {
      final p = _pin;
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          widget.onCompleted(p);
          setState(() => _pin = '');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            widget.length,
            (i) => Container(
              margin: const EdgeInsets.all(8),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? AppColors.ink : Colors.white,
                border: Border.all(color: AppColors.ink, width: 3),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 3 * 88,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keys)
                SizedBox(
                  width: 80,
                  height: 68,
                  child: k.isEmpty
                      ? const SizedBox()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            padding: EdgeInsets.zero,
                            elevation: 1,
                          ),
                          onPressed: widget.enabled ? () => _press(k) : null,
                          child: Text(k, style: titleStyle(30)),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
