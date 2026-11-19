import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/mic_button.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/sky_background.dart';

/// 💛 Góc tâm sự – Cú là người bạn lắng nghe (tâm lý học đường).
/// NGUYÊN TẮC: lắng nghe, không phán xét; không bao giờ xúi bé làm việc nguy hiểm; không bảo bé giữ bí mật
/// với bố mẹ; chuyện nguy hiểm → hướng bé tới bố mẹ, thầy cô và Tổng đài bảo vệ trẻ em 111.
/// Cuộc trò chuyện CHỈ nằm trên màn hình này (không lưu); bố mẹ chỉ thấy số lượt và cảnh báo.
class FriendScreen extends ConsumerStatefulWidget {
  const FriendScreen({super.key});

  @override
  ConsumerState<FriendScreen> createState() => _FriendScreenState();
}

class _Msg {
  final bool child;
  final String text;
  const _Msg(this.child, this.text);
}

const _moods = [
  ('vui', '😊', 'Vui'),
  ('buon', '😢', 'Buồn'),
  ('gian', '😠', 'Giận'),
  ('so', '😨', 'Sợ'),
  ('lo', '😟', 'Lo lắng'),
  ('met', '😴', 'Mệt'),
];

const _starters = [
  'Hôm nay con vui vì…',
  'Con bị bạn trêu',
  'Con sợ bài kiểm tra',
  'Con nhớ ông bà',
  'Con giận em quá',
  'Con không có bạn chơi',
];

/// Nhận diện nguy cơ ngay trên máy (khi mất mạng) – trùng ý với bộ lọc trên máy chủ.
String _localCrisis(String text) {
  final t = text.toLowerCase();
  if (RegExp(r'(muốn chết|tự tử|tự sát|không muốn sống|tự làm đau|muốn biến mất)').hasMatch(t)) return 'self_harm';
  if (RegExp(r'(bị đánh|đánh con|bị đánh đập|bị sờ|sờ vào người|bị đe dọa|bị người lạ)').hasMatch(t)) return 'abuse';
  return '';
}

class _FriendScreenState extends ConsumerState<FriendScreen> {
  final _msgs = <_Msg>[];
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String _mood = '';
  String _owlMood = 'listening';
  bool _busy = false;
  String _crisis = '';
  bool _breathing = false;
  bool _offerBreath = false;

