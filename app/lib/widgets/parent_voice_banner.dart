import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/game_models.dart';
import '../theme/app_theme.dart';

/// Băng nổi "💌 Lời nhắn của bố mẹ" khi app đang phát đoạn ghi âm của bố mẹ.
/// Chạm vào băng để dừng.
class ParentVoiceBanner extends ConsumerWidget {
  const ParentVoiceBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(parentVoiceProvider);
    return ValueListenableBuilder<ParentVoice?>(
      valueListenable: service.nowPlaying,
      builder: (context, v, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          top: v == null ? -140 : 14,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: service.stop,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 680),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFE0EC), Color(0xFFFFF3C4)]),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFF8FB1), width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('💌', style: TextStyle(fontSize: 40)),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lời nhắn của bố mẹ', style: titleStyle(24, const Color(0xFFE0457B))),
                            if (v != null && v.caption.isNotEmpty)
                              Text(v.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(19)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('🔊', style: TextStyle(fontSize: 30)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
