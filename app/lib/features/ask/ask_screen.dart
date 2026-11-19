import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';

/// FR-13: nói câu hỏi (giữ nút micro) · FR-14: gõ câu hỏi (lớp 3–5).
/// Luôn hiện chữ nhận dạng để bé/phụ huynh kiểm tra trước khi gửi (mục 12.1).
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key, required this.subject});
  final String subject;

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _text = TextEditingController();
  late String _subject = widget.subject;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    ref.read(ttsProvider).say('Bạn giữ nút micro rồi đọc câu hỏi cho Cú nghe nhé!');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final q = _text.text.trim();
    if (q.isEmpty) return;
    context.pushReplacement('/tutor', extra: TutorLaunch(questionText: q, subject: _subject));
  }

  @override
  Widget build(BuildContext context) {
    final grade = ref.watch(activeChildProvider)?.grade ?? 1;
    final hasText = _text.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  OutlinedButton(onPressed: () => context.pop(), child: const Text('← Về')),
                  const SizedBox(width: 20),
                  Text('Hỏi Cú', style: titleStyle(34)),
                  const Spacer(),
                  for (final s in const ['math', 'vietnamese', 'english', 'vietnam', 'science'])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(s == 'vietnam' ? '🇻🇳 Việt Nam' : subjectName(s),
                            style: bodyStyle(17, AppColors.ink, FontWeight.w800)),
                        selected: _subject == s,
                        selectedColor: AppColors.sun,
                        onSelected: (_) => setState(() => _subject = s),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Row(
                  children: [
                    OwlView(mood: _listening ? 'listening' : 'asking', size: 230),
                    const SizedBox(width: 30),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 140),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.softSky, width: 3),
                            ),
                            child: TextField(
                              controller: _text,
                              maxLines: 4,
                              minLines: 2,
                              // Lớp 1–2 chủ yếu nói, nhưng vẫn cho gõ (bố mẹ gõ giúp khi micro không dùng được).
                              style: bodyStyle(26),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                filled: false,
                                hintText: grade < 3
                                    ? 'Giữ micro rồi đọc câu hỏi (hoặc bố mẹ gõ giúp)'
                                    : 'Nói hoặc gõ câu hỏi ở đây…',
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              MicButton(
                                size: 110,
                                onListening: (v) => setState(() => _listening = v),
                                onPartial: (t) => setState(() => _text.text = t),
                                onFinal: (t) {
                                  setState(() => _text.text = t);
                                  if (t.isNotEmpty) {
                                    ref.read(ttsProvider).say('Cú nghe được: $t. Đúng chưa nào?');
                                  } else {
                                    ref.read(ttsProvider).say('Cú chưa nghe rõ, bạn nói lại nhé!');
                                  }
                                },
                              ),
                              const SizedBox(width: 40),
                              if (hasText) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                  onPressed: _send,
                                  child: const Text('✅ Đúng rồi, hỏi Cú'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: () => setState(() => _text.clear()),
                                  child: const Text('🔁 Xóa'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
