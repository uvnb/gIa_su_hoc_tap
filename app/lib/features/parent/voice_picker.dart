import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/app_settings.dart';
import '../../theme/app_theme.dart';

const _sample = 'Xin chào! Tớ là Cú Tò Mò. Hôm nay mình cùng học nhé!';

/// Chọn giọng Cú (Góc phụ huynh → Cài đặt): kiểu giọng dễ thương + giọng tiếng Việt có trên máy.
class VoicePicker extends ConsumerStatefulWidget {
  const VoicePicker({super.key});

  @override
  ConsumerState<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends ConsumerState<VoicePicker> {
  late final Future<List<Map<String, String>>> _voices = ref.read(ttsProvider).vietnameseVoices();

  Future<void> _save(AppSettings s) async {
    await ref.read(settingsProvider.notifier).save(s);
    await ref.read(ttsProvider).say(_sample);
  }

  /// Tên dễ hiểu cho giọng Google TTS (vd. vi-vn-x-gft-local → "Giọng 1 · trên máy").
  String _label(Map<String, String> v, int i) {
    final name = (v['name'] ?? '').toLowerCase();
    final where = name.contains('network') || v['network_required'] == 'true' ? 'cần mạng' : 'trên máy';
    return 'Giọng ${i + 1} · $where';
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
        const SizedBox(height: 18),
        Text('Giọng đọc tiếng Việt trên máy', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
        Text('Kết hợp với kiểu giọng ở trên. Giọng "cần mạng" thường tự nhiên hơn nhưng phải có Internet.',
            style: bodyStyle(15, Colors.grey.shade700, FontWeight.w500)),
        const SizedBox(height: 8),
        FutureBuilder<List<Map<String, String>>>(
          future: _voices,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator());
            }
            final voices = snap.data ?? const [];
            if (voices.isEmpty) {
              return Text(
                  'Máy chưa có giọng tiếng Việt. Vào Cài đặt → Ngôn ngữ & nhập liệu → Chuyển văn bản thành giọng nói '
                  '→ Google → tải "Tiếng Việt".',
                  style: bodyStyle(17));
            }
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _VoiceChip(
                  label: 'Mặc định',
                  selected: s.voiceName.isEmpty,
                  onTap: () => _save(s.copyWith(voiceName: '')),
                ),
                for (var i = 0; i < voices.length; i++)
                  _VoiceChip(
                    label: _label(voices[i], i),
                    selected: s.voiceName == voices[i]['name'],
                    onTap: () => _save(s.copyWith(voiceName: voices[i]['name'] ?? '')),
                  ),
              ],
            );
          },
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

class _VoiceChip extends StatelessWidget {
  const _VoiceChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text('▶️ $label', style: bodyStyle(17, AppColors.ink, FontWeight.w700)),
      ),
      selected: selected,
      selectedColor: AppColors.sun,
      onSelected: (_) => onTap(),
    );
  }
}
