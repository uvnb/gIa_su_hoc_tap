import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/neural_tts.dart';
import '../../core/providers.dart';
import '../../models/app_settings.dart';
import '../../theme/app_theme.dart';

const _sample = 'Xin chào! Tớ là Cú Tò Mò. Hôm nay mình cùng học nhé!';

/// Chọn kiểu giọng Cú (Góc phụ huynh → Cài đặt). Giọng tiếng Việt là giọng người thật chạy trên máy.
class VoicePicker extends ConsumerStatefulWidget {
  const VoicePicker({super.key});

  @override
  ConsumerState<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends ConsumerState<VoicePicker> {
  Future<void> _save(AppSettings s) async {
    await ref.read(settingsProvider.notifier).save(s);
    await ref.read(ttsProvider).say(_sample);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Kiểu giọng (chạm để nghe thử)', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in voicePresets)
              _PresetCard(
                preset: p,
                selected: s.voicePreset == p.id,
                onTap: () => _save(s.copyWith(voicePreset: p.id, ttsRate: p.rate, ttsPitch: p.pitch)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: ref.read(ttsProvider).natural,
          builder: (context, natural, _) => Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: natural ? const Color(0xFFE8F8EE) : const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Text(natural ? '🗣️' : '⏳', style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        natural
                            ? 'Cú đang dùng giọng người thật – chạy ngay trên máy, không cần mạng'
                            : 'Đang nạp giọng người thật cho Cú (vài giây ở lần mở đầu tiên)…',
                        style: bodyStyle(17, AppColors.ink, FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(NeuralTts.credit, style: bodyStyle(13, Colors.grey.shade700, FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.selected, required this.onTap});
  final VoicePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.sun : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppColors.orange : AppColors.softSky, width: 3),
          ),
          child: Row(
            children: [
              Text(preset.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(child: Text(preset.label, style: bodyStyle(18, AppColors.ink, FontWeight.w800))),
              const Text('▶️', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}
