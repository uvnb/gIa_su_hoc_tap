import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';
import 'tutor_controller.dart';
import 'widgets/celebration_overlay.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/manipulatives.dart';
import 'widgets/number_pad.dart';
import 'widgets/scratch_pad.dart';

/// Màn phiên gia sư – màn quan trọng nhất (mục 6.4).
class TutorScreen extends ConsumerStatefulWidget {
  const TutorScreen({super.key, required this.launch});
  final TutorLaunch launch;

  @override
  ConsumerState<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends ConsumerState<TutorScreen> {
  final _scroll = ScrollController();
  final _scratch = ScratchController();
  Timer? _silence;
  bool _silenceHint = false;
  bool _listening = false;
  String _partial = '';
  String? _pending; // chữ nhận dạng chờ bé bấm "Đúng"
  late final StudyTimer _timer;
  late final _tts = ref.read(ttsProvider);

  TutorController get _ctl => ref.read(tutorControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _timer = ref.read(studyTimerProvider.notifier);
    _timer.enter();
    _tts; // khởi tạo sớm để dùng được trong dispose
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctl.launch(widget.launch));
  }

  @override
  void dispose() {
    _timer.leave();
    _silence?.cancel();
    _scroll.dispose();
    _scratch.dispose();
    _tts.stop();
    super.dispose();
  }

