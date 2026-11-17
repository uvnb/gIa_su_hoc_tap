import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../theme/app_theme.dart';

/// Nút lớn cho trẻ: biểu tượng + chữ, chạm có tiếng "pop" (mục 6.5: biểu tượng luôn kèm chữ).
class BigButton extends ConsumerWidget {
  const BigButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.color = AppColors.orange,
    this.width = 240,
    this.height = 170,
    this.speakLabel = true,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double width;
  final double height;
  final bool speakLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: enabled ? color : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(32),
        elevation: enabled ? 4 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: enabled
              ? () {
                  ref.read(soundProvider).pop();
                  onTap!();
                }
              : null,
          onLongPress: speakLabel ? () => ref.read(ttsProvider).say(label) : null,
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: TextStyle(fontSize: height * 0.36)),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: titleStyle(26, enabled ? Colors.white : Colors.grey.shade600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút tròn nhỏ có chữ dưới (thanh công cụ dưới màn gia sư).
class ToolButton extends ConsumerWidget {
  const ToolButton({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.active = false,
  });

  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: active ? AppColors.sun : color,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap == null
            ? null
            : () {
                ref.read(soundProvider).pop();
                onTap!();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 120, minHeight: AppSizes.minButton + 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 8),
                Text(label, style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút loa 🔊 đọc to một đoạn chữ (FR-27; mục 2.1: mọi chữ đều có nút loa).
class SpeakButton extends ConsumerWidget {
  const SpeakButton({super.key, required this.text, this.size = 40});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Nghe lại',
      iconSize: size,
      onPressed: () => ref.read(ttsProvider).say(text),
      icon: const Text('🔊', style: TextStyle(fontSize: 30)),
    );
  }
}

/// Huy hiệu sao ⭐ N
class StarBadge extends StatelessWidget {
  const StarBadge({super.key, required this.stars, this.big = false});
  final int stars;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 18 : 14, vertical: big ? 8 : 6),
      decoration: BoxDecoration(color: AppColors.sun, borderRadius: BorderRadius.circular(30)),
      child: Text('⭐ $stars', style: titleStyle(big ? 30 : 24)),
    );
  }
}

/// Hỏi lại bằng hình trước hành động phá hủy (mục 6.5): ✅ / ❌ to, dễ hiểu.
Future<bool> confirmWithPicture(BuildContext context, {required String emoji, required String question}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 12),
          Text(question, textAlign: TextAlign.center, style: titleStyle(28)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        _PictureChoice(emoji: '❌', label: 'Không', color: Colors.white, onTap: () => Navigator.pop(ctx, false)),
        _PictureChoice(emoji: '✅', label: 'Đồng ý', color: AppColors.success, onTap: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return r ?? false;
}

class _PictureChoice extends StatelessWidget {
  const _PictureChoice({required this.emoji, required this.label, required this.color, required this.onTap});
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 150,
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 34)),
              Text(label, style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bong bóng lời nói của Cú (dùng ở màn chính / nghỉ / ngủ).
class OwlSpeech extends StatelessWidget {
  const OwlSpeech({super.key, required this.text, this.maxWidth = 520});
  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(22, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(text, style: titleStyle(30))),
          SpeakButton(text: text),
        ],
      ),
    );
  }
}

String subjectName(String s) => switch (s) {
      'vietnamese' => 'Tiếng Việt',
      'english' => 'Tiếng Anh',
      'science' => 'Khám phá',
      _ => 'Toán',
    };
