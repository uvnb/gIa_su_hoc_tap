import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';

/// FR-51 / FR-52: hết giờ học hoặc tới giờ ngủ → Cú "đi ngủ", khóa phiên mới.
/// Chỉ bố mẹ (qua mã PIN) mới mở thêm giờ được.
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key, this.reason = 'limit'});
  final String reason; // limit | bedtime

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(ttsProvider).say(widget.reason == 'bedtime'
        ? 'Tới giờ đi ngủ rồi! Cú đi ngủ đây. Chúc bạn ngủ ngon nhé!'
        : 'Hôm nay bạn học chăm lắm rồi! Cú đi ngủ đây, mai mình học tiếp nhé!');
  }

  @override
  Widget build(BuildContext context) {
    final bedtime = widget.reason == 'bedtime';
    return Scaffold(
      backgroundColor: const Color(0xFF2B3A6B),
      body: SafeArea(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const OwlView(mood: 'sleepy', size: 280),
              const SizedBox(width: 40),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bedtime ? '🌙 Tới giờ ngủ rồi' : '😴 Cú buồn ngủ quá', style: titleStyle(44, Colors.white)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 520,
                    child: Text(
                      bedtime
                          ? 'Mình ngủ thật ngon để mai học tiếp nhé!'
                          : 'Hôm nay bạn học chăm lắm rồi. Mai mình học tiếp nha!',
                      style: bodyStyle(26, Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(children: [
                    ElevatedButton(onPressed: () => context.go('/home'), child: const Text('🏠 Về màn chính')),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: () async {
                        final ok = await context.push<bool>('/parent', extra: 'grant15');
                        if (ok == true && context.mounted) context.go('/home');
                      },
                      child: const Text('👨‍👩‍👧 Bố mẹ cho thêm 15 phút'),
                    ),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
