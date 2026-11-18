import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/game_timer.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';

/// FR-51 / FR-52: hết giờ học hoặc tới giờ ngủ → Cú "đi ngủ", khóa phiên mới.
/// Chỉ bố mẹ (qua mã PIN) mới mở thêm giờ được.
class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({super.key, this.reason = 'limit'});
  final String reason; // limit | bedtime | game (hết giờ chơi trò chơi)

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.reason == 'game') {
      // Lời nhắc của bố mẹ (nếu đã ghi âm) thay cho giọng Cú.
      final child = ref.read(activeChildProvider);
      ref.read(parentVoiceProvider).play('time_up', childId: child?.id, cooldown: Duration.zero).then((played) {
        if (!played) {
          ref.read(ttsProvider).say('Hết giờ chơi hôm nay rồi! Mình nghỉ mắt một chút, mai chơi tiếp nhé!');
        }
      });
      return;
    }
    ref.read(ttsProvider).say(widget.reason == 'bedtime'
        ? 'Tới giờ đi ngủ rồi! Cú đi ngủ đây. Chúc bạn ngủ ngon nhé!'
        : 'Hôm nay bạn học chăm lắm rồi! Cú đi ngủ đây, mai mình học tiếp nhé!');
  }

  @override
  Widget build(BuildContext context) {
    final bedtime = widget.reason == 'bedtime';
    final game = widget.reason == 'game';
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
                  Text(bedtime ? '🌙 Tới giờ ngủ rồi' : (game ? '🎮 Hết giờ chơi rồi' : '😴 Cú buồn ngủ quá'),
                      style: titleStyle(44, Colors.white)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 520,
                    child: Text(
                      bedtime
                          ? 'Mình ngủ thật ngon để mai học tiếp nhé!'
                          : (game
                              ? 'Điểm của bạn đã được lưu. Mình nghỉ mắt, đi chơi với gia đình nhé! Mai chơi tiếp nha!'
                              : 'Hôm nay bạn học chăm lắm rồi. Mai mình học tiếp nha!'),
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
                        final ok = await context.push<bool>('/parent', extra: game ? 'grantGame15' : 'grant15');
                        if (ok == true && context.mounted) {
                          if (game) ref.read(gameTimerProvider.notifier).refresh();
                          context.go(game ? '/games' : '/home');
                        }
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
