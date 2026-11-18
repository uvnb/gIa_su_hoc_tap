import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/web_env.dart';
import '../theme/app_theme.dart';

const _flagsUrl = 'chrome://flags/#unsafely-treat-insecure-origin-as-secure';

/// Nút nhỏ "Bật micro & camera" – chỉ hiện khi mở bản web bằng http:// mà Chrome chưa cho phép.
class WebPermissionBanner extends StatelessWidget {
  const WebPermissionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isInsecureWebContext) return const SizedBox.shrink();
    return Material(
      color: AppColors.sun,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => showWebPermissionHelp(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text('🎤📷 Bố mẹ bật micro & camera (1 lần)', style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
        ),
      ),
    );
  }
}

/// Hướng dẫn bật tùy chọn Chrome bằng SAO CHÉP – DÁN, không phải gõ đường dẫn dài.
Future<void> showWebPermissionHelp(BuildContext context) {
  Future<void> copy(BuildContext ctx, String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx)
          .showSnackBar(SnackBar(content: Text('Đã sao chép $what', style: bodyStyle(18, Colors.white))));
    }
  }

  Widget step(String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 16, backgroundColor: AppColors.sky, child: Text(n, style: titleStyle(18, Colors.white))),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: bodyStyle(19))),
          ],
        ),
      );

  final appUrl = Uri.base.origin;
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cream,
      title: Text('Bật micro & camera cho Cú (làm 1 lần)', style: titleStyle(26)),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step('1',
                  'Bấm nút "Sao chép đường dẫn cài đặt" bên dưới. Mở tab mới, chạm thanh địa chỉ → giữ ngón tay → Dán → Enter.'),
              step(
                  '2',
                  'Quay lại tab Cú Tò Mò, bấm "Sao chép địa chỉ app". Sang lại tab cài đặt, ở mục được tô vàng '
                      '"Insecure origins treated as secure": chạm ô chữ → giữ ngón tay → Dán.'),
              step('3', 'Đổi "Disabled" thành "Enabled", rồi bấm nút "Relaunch" ở dưới cùng.'),
              const SizedBox(height: 8),
              Text('Địa chỉ app: $appUrl', style: bodyStyle(16, Colors.grey.shade700, FontWeight.w600)),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: () => copy(ctx, _flagsUrl, 'đường dẫn cài đặt'),
          child: const Text('📋 1. Sao chép đường dẫn cài đặt'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky),
          onPressed: () => copy(ctx, appUrl, 'địa chỉ app'),
          child: const Text('📋 2. Sao chép địa chỉ app'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
      ],
    ),
  );
}
