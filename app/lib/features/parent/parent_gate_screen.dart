import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pin_pad.dart';

/// Đã nhập đúng PIN trong lượt này chưa (tự khóa lại khi rời Góc phụ huynh).
final parentUnlockedProvider = StateProvider<bool>((ref) => false);

/// ParentGate (mục 14.6): bàn phím PIN; khóa 1 phút sau 3 lần sai.
/// next = đường dẫn mở sau khi đúng PIN, hoặc "grant15" = cho bé thêm 15 phút.
class ParentGateScreen extends ConsumerStatefulWidget {
  const ParentGateScreen({super.key, this.next = '/parent/home'});
  final String next;

  @override
  ConsumerState<ParentGateScreen> createState() => _ParentGateScreenState();
}

class _ParentGateScreenState extends ConsumerState<ParentGateScreen> {
  String _msg = 'Nhập mã PIN của bố mẹ';
  DateTime? _lockedUntil;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final until = await ref.read(secureStoreProvider).lockedUntil();
    if (!mounted) return;
    setState(() => _lockedUntil = until);
    _tick?.cancel();
    if (until != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (DateTime.now().isAfter(until)) {
          _tick?.cancel();
          setState(() {
            _lockedUntil = null;
            _msg = 'Nhập mã PIN của bố mẹ';
          });
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _onPin(String pin) async {
    final ok = await ref.read(secureStoreProvider).verifyPin(pin);
    if (!mounted) return;
    if (!ok) {
      setState(() => _msg = 'Mã PIN chưa đúng');
      await _checkLock();
      return;
    }
    if (widget.next == 'grant15') {
      await ref.read(studyTimerProvider.notifier).grantExtra(15);
      if (mounted) context.pop(true);
      return;
    }
    ref.read(parentUnlockedProvider.notifier).state = true;
    if (mounted) context.pushReplacement(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    final locked = _lockedUntil;
    final secs = locked == null ? 0 : locked.difference(DateTime.now()).inSeconds + 1;
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.cream, title: Text('👨‍👩‍👧 Góc phụ huynh', style: titleStyle(28))),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(locked != null ? 'Sai 3 lần. Thử lại sau $secs giây' : _msg, style: titleStyle(28)),
            const SizedBox(height: 16),
            PinPad(enabled: locked == null, onCompleted: _onPin),
          ],
        ),
      ),
    );
  }
}
