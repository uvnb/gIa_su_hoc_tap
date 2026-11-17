import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';

/// FR-50: Nghỉ giải lao – Cú rủ vươn vai, nhìn xa 20 giây, chớp mắt.
class BreakTimeScreen extends ConsumerStatefulWidget {
  const BreakTimeScreen({super.key});

  @override
  ConsumerState<BreakTimeScreen> createState() => _BreakTimeScreenState();
}

class _Step {
  final String emoji;
  final String text;
  final int seconds;
  final String mood;
  const _Step(this.emoji, this.text, this.seconds, this.mood);
}

const _steps = [
  _Step('🙆', 'Đứng dậy, vươn vai thật cao nào!', 8, 'celebrating'),
  _Step('🌳', 'Nhìn ra cửa sổ, nhìn thật xa nhé!', 20, 'idle'),
  _Step('😉', 'Chớp mắt thật chậm 5 lần nào!', 6, 'encouraging'),
  _Step('💧', 'Uống một ngụm nước nhé!', 5, 'asking'),
];

class _BreakTimeScreenState extends ConsumerState<BreakTimeScreen> {
  int _i = 0;
  int _left = _steps.first.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _startStep();
  }

  void _startStep() {
    final s = _steps[_i];
    _left = s.seconds;
    ref.read(ttsProvider).say(s.text);
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        _t?.cancel();
        ref.read(soundProvider).ting();
        if (_i < _steps.length - 1) {
          setState(() => _i++);
          _startStep();
        } else {
          setState(() => _i = _steps.length);
          ref.read(ttsProvider).say('Giỏi quá! Mình học tiếp nhé!');
        }
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _i >= _steps.length;
    final s = done ? null : _steps[_i];
    return Scaffold(
      backgroundColor: AppColors.softSky,
      body: SafeArea(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OwlView(mood: s?.mood ?? 'celebrating', size: 260),
              const SizedBox(width: 40),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('☕ Giờ giải lao', style: titleStyle(40)),
                  const SizedBox(height: 16),
                  if (s != null) ...[
                    Text(s.emoji, style: const TextStyle(fontSize: 110)),
                    SizedBox(width: 520, child: Text(s.text, textAlign: TextAlign.center, style: titleStyle(32))),
                    const SizedBox(height: 10),
                    Text('$_left', style: titleStyle(64, AppColors.orange)),
                  ] else ...[
                    const Text('🌟', style: TextStyle(fontSize: 110)),
                    Text('Khỏe re rồi!', style: titleStyle(34)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () => context.pop(), child: const Text('📚 Học tiếp')),
                  ],
                  if (!done)
                    TextButton(
                      onPressed: () {
                        _t?.cancel();
                        setState(() => _i = _steps.length);
                      },
                      child: Text('Bỏ qua', style: bodyStyle(18, Colors.grey.shade700)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
