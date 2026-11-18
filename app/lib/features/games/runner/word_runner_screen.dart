import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/game_timer.dart';
import '../../../core/local_store.dart';
import '../../../core/music_service.dart';
import '../../../core/permissions.dart';
import '../../../core/providers.dart';
import '../../../core/stt_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/owl_view.dart';
import '../game_session.dart';
import 'word_bank.dart';

/// 🦉 Cú Từ Ngữ: Cú chạy trong rừng, gặp chướng ngại vật thì bé phải ĐỌC TO từ trên màn hình
/// (hoặc điền từ còn thiếu trong thành ngữ, tục ngữ) trước khi Cú chạm vào – đúng thì Cú nhảy qua.
/// Sai/hết giờ thì mất một trái tim ❤️. Hết 3 tim là hết lượt.
class WordRunnerScreen extends ConsumerStatefulWidget {
  const WordRunnerScreen({super.key});

  @override
  ConsumerState<WordRunnerScreen> createState() => _WordRunnerScreenState();
}

class _Obstacle {
  _Obstacle(this.x, this.emoji, this.ch, this.time);
  double x;
  final String emoji;
  final WordChallenge ch;
  final double time; // số giây bé có để trả lời
  int state = 0; // 0 chờ · 1 đúng · 2 trượt
  bool jumped = false;
  bool starTaken = false;
  bool tapHint = false; // đã quá nửa thời gian → hiện thêm nút chạm (máy nghe chưa rõ)
  double bornAt = 0;
}