  @override
  void initState() {
    super.initState();
    final name = ref.read(activeChildProvider)?.nickname ?? 'bạn';
    _owl('Chào $name! Đây là Góc tâm sự của hai đứa mình. Hôm nay bạn thấy thế nào? Bạn chọn một hình nhé.');
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _owl(String text) {
    setState(() => _msgs.add(_Msg(false, text)));
    _toBottom();
    ref.read(ttsProvider).say(text);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  void _pickMood(String id, String label) {
    ref.read(soundProvider).pop();
    setState(() => _mood = id);
    _send('Hôm nay con thấy $label.');
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _busy) return;
    _text.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
      _owlMood = 'thinking';
    });
    _toBottom();
    final child = ref.read(activeChildProvider);
    final settings = ref.read(settingsProvider);
    final history = [
      for (final m in _msgs.length > 11
          ? _msgs.sublist(_msgs.length - 11, _msgs.length - 1)
          : _msgs.sublist(0, _msgs.length - 1))
        {'who': m.child ? 'child' : 'owl', 'text': m.text},
    ];
    try {
      final deviceId = await ref.read(deviceServiceProvider).ensureRegistered() ?? '';
      final r = await ref.read(apiProvider).friendChat(
            message: text,
            history: history,
            mood: _mood,
            nickname: child?.nickname ?? 'bạn',
            grade: child?.grade ?? 1,
            deviceId: deviceId,
            childId: child?.id ?? '',
            provider: settings.provider,
            tier: settings.tier,
          );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _owlMood = r.owlMood;
        if (r.crisis.isNotEmpty) _crisis = r.crisis;
      });
      _owl(r.say);
      setState(() => _offerBreath = r.suggestBreathing);
    } on ApiOffline {
      _offline(text);
    } on ApiError {
      _offline(text);
    }
  }

  void _offline(String text) {
    if (!mounted) return;
    final crisis = _localCrisis(text);
    setState(() {
      _busy = false;
      _owlMood = 'encouraging';
      if (crisis.isNotEmpty) _crisis = crisis;
    });
    _owl(crisis.isNotEmpty
        ? 'Cú thương bạn lắm. Bạn hãy kể ngay với bố mẹ, thầy cô hoặc người lớn bạn tin tưởng nhé. '
            'Nếu cần, gọi số 111, miễn phí, có cô chú giúp bạn.'
        : 'Mạng đang chập chờn một chút, nhưng Cú vẫn ở đây với bạn. Mình hít thở cùng nhau nhé, '
            'và kể chuyện này với bố mẹ nữa nha.');
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    return Scaffold(
      body: SkyBackground(
        theme: SkyTheme.candy,
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 8, compact ? 12 : 20, 10),
              child: Column(children: [
                Row(children: [
                  PressBounce(
                    child: OutlinedButton(
                      onPressed: () => context.go('/home'),
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: const Text('← Về nhà'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('💛 Góc tâm sự', style: titleStyle(compact ? 28 : 34, const Color(0xFFE0457B))),
                  const Spacer(),
                  PressBounce(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8BC5FF)),
                      onPressed: () => setState(() => _breathing = true),
                      child: const Text('🌬️ Thở cùng Cú'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: compact ? 200 : 250,
                      child: Column(children: [
                        Bobbing(child: OwlView(mood: _owlMood, size: compact ? 110 : 150)),
                        Text('Hôm nay bạn thấy thế nào?',
                            textAlign: TextAlign.center,
                            style: bodyStyle(compact ? 16 : 18, AppColors.ink, FontWeight.w800)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                          for (final (id, emoji, label) in _moods)
                            PressBounce(
                              child: GestureDetector(
                                onTap: () => _pickMood(id, label),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: compact ? 58 : 70,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _mood == id ? AppColors.sun : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _mood == id ? AppColors.orange : Colors.white, width: 3),
                                  ),
                                  child: Column(children: [
                                    Text(emoji, style: TextStyle(fontSize: compact ? 26 : 32)),
                                    Text(label, style: bodyStyle(compact ? 11 : 13, AppColors.ink, FontWeight.w800)),
                                  ]),
                                ),
                              ),
                            ),
                        ]),
                        const Spacer(),
                        Text('Cú luôn lắng nghe bạn 💛\nChuyện quan trọng hãy kể với bố mẹ, thầy cô nhé.',
                            textAlign: TextAlign.center, style: bodyStyle(compact ? 12 : 14, Colors.grey.shade700)),
                      ]),
                    ),
                    SizedBox(width: compact ? 10 : 16),
                    Expanded(child: _chat(compact)),
                  ]),
                ),
              ]),
            ),
            if (_breathing) Positioned.fill(child: _Breathing(onDone: () => setState(() => _breathing = false))),
          ]),
        ),
      ),
    );
  }

  Widget _chat(bool compact) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(26)),
      child: Column(children: [
        if (_crisis.isNotEmpty) _crisisCard(compact),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length + (_busy || _offerBreath ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _msgs.length && _busy) return _bubble(const _Msg(false, 'Cú đang lắng nghe… 💭'), compact);
              if (i == _msgs.length) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: PopIn(
                    child: ActionChip(
                      backgroundColor: const Color(0xFFBDE3FF),
                      label: Text('🌬️ Thở cùng Cú nhé?',
                          style: bodyStyle(compact ? 16 : 18, AppColors.ink, FontWeight.w800)),
                      onPressed: () => setState(() {
                        _offerBreath = false;
                        _breathing = true;
                      }),
                    ),
                  ),
                );
              }
              return PopIn(key: ValueKey(i), child: _bubble(_msgs[i], compact));
            },
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final s in _starters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(s, style: bodyStyle(compact ? 14 : 16)),
                    onPressed: () => s.endsWith('…') ? setState(() => _text.text = s.replaceAll('…', ' ')) : _send(s),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: Row(children: [
            MicButton(
              size: compact ? 58 : 70,
              label: 'Giữ để nói',
              enabled: !_busy,
              onPartial: (t) => setState(() => _text.text = t),
              onFinal: _send,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 2,
                maxLength: 300,
                style: bodyStyle(compact ? 18 : 20),
                decoration: const InputDecoration(hintText: 'Kể cho Cú nghe…', counterText: ''),
                onSubmitted: _send,
              ),
            ),
            const SizedBox(width: 8),
            PressBounce(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0457B)),
                onPressed: _busy ? null : () => _send(_text.text),
                child: const Text('Gửi 💌'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(_Msg m, bool compact) => Align(
        alignment: m.child ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: compact ? 480 : 620),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: m.child ? const Color(0xFFDDEBFF) : const Color(0xFFFFF1D6),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(m.child ? 20 : 4),
              bottomRight: Radius.circular(m.child ? 4 : 20),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (!m.child) const Text('🦉 ', style: TextStyle(fontSize: 22)),
            Flexible(child: Text(m.text, style: bodyStyle(compact ? 18 : 20, AppColors.ink, FontWeight.w600))),
          ]),
        ),
      );

  Widget _crisisCard(bool compact) => Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3C4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.orange, width: 3),
        ),
        child: Row(children: [
          const Text('💛', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bạn không một mình đâu!', style: titleStyle(compact ? 20 : 24, const Color(0xFFD62828))),
              Text('👨‍👩‍👧 Kể ngay với bố mẹ, thầy cô hoặc người lớn bạn tin tưởng.',
                  style: bodyStyle(compact ? 15 : 17, AppColors.ink, FontWeight.w700)),
              Text('📞 Gọi 111 – Tổng đài bảo vệ trẻ em (miễn phí, cả ngày lẫn đêm).',
                  style: bodyStyle(compact ? 15 : 17, AppColors.ink, FontWeight.w800)),
            ]),
          ),
        ]),
      );
}

