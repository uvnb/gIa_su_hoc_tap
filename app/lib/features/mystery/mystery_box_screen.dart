import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owl_view.dart';

/// FR-42: 🎁 Hộp bí ẩn hôm nay – chạm/lắc hộp để mở một câu đố hoặc câu hỏi khám phá.
/// App chỉ nhận CÂU HỎI; lời giải do backend tính và giữ bí mật.
class MysteryBoxScreen extends ConsumerStatefulWidget {
  const MysteryBoxScreen({super.key});

  @override
  ConsumerState<MysteryBoxScreen> createState() => _MysteryBoxScreenState();
}

class _MysteryBoxScreenState extends ConsumerState<MysteryBoxScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  int _taps = 0;
  Map<String, dynamic>? _item;
  bool _offline = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    ref.read(ttsProvider).say('Chạm vào hộp 3 lần để mở nhé!');
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tapBox() async {
    if (_item != null || _loading) return;
    ref.read(soundProvider).pop();
    _shake.forward(from: 0);
    setState(() => _taps++);
    if (_taps < 3) return;
    setState(() => _loading = true);
    try {
      final grade = ref.read(activeChildProvider)?.grade ?? 1;
      final item = await ref.read(apiProvider).mysteryBox(grade);
      if (!mounted) return;
      ref.read(soundProvider).tada();
      setState(() {
        _item = item;
        _loading = false;
      });
      final kind = item['kind'] == 'kham_pha' ? 'Câu hỏi khám phá' : 'Câu đố vui';
      ref.read(ttsProvider).say('$kind hôm nay: ${item['question']}');
    } on ApiOffline {
      setState(() {
        _offline = true;
        _loading = false;
      });
      ref.read(ttsProvider).say('Mạng đang nghỉ mất rồi. Mình luyện tập không cần mạng nhé!');
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(children: [
                OutlinedButton(onPressed: () => context.pop(), child: const Text('← Về')),
                const SizedBox(width: 20),
                Text('🎁 Hộp bí ẩn hôm nay', style: titleStyle(34)),
              ]),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OwlView(mood: item != null ? 'celebrating' : 'asking', size: 220),
                    const SizedBox(width: 40),
                    if (item == null)
                      GestureDetector(
                        onTap: _tapBox,
                        child: AnimatedBuilder(
                          animation: _shake,
                          builder: (_, child) => Transform.rotate(
                            angle: math.sin(_shake.value * math.pi * 6) * 0.12 * (1 - _shake.value),
                            child: child,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_loading ? '✨' : '🎁', style: const TextStyle(fontSize: 180)),
                              Text(
                                _offline
                                    ? 'Mạng đang nghỉ 😴'
                                    : (_loading ? 'Đang mở…' : 'Chạm ${3 - _taps} lần nữa!'),
                                style: titleStyle(30),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 560,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.think, width: 4),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['kind'] == 'kham_pha' ? '🔭 Câu hỏi khám phá' : '🧩 Câu đố vui',
                                style: titleStyle(26, AppColors.think)),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: Text('${item['question']}', style: titleStyle(30))),
                              SpeakButton(text: '${item['question']}'),
                            ]),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                              onPressed: () => context.pushReplacement('/tutor',
                                  extra: TutorLaunch(
                                    questionText: '${item['question']}',
                                    subject: '${item['subject'] ?? 'math'}',
                                    fromMysteryBox: true,
                                  )),
                              child: const Text('🦉 Cùng Cú tìm hiểu'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_offline)
                ElevatedButton(
                  onPressed: () => context.pushReplacement('/practice', extra: 'math'),
                  child: const Text('🧩 Luyện tập không cần mạng'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