class _WordRunnerScreenState extends ConsumerState<WordRunnerScreen>
    with SingleTickerProviderStateMixin, GameSession<WordRunnerScreen> {
  static const _obstacleEmojis = ['🪵', '🪨', '🍄', '🌵', '🦔', '🐌', '🌰', '📦'];
  static const _hearts = 3;
  static const _perLevel = 6; // số chướng ngại mỗi cấp

  late final Ticker _ticker = createTicker(_onTick);
  final _frame = ValueNotifier<int>(0);
  final _rnd = math.Random();
  // giữ sẵn các dịch vụ: không được dùng ref trong dispose
  late final SttService _stt = ref.read(sttProvider);
  late final LocalStore _store = ref.read(localStoreProvider);
  late final MusicService _musicSvc = ref.read(musicProvider);

  Size _size = const Size(1280, 700);
  Duration _last = Duration.zero;
  double _t = 0; // giây
  double _dist = 0;
  double _speedMul = 1;
  double _jumpT = -1; // 0..1 khi đang nhảy
  double _hurtT = -1; // 0..1 khi vấp
  final _obs = <_Obstacle>[];
  final _recent = <String>{};
  double _nextSpawnAt = 1.2;

  _Obstacle? _current; // thử thách đang hiện
  final _wrongOpts = <String>{};
  String _heard = '';
  String _feedback = '';
  bool _voice = true; // chế độ nói (true) hay chạm (false)
  bool _listeningWanted = false;
  bool _ducked = false;
  int _restarts = 0;

  int _lives = _hearts;
  int _score = 0;
  int _level = 1;
  int _passed = 0;
  int _best = 0;
  bool _started = false;
  bool _over = false;
  String _banner = '';
  String _childId = '';
  int _grade = 1;

  @override
  String get musicTrack => 'runner';

  double get _ground => _size.height * 0.82;
  double get _owlX => _size.width * 0.16;
  double get _owlW => 120;
  double get _baseSpeed => math.min(480, 230 + 28.0 * (_level - 1));

  @override
  void initState() {
    super.initState();
    final child = ref.read(activeChildProvider);
    _childId = child?.id ?? '';
    _grade = child?.grade ?? 1;
    _best = _childId.isEmpty ? 0 : _store.gameBest(_childId, 'runner');
    _level = _childId.isEmpty ? 1 : math.max(1, _store.gameLevel(_childId, 'runner') - 1); // khởi động nhẹ hơn 1 cấp
    _stt.listening.addListener(_onListeningChanged);
    startGameSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ttsProvider).say('Cú Từ Ngữ! Gặp chướng ngại vật, bạn đọc to từ trên màn hình để Cú nhảy qua nhé!');
    });
  }

  @override
  void onGameStop() {
    _ticker.stop();
    _stopListening();
    _saveBest();
  }

  @override
  void dispose() {
    _stt.listening.removeListener(_onListeningChanged);
    _stopListening();
    _saveBest();
    endGameSession();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _saveBest() {
    if (_childId.isEmpty || _score <= 0) return;
    _store.submitGameBest(_childId, 'runner', _score);
    if (_score > _best) _best = _score;
  }

  // ------------------------------------------------------------------ bắt đầu
  Future<void> _start() async {
    var voice = await ensurePermission(Permission.microphone);
    if (voice) voice = await _stt.init();
    if (!mounted) return;
    setState(() {
      _voice = voice;
      _started = true;
      _over = false;
      _lives = _hearts;
      _score = 0;
      _passed = 0;
      _obs.clear();
      _current = null;
      _dist = 0;
      _t = 0;
      _nextSpawnAt = 1.0;
      _feedback = '';
    });
    if (!voice) {
      ref.read(ttsProvider).say('Máy chưa nghe được giọng nói. Mình chơi bằng cách chạm đúng từ nhé!');
    }
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  // ------------------------------------------------------------------ vòng lặp
  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.016 : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    if (!_started || _over) return;
    _t += dt;

    // tăng tốc khi bé trả lời đúng sớm → Cú "lao" tới chướng ngại để nhảy qua
    final cur = _current;
    final target = cur != null && cur.state == 1 && !cur.jumped ? 2.4 : 1.0;
    _speedMul += (target - _speedMul) * math.min(1, dt * 6);
    final speed = _baseSpeed * _speedMul;
    _dist += speed * dt;

    for (final o in _obs) {
      o.x -= speed * dt;
    }

    // sinh chướng ngại mới khi không còn thử thách đang chờ
    final pending = _obs.any((o) => o.state == 0);
    if (!pending && _current == null && _t >= _nextSpawnAt) _spawn();

    if (cur != null && cur.state == 0 && !cur.tapHint && _t - cur.bornAt > cur.time * 0.5) {
      cur.tapHint = true;
      setState(() {});
    }

    final front = _owlX + _owlW * 0.55;
    for (final o in _obs) {
      // nhảy đúng lúc khi đã trả lời đúng
      if (o.state == 1 && !o.jumped && o.x - front < speed * 0.32) {
        o.jumped = true;
        _jumpT = 0;
        ref.read(soundProvider).jump();
      }
      if (o.state == 0 && o.x <= front) _miss(o);
      // nhặt sao khi nhảy qua
      if (o.state == 1 && o.jumped && !o.starTaken && (o.x - _owlX).abs() < 60) {
        o.starTaken = true;
        _score += 3;
        ref.read(soundProvider).coin();
        _addPoints(3);
      }
    }
    // chướng ngại đã qua khỏi Cú → tính là đã vượt
    for (final o in _obs.where((o) => o.state != 0 && o.x < _owlX - 80 && identical(o, _current)).toList()) {
      _passedOne(o);
    }
    _obs.removeWhere((o) => o.x < -140);

    if (_jumpT >= 0) {
      _jumpT += dt / 0.75;
      if (_jumpT >= 1) _jumpT = -1;
    }
    if (_hurtT >= 0) {
      _hurtT += dt / 0.8;
      if (_hurtT >= 1) _hurtT = -1;
    }
    _frame.value++;
  }

  void _spawn() {
    final ch = nextChallenge(grade: _grade, level: _level, rnd: _rnd, recent: _recent);
    _recent.add(ch.prompt);
    if (_recent.length > 12) _recent.remove(_recent.first);
    var time = math.max(4.5, 9.0 - 0.7 * (_level - 1));
    if (!ch.isRead) time += 2.5; // câu dài cần thời gian đọc
    if (ch.prompt.split(' ').length >= 4 && ch.isRead) time += 1.5;
    final front = _owlX + _owlW * 0.55;
    final o = _Obstacle(front + _baseSpeed * time, _obstacleEmojis[_rnd.nextInt(_obstacleEmojis.length)], ch, time)
      ..bornAt = _t;
    _obs.add(o);
    setState(() {
      _current = o;
      _wrongOpts.clear();
      _heard = '';
      _feedback = '';
      _restarts = 0;
    });
    if (!ch.isRead) {
      // Cú đọc câu (chỗ trống đọc là "gì") rồi mới mở micro – không để micro nghe nhầm giọng Cú.
      ref.read(ttsProvider).say(ch.spokenPrompt).then((_) => _listenFor(o));
    } else if (!_voice) {
      ref.read(ttsProvider).say('Chạm vào chữ: ${ch.prompt}');
    } else {
      _listenFor(o);
    }
  }

  // ------------------------------------------------------------------ giọng nói
  void _listenFor(_Obstacle o) {
    if (!_voice || !mounted || _over || o.state != 0 || !identical(o, _current)) return;
    _listeningWanted = true;
    if (!_ducked) {
      _ducked = true;
      _musicSvc.duck(true);
    }
    _stt.listen((text, isFinal) {
      if (!mounted || !identical(o, _current) || o.state != 0) return;
      setState(() => _heard = text);
      final m = matchSpeech(text, o.ch.answer);
      if (m != SpeechMatch.none) _correct(o, close: m == SpeechMatch.close);
    });
  }

  /// Micro tự tắt khi bé im lặng một lúc → mở lại nếu thử thách vẫn đang chờ.
  void _onListeningChanged() {
    if (_stt.listening.value || !_listeningWanted) return;
    final o = _current;
    if (o == null || o.state != 0 || _over || !mounted) return;
    if (_restarts++ > 10) return;
    Future.delayed(const Duration(milliseconds: 350), () => _listenFor(o));
  }

  void _stopListening() {
    _listeningWanted = false;
    if (_stt.listening.value) _stt.cancel();
    if (_ducked) {
      _ducked = false;
      _musicSvc.duck(false);
    }
  }

  // ------------------------------------------------------------------ kết quả
  void _tapOption(String o) {
    final cur = _current;
    if (cur == null || cur.state != 0 || _wrongOpts.contains(o)) return;
    if (o == cur.ch.answer) {
      _correct(cur);
    } else {
      setState(() => _wrongOpts.add(o));
      ref.read(soundProvider).oops();
    }
  }

  void _correct(_Obstacle o, {bool close = false}) {
    if (o.state != 0) return;
    o.state = 1;
    _stopListening();
    final quick = (_t - o.bornAt) < o.time / 2;
    final pts = 10 + (quick ? 5 : 0) + (_wrongOpts.isEmpty ? 0 : -3);
    _score += pts;
    _addPoints(pts);
    ref.read(soundProvider).ting();
    setState(() => _feedback = close ? 'Gần đúng! Cú cho qua 😉' : (quick ? 'Nhanh quá! +$pts' : 'Đúng rồi! +$pts'));
  }

  void _miss(_Obstacle o) {
    o.state = 2;
    o.jumped = true; // Cú leo qua sau khi vấp
    _stopListening();
    _hurtT = 0;
    _lives--;
    ref.read(soundProvider).bump();
    final ans = o.ch.isRead ? o.ch.prompt : o.ch.full;
    setState(() => _feedback = o.ch.isRead ? 'Từ này đọc là: $ans' : ans);
    ref.read(ttsProvider).say(o.ch.isRead ? 'Ối! Từ này đọc là: $ans' : 'Ối! Câu đúng là: $ans');
    if (_lives <= 0) _gameOver();
  }

  void _passedOne(_Obstacle o) {
    if (!identical(o, _current)) return;
    _passed++;
    _current = null;
    _nextSpawnAt = _t + (o.state == 2 ? 2.2 : 0.9);
    if (_passed % _perLevel == 0) {
      _level++;
      if (_childId.isNotEmpty) _store.setGameLevel(_childId, 'runner', _level);
      ref.read(soundProvider).tada();
      _showBanner('Cấp $_level! Cú chạy nhanh hơn! 🚀');
      ref.read(ttsProvider).say('Lên cấp $_level! Cú chạy nhanh hơn rồi!');
    }
    setState(() {});
  }

  void _showBanner(String text) {
    setState(() => _banner = text);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _banner == text) setState(() => _banner = '');
    });
  }

  Future<void> _addPoints(int pts) async {
    final goal = await ref.read(gamePointsProvider.notifier).add(pts);
    if (goal && mounted) {
      _showBanner('🎁 Đạt mục tiêu hôm nay!');
      parentVoiceOrSay(ref, 'praise', 'Bạn đạt mục tiêu hôm nay rồi! Chơi xong nhớ viết điều ước gửi bố mẹ nhé!');
    }
  }

  void _gameOver() {
    _saveBest();
    _stopListening();
    setState(() {
      _over = true;
      _current = null;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) parentVoiceOrSay(ref, 'encourage', 'Cú mệt rồi! Bạn giỏi lắm, mình chơi lại nhé!');
    });
  }

  void _toggleMode() {
    final voice = !_voice;
    if (voice && !_stt.ready) {
      ref.read(ttsProvider).say('Máy chưa nghe được giọng nói.');
      return;
    }
    setState(() => _voice = voice);
    final cur = _current;
    if (!voice) {
      _stopListening();
      if (cur != null && cur.state == 0 && cur.ch.isRead) ref.read(ttsProvider).say('Chạm vào chữ: ${cur.ch.prompt}');
    } else if (cur != null && cur.state == 0) {
      _listenFor(cur);
    }
  }

  // ------------------------------------------------------------------ giao diện
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFFCDEBFF),
              child: GameTopBar(
                title: '🦉 Cú Từ Ngữ',
                onBack: leaveGame,
                extra: [
                  Text(List.generate(_hearts, (i) => i < _lives ? '❤️' : '🤍').join(),
                      style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  if (_started)
                    OutlinedButton(
                      onPressed: _toggleMode,
                      style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                      child: Text(_voice ? '🎤 Nói' : '👆 Chạm'),
                    ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                _size = Size(box.maxWidth, box.maxHeight);
                return Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(painter: _RunnerPainter(this, repaint: _frame)),
                      ),
                    ),
                    Positioned(left: 16, bottom: 12, child: _hud()),
                    if (_current != null && _started && !_over)
                      Positioned(top: 10, left: 0, right: 0, child: Center(child: _challengeCard(_current!))),
                    if (_banner.isNotEmpty)
                      Positioned(
                        top: _current == null ? 30 : 250,
                        left: 0,
                        right: 0,
                        child: Center(child: _bannerView(_banner)),
                      ),
                    if (!_started) Positioned.fill(child: _startCard()),
                    if (_over) Positioned.fill(child: _gameOverCard()),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hud() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(24)),
        child: Text('Cấp $_level · 🏃 ${(_dist / 50).round()} m · ⭐ $_score điểm',
            style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
      );

  Widget _bannerView(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.sun,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
        ),
        child: Text(text, style: titleStyle(34)),
      );

  Widget _challengeCard(_Obstacle o) {
    final ch = o.ch;
    final done = o.state != 0;
    final showOptions = !ch.isRead || !_voice || o.tapHint;
    final label = ch.isRead
        ? (_voice ? '🗣️ Đọc to từ này!' : '👂 Nghe Cú đọc, chạm đúng chữ!')
        : '🧩 Điền từ còn thiếu';
    final border = o.state == 1 ? AppColors.success : (o.state == 2 ? AppColors.think : AppColors.sky);
    return Container(
      width: math.min(820, _size.width - 40),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border, width: 5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text(label, style: bodyStyle(22, AppColors.ink, FontWeight.w800)),
            const Spacer(),
            if (!ch.isRead || !_voice)
              IconButton(
                onPressed: () => ref.read(ttsProvider).say(ch.isRead ? ch.prompt : ch.spokenPrompt),
                icon: const Text('🔊', style: TextStyle(fontSize: 28)),
              ),
          ]),
          if (!done)
            // chỉ thanh thời gian vẽ lại mỗi khung hình
            ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (_, __, ___) {
                final remain = (1 - (_t - o.bornAt) / o.time).clamp(0.0, 1.0).toDouble();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: remain,
                    minHeight: 12,
                    backgroundColor: const Color(0xFFF1EBFF),
                    color: remain > 0.5 ? AppColors.success : (remain > 0.25 ? AppColors.sun : AppColors.orange),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          if (ch.isRead && (_voice || done))
            Text(ch.prompt, textAlign: TextAlign.center, style: titleStyle(ch.prompt.length > 14 ? 46 : 66, AppColors.ink))
          else if (!ch.isRead)
            _proverbText(ch, done),
          if (showOptions && !done) ...[
            if (ch.isRead && _voice)
              Text('Cú chưa nghe rõ? Chạm vào chữ đúng nhé!', style: bodyStyle(18, Colors.grey.shade700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [for (final opt in ch.options) _optionButton(opt)],
            ),
          ],
          if (_voice && !done)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ValueListenableBuilder<bool>(
                valueListenable: _stt.listening,
                builder: (_, on, __) => Text(
                  on ? '👂 Cú đang nghe…${_heard.isEmpty ? '' : '  “$_heard”'}' : '🎤 Chuẩn bị nghe…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(19, const Color(0xFF7A5CFF), FontWeight.w700),
                ),
              ),
            ),
          if (_feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_feedback,
                  textAlign: TextAlign.center,
                  style: titleStyle(28, o.state == 1 ? AppColors.success : const Color(0xFF7A5CFF))),
            ),
        ],
      ),
    );
  }

  Widget _proverbText(WordChallenge ch, bool done) {
    final parts = ch.prompt.split('___');
    final style = titleStyle(ch.prompt.length > 40 ? 30 : 38);
    return Text.rich(
      TextSpan(style: style, children: [
        TextSpan(text: parts.first),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: done ? const Color(0xFFDDF7E8) : AppColors.sun,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(done ? ch.answer : ' ? ', style: style),
          ),
        ),
        if (parts.length > 1) TextSpan(text: parts[1]),
      ]),
      textAlign: TextAlign.center,
    );
  }

  Widget _optionButton(String opt) {
    final wrong = _wrongOpts.contains(opt);
    return Material(
      color: wrong ? Colors.grey.shade300 : AppColors.sky,
      borderRadius: BorderRadius.circular(24),
      elevation: wrong ? 0 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: wrong ? null : () => _tapOption(opt),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 150, minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: Center(
              widthFactor: 1,
              child: Text(wrong ? '🤔' : opt, style: titleStyle(34, Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _startCard() => Container(
        color: Colors.black.withValues(alpha: 0.25),
        alignment: Alignment.center,
        child: Container(
          width: 680,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.sky, width: 6),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const OwlView(mood: 'celebrating', size: 130),
            Text('Cú Từ Ngữ', style: titleStyle(40)),
            const SizedBox(height: 8),
            for (final line in const [
              '🏃 Cú chạy qua khu rừng.',
              '🗣️ Gặp chướng ngại vật: ĐỌC TO từ trên màn hình.',
              '🧩 Có câu thành ngữ thiếu từ: nói hoặc chạm từ đúng.',
              '🦘 Đúng thì Cú nhảy qua và nhặt ⭐. Trượt thì mất ❤️.',
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(line, style: bodyStyle(21)),
              ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _start,
              style: ElevatedButton.styleFrom(minimumSize: const Size(260, 84), backgroundColor: AppColors.success),
              child: Text('▶️ Bắt đầu', style: titleStyle(32, Colors.white)),
            ),
          ]),
        ),
      );

  Widget _gameOverCard() => Container(
        color: Colors.black.withValues(alpha: 0.35),
        alignment: Alignment.center,
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.sun, width: 6),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const OwlView(mood: 'sleepy', size: 130),
            Text('Cú mệt rồi! 😴', style: titleStyle(38)),
            const SizedBox(height: 8),
            Text('Chạy được ${(_dist / 50).round()} m · ⭐ $_score điểm',
                style: bodyStyle(24, AppColors.ink, FontWeight.w800)),
            Text('Kỷ lục: ${math.max(_best, _score)} điểm · Cấp $_level', style: bodyStyle(20)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: _start, child: const Text('🔄 Chạy lại')),
              const SizedBox(width: 14),
              OutlinedButton(onPressed: leaveGame, child: const Text('🏠 Góc trò chơi')),
            ]),
          ]),
        ),
      );
}