/// 🌬️ Thở cùng Cú: vòng tròn phồng lên (hít vào 4 nhịp) rồi xẹp xuống (thở ra 4 nhịp), 3 lần.
class _Breathing extends ConsumerStatefulWidget {
  const _Breathing({required this.onDone});
  final VoidCallback onDone;

  @override
  ConsumerState<_Breathing> createState() => _BreathingState();
}

class _BreathingState extends ConsumerState<_Breathing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  int _round = 0;
  bool _inhale = true;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final tts = ref.read(ttsProvider);
    await tts.say('Mình cùng thở thật chậm nhé.');
    for (_round = 1; _round <= 3 && !_stopped; _round++) {
      setState(() => _inhale = true);
      unawaited(tts.say('Hít vào'));
      await _c.forward(from: 0);
      if (_stopped) return;
      setState(() => _inhale = false);
      unawaited(tts.say('Thở ra'));
      await _c.reverse(from: 1);
    }
    if (!_stopped) {
      await tts.say('Giỏi lắm! Bạn thấy dễ chịu hơn chưa?');
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _stopped = true;
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xCC2B3A6B),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final s = 120 + 160 * Curves.easeInOut.transform(_c.value);
            return Container(
              width: s,
              height: s,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFFBDE3FF), Color(0xFF5EB8FF)]),
                boxShadow: [BoxShadow(color: const Color(0xFF5EB8FF).withValues(alpha: 0.6), blurRadius: s / 4)],
              ),
              child: const Text('🦉', style: TextStyle(fontSize: 56)),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(_inhale ? 'Hít vào… 🌬️' : 'Thở ra… 😌', style: titleStyle(40, Colors.white)),
        Text('Lần ${_round.clamp(1, 3)}/3', style: bodyStyle(20, Colors.white)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            _stopped = true;
            ref.read(ttsProvider).stop();
            widget.onDone();
          },
          child: Text('Xong rồi', style: bodyStyle(20, Colors.white, FontWeight.w800)),
        ),
      ]),
    );
  }
}
