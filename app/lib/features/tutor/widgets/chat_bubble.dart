import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/common.dart';

/// Bong bóng bo tròn, chữ ≥ 22sp, có nút 🔊 nghe lại trên mọi lời Cú (FR-27).
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.fromOwl, required this.text, this.avatar = '🧒'});

  final bool fromOwl;
  final String text;
  final String avatar;

  @override
  Widget build(BuildContext context) {
    final bubble = Flexible(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: EdgeInsets.fromLTRB(18, 12, fromOwl ? 4 : 18, 12),
        decoration: BoxDecoration(
          color: fromOwl ? Colors.white : AppColors.softSky,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(fromOwl ? 4 : 24),
            bottomRight: Radius.circular(fromOwl ? 24 : 4),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text, style: bodyStyle(24, AppColors.ink, FontWeight.w700))),
            if (fromOwl) SpeakButton(text: text, size: 32),
          ],
        ),
      ),
    );
    final face = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(fromOwl ? '🦉' : avatar, style: const TextStyle(fontSize: 34)),
    );
    return Row(
      mainAxisAlignment: fromOwl ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: fromOwl ? [face, bubble, const SizedBox(width: 40)] : [const SizedBox(width: 40), bubble, face],
    );
  }
}