// ============================================================================ vẽ cảnh
class _RunnerPainter extends CustomPainter {
  _RunnerPainter(this.g, {required Listenable repaint}) : super(repaint: repaint);
  final _WordRunnerScreenState g;

  static final _emojiCache = <String, TextPainter>{};

  static TextPainter _emoji(String e, double size) {
    final key = '$e@$size';
    return _emojiCache.putIfAbsent(
      key,
      () => TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)
        ..layout(),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = g._ground;
    final d = g._dist;

    // bầu trời
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDEBFF), Color(0xFFFFF4E0)],
        ).createShader(Offset.zero & size),
    );
    // mặt trời cười
    final sun = Offset(w - 120, 90);
    canvas.drawCircle(sun, 62, Paint()..color = const Color(0x55FFD23F));
    canvas.drawCircle(sun, 46, Paint()..color = AppColors.sun);
    final face = Paint()..color = const Color(0xFF8A5A00);
    canvas.drawCircle(sun + const Offset(-14, -6), 4.5, face);
    canvas.drawCircle(sun + const Offset(14, -6), 4.5, face);
    canvas.drawArc(Rect.fromCenter(center: sun + const Offset(0, 6), width: 26, height: 18), 0.2, 2.7, false,
        Paint()
          ..color = const Color(0xFF8A5A00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round);

    // mây trôi chậm
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < 4; i++) {
      final span = w + 260;
      final x = ((i * 380 + 140 - d * 0.08) % span + span) % span - 160;
      final y = 60.0 + (i % 2) * 70 + i * 12;
      canvas.drawCircle(Offset(x, y), 30, cloud);
      canvas.drawCircle(Offset(x + 34, y - 12), 36, cloud);
      canvas.drawCircle(Offset(x + 70, y), 28, cloud);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - 10, y, 100, 26), const Radius.circular(13)), cloud);
    }

    // đồi xa
    _hills(canvas, size, ground - 70, 90, 520, d * 0.22, const Color(0xFFC7EBC0));
    _hills(canvas, size, ground - 25, 60, 330, d * 0.45, const Color(0xFFA9DE9C));

    // cây gần
    final tree = _emoji('🌳', 74);
    for (var i = 0; i < 6; i++) {
      final span = w + 300;
      final x = ((i * 290 + 60 - d * 0.7) % span + span) % span - 150;
      tree.paint(canvas, Offset(x, ground - tree.height + 8));
    }

    // mặt đất
    canvas.drawRect(Rect.fromLTWH(0, ground, w, h - ground), Paint()..color = const Color(0xFFE9C891));
    canvas.drawRect(Rect.fromLTWH(0, ground - 4, w, 18), Paint()..color = const Color(0xFF7CC46A));
    final dash = Paint()..color = const Color(0xFFD6B176);
    for (var i = 0; i < 14; i++) {
      final span = w + 120;
      final x = ((i * 110 - d) % span + span) % span - 60;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, ground + 30 + (i % 3) * 14, 36, 8), const Radius.circular(4)), dash);
    }

    // chướng ngại + sao
    for (final o in g._obs) {
      final tp = _emoji(o.emoji, 70);
      tp.paint(canvas, Offset(o.x - tp.width / 2, ground - tp.height + 10));
      if (!o.starTaken && o.state != 2) {
        final star = _emoji('⭐', 40);
        final bob = math.sin(g._t * 5 + o.x * 0.01) * 6;
        star.paint(canvas, Offset(o.x - star.width / 2, ground - 210 + bob));
      }
      if (o.state == 1 && !o.jumped) {
        final ok = _emoji('✅', 34);
        ok.paint(canvas, Offset(o.x - ok.width / 2, ground - tp.height - 30));
      }
    }

    // Cú chạy / nhảy / vấp
    var y = ground - 128.0;
    var mood = 'idle';
    final cur = g._current;
    if (cur != null && cur.state == 0) mood = g._voice ? 'listening' : 'thinking';
    if (cur != null && cur.state == 1) mood = 'celebrating';
    if (g._jumpT >= 0) {
      y -= 165 * math.sin(math.pi * g._jumpT);
    } else if (g._started && !g._over) {
      y -= (math.sin(g._t * 16)).abs() * 7; // nhún nhảy khi chạy
    }
    double tilt = 0;
    if (g._hurtT >= 0) {
      mood = 'encouraging';
      tilt = math.sin(g._hurtT * math.pi * 4) * 0.15;
      if (g._hurtT < 0.35) {
        final boom = _emoji('💥', 54);
        boom.paint(canvas, Offset(g._owlX + 80, ground - 120));
      }
    }
    if (g._over) mood = 'sleepy';
    // bóng
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(g._owlX + 60, ground + 4),
          width: 90 - (ground - 128 - y) * 0.2,
          height: 14),
      Paint()..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.save();
    canvas.translate(g._owlX + 60, y + 66);
    canvas.rotate(tilt);
    canvas.translate(-60, -66);
    OwlPainter(mood: mood, t: (g._t * 0.6) % 1, stage: 3, waving: false).paint(canvas, const Size(120, 132));
    canvas.restore();
  }

  void _hills(Canvas canvas, Size size, double base, double amp, double period, double offset, Color color) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 10; x += 10) {
      final yy = base - amp * (0.5 + 0.5 * math.sin((x + offset) / period * 2 * math.pi));
      path.lineTo(x, yy);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RunnerPainter old) => true;
}