  // ------------------------------------------------------------------ im lặng > 20 giây (mục 3.3)
  void _restartSilenceTimer() {
    _silence?.cancel();
    if (_silenceHint) setState(() => _silenceHint = false);
    _silence = Timer(const Duration(seconds: 20), () {
      final s = ref.read(tutorControllerProvider);
      if (!mounted || s.phase != TutorPhase.tutoring || s.busy || _listening) return;
      if (ref.read(ttsProvider).speaking.value) {
        _restartSilenceTimer();
        return;
      }
      setState(() => _silenceHint = true);
      ref.read(ttsProvider).say('Bạn cứ từ từ suy nghĩ nhé! Muốn dùng que tính, hay nghỉ một chút?');
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _maybeBreak() async {
    final s = ref.read(tutorControllerProvider);
    if (s.busy) return;
    await ref.read(ttsProvider).say('Mình nghỉ giải lao một chút cho khỏe nhé!');
    if (!mounted) return;
    await context.push('/break');
    _timer.breakTaken();
    _ctl.breakHandled();
  }

  Future<void> _openScratch() async {
    final s = ref.read(tutorControllerProvider);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ScratchPadScreen(controller: _scratch, problem: s.problem, onSend: _ctl.sendScratch),
    ));
  }

  Future<void> _typeAnswer() async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gõ câu trả lời', style: titleStyle(28)),
        content: SizedBox(
          width: 520,
          child: TextField(controller: c, autofocus: true, style: bodyStyle(26), maxLength: 200),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Thôi')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Gửi')),
        ],
      ),
    );
    if (text != null && text.trim().isNotEmpty) _ctl.childSays(text, mode: 'text');
  }

  Future<bool> _confirmExit() async {
    final s = ref.read(tutorControllerProvider);
    if (s.phase != TutorPhase.tutoring) return true;
    return confirmWithPicture(context, emoji: '🏠', question: 'Mình dừng bài này và về nhà nhé?');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(tutorControllerProvider);
    final child = ref.watch(activeChildProvider);
    final grade = child?.grade ?? 1;

    ref.listen<TutorState>(tutorControllerProvider, (prev, next) {
      if (prev?.bubbles.length != next.bubbles.length) {
        _scrollToEnd();
        _restartSilenceTimer();
      }
      if ((prev?.scratchTick ?? 0) != next.scratchTick) _openScratch();
      if (next.breakSuggested && !(prev?.breakSuggested ?? false)) _maybeBreak();
      if (prev?.currentId != next.currentId) _scratch.clear();
    });
    ref.listen<StudyState>(studyTimerProvider, (prev, next) {
      if (next.breakDue && !(prev?.breakDue ?? false)) _maybeBreak(); // FR-50
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) context.go('/home');
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(s),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 4, child: _leftPanel(s)),
                        Expanded(flex: 6, child: _rightPanel(s, child?.avatar ?? '🧒')),
                      ],
                    ),
                  ),
                  if (s.phase == TutorPhase.tutoring ||
                      s.phase == TutorPhase.solved ||
                      s.phase == TutorPhase.explaining)
                    _toolbar(s, grade),
                ],
              ),
              if (s.numberPad)
                Positioned(
                  right: 16,
                  bottom: 100,
                  child: BigNumberPad(
                    grade: grade,
                    onClose: () => _ctl.setNumberPad(false),
                    onTypeText: grade >= 3 ? _typeAnswer : null,
                    onSubmit: (v) => _ctl.childSays(v, mode: 'keypad'),
                  ),
                ),
              Positioned.fill(child: CelebrationOverlay(tick: s.celebrateTick)),
              if (s.funQuestion.isNotEmpty) _funCard(s),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ các phần giao diện
  Widget _topBar(TutorState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 4),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () async {
              if (await _confirmExit() && mounted) context.go('/home');
            },
            child: const Text('← Về'),
          ),
          const SizedBox(width: 16),
          Text('${subjectName(s.subject)} · Câu ${s.problemNumber}', style: titleStyle(28)),
          const Spacer(),
          if (s.phase == TutorPhase.tutoring) ...[
            Text('Gợi ý: ', style: bodyStyle(20)),
            for (var i = 0; i < 6; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= s.hintLevel ? AppColors.think : Colors.white,
                  border: Border.all(color: AppColors.think, width: 2),
                ),
              ),
            const SizedBox(width: 20),
          ],
          StarBadge(stars: s.starsThisSession),
        ],
      ),
    );
  }

  Widget _leftPanel(TutorState s) {
    final mood = _listening ? 'listening' : (s.busy ? 'thinking' : s.mood);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s.problem.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 190),
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.softSky, width: 3),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(s.problem, style: bodyStyle(24, AppColors.ink, FontWeight.w700)),
                    ),
                  ),
                  Column(
                    children: [
                      SpeakButton(text: s.problem),
                      Text('Đọc đề', style: bodyStyle(14)),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: s.tool != null
                ? Stack(
                    children: [
                      Positioned.fill(child: ManipulativeView(spec: s.tool!, onClose: _ctl.closeTool)),
                      Positioned(right: 6, bottom: 6, child: OwlView(mood: mood, size: 80)),
                    ],
                  )
                : Center(child: OwlView(mood: mood, size: 230)),
          ),
        ],
      ),
    );
  }

  Widget _rightPanel(TutorState s, String avatar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
      child: Container(
        decoration: BoxDecoration(color: AppColors.softSky.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: s.bubbles.length + (s.busy ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == s.bubbles.length) {
                    return const ChatBubble(fromOwl: true, text: 'Cú đang nghĩ… 🤔');
                  }
                  final b = s.bubbles[i];
                  return ChatBubble(fromOwl: b.fromOwl, text: b.text, avatar: avatar);
                },
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: _phasePanel(s)),
          ],
        ),
      ),
    );
  }

  Widget _phasePanel(TutorState s) {
    Widget row(List<Widget> children) =>
        Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.center, children: children);

    if (_listening && _partial.isNotEmpty) {
      return Text('👂 $_partial', style: bodyStyle(22, AppColors.sky, FontWeight.w800));
    }
    if (_pending != null) {
      return Column(
        children: [
          Text('Bạn nói: "$_pending"', style: bodyStyle(24, AppColors.ink, FontWeight.w800)),
          const SizedBox(height: 8),
          row([
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: () {
                final t = _pending!;
                setState(() => _pending = null);
                _ctl.childSays(t);
              },
              child: const Text('✅ Đúng rồi'),
            ),
            OutlinedButton(onPressed: () => setState(() => _pending = null), child: const Text('🎤 Nói lại')),
          ]),
        ],
      );
    }
    if (_silenceHint && s.phase == TutorPhase.tutoring) {
      return row([
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.think),
          onPressed: () {
            setState(() => _silenceHint = false);
            _ctl.tooHard();
          },
          child: const Text('🧮 Dùng que tính'),
        ),
        OutlinedButton(
          onPressed: () async {
            setState(() => _silenceHint = false);
            await context.push('/break');
            _timer.breakTaken();
          },
          child: const Text('☕ Nghỉ chút'),
        ),
      ]);
    }
    switch (s.phase) {
      case TutorPhase.loading:
        return Text('Cú đang đọc bài… 📖', style: titleStyle(26));
      case TutorPhase.picking:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Chạm vào câu bạn muốn làm:', style: titleStyle(24)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in s.problems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Material(
                        color: s.doneIds.contains(p.id) ? AppColors.success.withValues(alpha: 0.2) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: s.busy ? null : () => _ctl.pickProblem(p.id),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text('${s.doneIds.contains(p.id) ? '✅ ' : ''}${p.text}',
                                maxLines: 3, overflow: TextOverflow.ellipsis, style: bodyStyle(22)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      case TutorPhase.confirming:
        return row([
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: s.busy ? null : _ctl.confirmProblem,
            child: const Text('✅ Đúng rồi'),
          ),
          OutlinedButton(onPressed: s.busy ? null : _ctl.rejectProblem, child: const Text('❌ Chưa đúng')),
        ]);
      case TutorPhase.unreadable:
      case TutorPhase.error:
        return row([
          ElevatedButton(
              onPressed: () => context.pushReplacement('/capture', extra: s.subject), child: const Text('📸 Chụp lại')),
          OutlinedButton(
              onPressed: () => context.pushReplacement('/ask', extra: s.subject), child: const Text('🎤 Đọc đề cho Cú')),
          OutlinedButton(onPressed: () => context.go('/home'), child: const Text('🏠 Về nhà')),
        ]);
      case TutorPhase.offline:
        return row([
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => context.pushReplacement('/practice', extra: s.subject),
            child: const Text('🧩 Luyện tập không cần mạng'),
          ),
          OutlinedButton(onPressed: () => context.go('/home'), child: const Text('🏠 Về nhà')),
        ]);
      case TutorPhase.solved:
      case TutorPhase.explaining:
      case TutorPhase.parked:
        return row([
          if (s.phase == TutorPhase.solved)
            Text('👇 Giữ micro để kể Cú nghe vì sao', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
          ElevatedButton(
            onPressed: s.busy
                ? null
                : () async {
                    final more = await _ctl.nextProblem();
                    if (!more && mounted) context.pushReplacement('/capture', extra: s.subject);
                  },
            child: Text(s.hasMoreProblems ? '➡️ Câu tiếp' : '📸 Bài mới'),
          ),
          if (s.phase != TutorPhase.parked)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.think),
              onPressed: s.busy ? null : _ctl.challenge,
              child: const Text('🏆 Thử thách'),
            ),
          OutlinedButton(onPressed: () => context.go('/home'), child: const Text('🏠 Nghỉ')),
        ]);
      case TutorPhase.tutoring:
        if (s.choices.isNotEmpty) {
          return row([
            for (final c in s.choices)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky),
                onPressed: s.busy ? null : () => _ctl.childSays(c, mode: 'choice'),
                child: Text(c),
              ),
          ]);
        }
        return const SizedBox.shrink();
    }
  }

  Widget _toolbar(TutorState s, int grade) {
    final tutoring = s.phase == TutorPhase.tutoring;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      color: AppColors.cream,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          MicButton(
            size: 78,
            enabled: !s.busy,
            onListening: (v) => setState(() {
              _listening = v;
              if (v) {
                _partial = '';
                _pending = null;
                _silence?.cancel();
              }
            }),
            onPartial: (t) => setState(() => _partial = t),
            onFinal: (t) {
              setState(() {
                _partial = '';
                _pending = t.isEmpty ? null : t;
              });
              if (t.isEmpty) ref.read(ttsProvider).say('Cú chưa nghe rõ, bạn nói lại nhé!');
            },
          ),
          ToolButton(
            emoji: '🔢',
            label: 'Bàn phím số',
            active: s.numberPad,
            onTap: () => _ctl.setNumberPad(!s.numberPad),
          ),
          ToolButton(emoji: '✏️', label: 'Nháp', onTap: tutoring ? _openScratch : null),
          ToolButton(
            emoji: '😵',
            label: 'Khó quá',
            color: AppColors.softThink,
            onTap: tutoring && !s.busy ? _ctl.tooHard : null,
          ),
        ],
      ),
    );
  }

  Widget _funCard(TutorState s) => Positioned(
        left: 24,
        bottom: 110,
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sun,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💡 Bạn có biết…', style: titleStyle(24)),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: Text(s.funQuestion, style: bodyStyle(21))),
                  SpeakButton(text: s.funQuestion),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _ctl.dismissFun, child: const Text('Đóng')),
              ),
            ],
          ),
        ),
      );
}
