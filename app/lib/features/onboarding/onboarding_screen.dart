import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/pin_pad.dart';
import 'profile_form.dart';

/// Lần đầu mở app (FR-01, FR-02, FR-04):
/// 1) Cú chào  2) Phụ huynh đồng ý điều khoản + đặt PIN  3) Tạo hồ sơ bé.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _page = PageController();
  bool _consent = false;
  String? _firstPin;
  String _pinMsg = 'Bố mẹ đặt mã PIN 4 số';
  final _pinKey = GlobalKey<PinPadState>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 600), () {
      ref.read(ttsProvider).say('Xin chào! Tớ là Cú Tò Mò. Bố mẹ giúp tớ cài đặt một chút nhé!');
    });
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() => _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOut);

  Future<void> _onPin(String pin) async {
    if (_firstPin == null) {
      setState(() {
        _firstPin = pin;
        _pinMsg = 'Nhập lại mã PIN để xác nhận';
      });
      return;
    }
    if (_firstPin != pin) {
      setState(() {
        _firstPin = null;
        _pinMsg = 'Hai lần nhập chưa giống nhau. Đặt lại mã PIN nhé';
      });
      return;
    }
    await ref.read(secureStoreProvider).setPin(pin);
    _next();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _page,
          physics: const NeverScrollableScrollPhysics(),
          children: [_welcome(), _parent(), _child()],
        ),
      ),
    );
  }

  Widget _welcome() => Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const OwlView(mood: 'celebrating', size: 280, waving: true),
            const SizedBox(width: 40),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Xin chào! 👋', style: titleStyle(52)),
                Text('Tớ là Cú Tò Mò', style: titleStyle(44, AppColors.sky)),
                const SizedBox(height: 8),
                SizedBox(
                  width: 460,
                  child: Text('Tớ không nói đáp án đâu – tớ giúp bạn TỰ tìm ra!', style: bodyStyle(26)),
                ),
                const SizedBox(height: 28),
                ElevatedButton(onPressed: _next, child: const Text('Bắt đầu  ➜')),
              ],
            ),
          ],
        ),
      );

  Widget _parent() => Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dành cho bố mẹ 👨‍👩‍👧', style: titleStyle(34)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                      child: SingleChildScrollView(
                        child: Text(_consentText, style: bodyStyle(19, AppColors.ink, FontWeight.w500)),
                      ),
                    ),
                  ),
                  CheckboxListTile(
                    value: _consent,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _consent = v ?? false),
                    title: Text('Tôi là cha mẹ / người giám hộ và đồng ý với các điều trên',
                        style: bodyStyle(20, AppColors.ink, FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 28),
            SizedBox(
              width: 300,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_consent ? _pinMsg : 'Đánh dấu đồng ý trước nhé',
                      textAlign: TextAlign.center, style: titleStyle(24)),
                  const SizedBox(height: 10),
                  PinPad(key: _pinKey, enabled: _consent, onCompleted: _onPin),
                  const SizedBox(height: 8),
                  Text('Mã PIN dùng để vào Góc phụ huynh.',
                      textAlign: TextAlign.center, style: bodyStyle(16, Colors.grey.shade700, FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _child() => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OwlView(mood: 'asking', size: 220),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bạn nhỏ tên là gì nhỉ?', style: titleStyle(36)),
                  const SizedBox(height: 12),
                  ProfileForm(
                    onSave: (p) async {
                      await ref.read(profilesProvider.notifier).upsert(p, makeActive: true);
                      await ref.read(localStoreProvider).setOnboardingDone(true);
                      ref.read(deviceServiceProvider).ensureRegistered(); // chạy nền, mất mạng thì để sau
                      if (mounted) context.go('/home');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

const _consentText = '''Cú Tò Mò là gia sư AI cho học sinh tiểu học. Để bé dùng an toàn, xin bố mẹ đọc kỹ:

• Cú KHÔNG BAO GIỜ nói đáp án. Cú chỉ hỏi gợi mở để bé tự tìm ra. Đáp án tham khảo chỉ xem được trong Góc phụ huynh.
• Dữ liệu thu thập tối thiểu: biệt danh, lớp, lịch sử học. KHÔNG thu tên thật, ngày sinh, ảnh khuôn mặt, vị trí.
• Ảnh bài tập chỉ dùng để đọc đề: máy chủ của ứng dụng gửi ảnh tới nhà cung cấp AI (Anthropic Claude hoặc OpenAI ChatGPT) và KHÔNG lưu ảnh. Chữ của đề bài và lịch sử học được giữ tối đa 30 ngày để làm báo cáo cho bố mẹ.
• Giọng nói của bé được nhận dạng ngay trên máy tính bảng; chỉ chữ đã nhận dạng được gửi đi.
• Không quảng cáo, không mua bán trong ứng dụng, không trò chuyện với người lạ, không mở trình duyệt.
• Bố mẹ có thể xem báo cáo học, đặt giới hạn thời gian, giờ ngủ và xóa toàn bộ dữ liệu của bé bất cứ lúc nào trong Góc phụ huynh.
• Việc xử lý dữ liệu cá nhân của trẻ em tuân theo quy định về bảo vệ dữ liệu cá nhân của Việt Nam (Nghị định 13/2023/NĐ-CP và văn bản cập nhật), cần sự đồng ý của cha mẹ hoặc người giám hộ.

Gợi ý: bật "Ghim màn hình" hoặc Google Family Link để bé chỉ dùng ứng dụng này khi học.''';
