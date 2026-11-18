import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';
import '../tutor/widgets/celebration_overlay.dart';
import '../tutor/widgets/manipulatives.dart';
import '../tutor/widgets/number_pad.dart';
import 'problem_generator.dart';

/// FR-70: chế độ luyện tập không cần mạng. Gợi ý theo thang 6 bậc dựng sẵn – KHÔNG bao giờ nói kết quả.
class OfflinePracticeScreen extends ConsumerStatefulWidget {
  const OfflinePracticeScreen({super.key, this.subject = 'math'});
  final String subject;

  @override
  ConsumerState<OfflinePracticeScreen> createState() => _OfflinePracticeScreenState();
}

class _OfflinePracticeScreenState extends ConsumerState<OfflinePracticeScreen> {
  late final ProblemGenerator _gen = ProblemGenerator(ref.read(activeChildProvider)?.grade ?? 1);
  late final StudyTimer _timer;
  late OfflineProblem _p;
  int _level = 0;
  int _wrong = 0;
  int _stars = 0;
  int _celebrate = 0;
  bool _solved = false;
  bool _showTool = false;
  String _say = '';
  String _mood = 'asking';
  String? _pending;

  @override
  void initState() {
    super.initState();
    _timer = ref.read(studyTimerProvider.notifier);
    _timer.enter();
    _p = _gen.next();
    _say = 'Mình luyện tập nhé! ${_spoken(_p)}';
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(ttsProvider).say(_say));
  }

  String _spoken(OfflineProblem p) => p.text.replaceAll('= ?', 'bằng mấy?');

  @override
  void dispose() {
    _timer.leave();
    super.dispose();
  }

  Future<void> _owl(String text, String mood) {
    setState(() {
      _say = text;
      _mood = mood;
    });
    return ref.read(ttsProvider).say(text);
  }

  /// Phát lời bố mẹ ghi âm (khen / động viên) sau khi Cú nói xong.
  void _parentVoice(Future<void> spoken, String purpose) {
    final childId = ref.read(activeChildProvider)?.id;
    final voice = ref.read(parentVoiceProvider);
    spoken.then((_) => voice.play(purpose, childId: childId));
  }

  void _newProblem() {
    _p = _gen.next();
    _level = 0;
    _wrong = 0;
    _solved = false;
    _showTool = false;
    _owl(_spoken(_p), 'asking');
  }

  /// Câu gợi ý theo bậc – chỉ dùng số trong đề hoặc ví dụ nhỏ hơn, không bao giờ nói kết quả.
  String _hint(int level) {
    final a = _p.a, b = _p.b;
    switch (level) {
      case 1:
        return 'Đề bài cho mình những số nào? Bạn đọc lại đề cùng Cú nhé.';
      case 2:
        return switch (_p.op) {
          '+' => 'Được thêm vào thì nhiều lên hay ít đi nhỉ?',
          '-' => 'Bớt đi thì còn lại nhiều hơn hay ít hơn $a?',
          '×' => 'Có $a nhóm, mỗi nhóm $b. Mình cộng $b bao nhiêu lần nhỉ?',
          _ => 'Chia đều $a cho $b bạn. Mỗi bạn được mấy? Bạn thử nghĩ phép nhân ngược lại xem.',
        };
      case 3:
        return switch (_p.op) {
          '+' => 'Thử bài nhỏ hơn nhé: 2 thêm 1 là mấy? Bài này cũng làm giống vậy!',
          '-' => 'Thử bài nhỏ hơn nhé: 5 bớt 2 còn mấy? Bài này cũng làm giống vậy!',
          '×' => 'Thử bài nhỏ hơn: 2 nhóm, mỗi nhóm 3 là mấy? Bài này cũng vậy!',
          _ => 'Thử bài nhỏ hơn: 6 chia đều cho 2 bạn thì mỗi bạn mấy? Bài này cũng vậy!',
        };
      case 4:
        return 'Mình dùng que tính nhé! Bạn chạm từng cái để đếm cùng Cú.';
      default:
        return switch (_p.op) {
          '+' => 'Mình đếm thêm từ $a nhé: $a, rồi tiếp theo là số mấy?',
          '-' => 'Mình đếm lùi từ $a nhé: $a, rồi lùi 1 là số mấy?',
          '×' => 'Mình cộng dần nhé: $b, cộng thêm $b nữa là mấy?',
          _ => 'Mỗi bạn được 1 cái thì hết bao nhiêu cái? Còn lại mấy cái nữa?',
        };
    }
  }

  void _answer(String input) {
    if (_solved) return;
    final v = parseChildNumber(input);
    if (v == null) {
      _owl('Cú chưa nghe ra số. Bạn bấm bàn phím số nhé!', 'encouraging');
      return;
    }
    if (_p.check(v)) {
      final stars = _wrong == 0 ? 2 : 3; // tự sửa sai được thêm sao
      setState(() {
        _solved = true;
        _stars += stars;
        _celebrate++;
      });
      ref.read(profilesProvider.notifier).addStars(stars);
      ref.read(soundProvider).tada();
      _parentVoice(_owl('Bạn tự tìm ra rồi! 🎉 Giỏi quá!', 'celebrating'), 'praise');
      return;
    }
    _wrong++;
    if (_wrong >= 6) {
      setState(() => _solved = true);
      _parentVoice(
          _owl('Bạn cố gắng nhiều lắm rồi! Mình để dành câu này hỏi thầy cô nhé. Làm câu khác nha!', 'encouraging'),
          'encourage');
      return;
    }
    if (_wrong % 2 == 0 || _level == 0) _level = _level >= 5 ? 5 : _level + 1;
    if (_level >= 4) setState(() => _showTool = true);
    final spoken = _owl('Bạn tính thế nào ra $v? ${_hint(_level)}', 'encouraging');
    if (_wrong == 3) _parentVoice(spoken, 'encourage');
  }

  void _tooHard() {
    _level = _level < 3 ? 3 : (_level >= 5 ? 5 : _level + 1);
    if (_level >= 4) setState(() => _showTool = true);
    _parentVoice(_owl(_hint(_level), 'encouraging'), 'encourage');
  }

  @override
  Widget build(BuildContext context) {
    final grade = ref.watch(activeChildProvider)?.grade ?? 1;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(children: [
                    OutlinedButton(onPressed: () => context.go('/home'), child: const Text('← Về')),
                    const SizedBox(width: 16),
                    Text('🧩 Luyện tập (không cần mạng)', style: titleStyle(28)),
                    const Spacer(),
                    StarBadge(stars: _stars),
                  ]),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                                child: Row(children: [
                                  Expanded(child: Text(_p.text, style: titleStyle(32))),
                                  SpeakButton(text: _spoken(_p)),
                                ]),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: _showTool
                                    ? ManipulativeView(
                                        spec: ManipulativeSpec(_p.tool, _p.a, _p.b, _p.op),
                                        onClose: () => setState(() => _showTool = false),
                                      )
                                    : Center(child: OwlView(mood: _mood, size: 220)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                                child: Row(children: [
                                  const Text('🦉', style: TextStyle(fontSize: 34)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_say, style: bodyStyle(23, AppColors.ink, FontWeight.w700))),
                                  SpeakButton(text: _say),
                                ]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_solved) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                                  onPressed: _newProblem,
                                  child: const Text('➡️ Câu tiếp'),
                                ),
                              ] else ...[
                                BigNumberPad(grade: grade, onSubmit: _answer),
                                const SizedBox(height: 10),
                                if (_pending != null)
                                  Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    Text('Bạn nói: "$_pending"', style: bodyStyle(20)),
                                    ElevatedButton(
                                      onPressed: () {
                                        final t = _pending!;
                                        setState(() => _pending = null);
                                        _answer(t);
                                      },
                                      child: const Text('✅ Đúng'),
                                    ),
                                  ])
                                else
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                    MicButton(
                                      size: 72,
                                      onFinal: (t) => setState(() => _pending = t.isEmpty ? null : t),
                                    ),
                                    ToolButton(emoji: '😵', label: 'Khó quá', color: AppColors.softThink, onTap: _tooHard),
                                  ]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(child: CelebrationOverlay(tick: _celebrate)),
          ],
        ),
      ),
    );
  }
}
