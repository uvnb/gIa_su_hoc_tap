import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'neural_tts.dart';

/// Giọng Cú.
///
/// TIẾNG VIỆT: giọng người thật tổng hợp bằng mô hình mã nguồn mở Piper chạy ngay trên máy
/// ([NeuralTts]) – tự nhiên hơn hẳn giọng máy của Android, không cần mạng, không cần cài thêm gì.
/// Chỉ khi mô hình không chạy được trên máy (rất hiếm) mới dùng tạm giọng tiếng Việt của Android.
///
/// TIẾNG ANH (đảo Tiếng Anh): giọng tiếng Anh trên máy của Android.
///
/// Kiểu giọng (tốc độ / cao độ) bố mẹ chọn được lưu và áp cho mọi câu, kể cả sau khi tắt mở lại app.
class TtsService with WidgetsBindingObserver {
  TtsService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _tts = FlutterTts();
  final _neural = NeuralTts();
  AudioPlayer? _player;
  final speaking = ValueNotifier<bool>(false);
  bool available = false;
  bool englishAvailable = false;

  /// true khi giọng tự nhiên đã sẵn sàng (Cú đang dùng giọng người thật).
  final natural = ValueNotifier<bool>(false);

  final _ready = Completer<void>();
  double _rate = 0.42;
  double _pitch = 1.35;
  String _voice = '';
  bool _dirty = true; // cần áp lại giọng tiếng Việt dự phòng trước câu nói tới
  DateTime _appliedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _lock = Future.value(); // tuần tự hóa các lệnh nói / đổi giọng
  List<Map<String, String>>? _voicesCache;
  int _gen = 0; // tăng mỗi lần nói mới / dừng → câu cũ tự bỏ
  Completer<void>? _playing;
  late final Future<bool> _neuralStart;

  /// Máy chủ đọc giúp từng câu (cùng giọng, nhanh hơn tablet rất nhiều). Gắn trong main.dart.
  set cloud(Future<Uint8List?> Function(String text, double speed, double pitch)? f) => _neural.cloud = f;

  /// Xong khi đã áp giọng đã lưu lần đầu.
  Future<void> get ready => _ready.future;

  Future<void> init({double rate = 0.42, double pitch = 1.35, String voice = ''}) async {
    _rate = rate;
    _pitch = pitch;
    _voice = voice;
    _neuralStart = _neural.start().then((ok) {
      natural.value = ok;
      debugPrint(ok ? 'Cú: dùng giọng tự nhiên (Piper)' : 'Cú: giọng tự nhiên không chạy được – dùng giọng dự phòng');
      return ok;
    });
    if (!kIsWeb) {
      final p = AudioPlayer();
      _player = p;
      p.onPlayerComplete.listen((_) => _donePlaying());
      unawaited(p
          .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build())
          .catchError((Object e) => debugPrint('Giọng Cú – âm thanh: $e')));
    }
    try {
      final ok = await _tts.isLanguageAvailable('vi-VN');
      available = ok == true || ok == 1;
      final en = await _tts.isLanguageAvailable('en-US');
      englishAvailable = en == true || en == 1;
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
      await _applyVietnamese();
    } catch (e) {
      debugPrint('TTS init lỗi: $e');
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _dirty = true;
    if (state == AppLifecycleState.paused) unawaited(stop());
  }

  /// Đổi tốc độ / cao độ (Góc phụ huynh). Lưu lại để áp cho mọi câu sau.
  Future<void> apply({required double rate, required double pitch, String voice = ''}) async {
    _rate = rate;
    _pitch = pitch;
    _voice = voice;
    await _run(_applyVietnamese);
  }

  /// Tốc độ cho giọng tự nhiên (thang của Android: 0.5 ≈ bình thường).
  double get _neuralSpeed => (_rate / 0.46).clamp(0.7, 1.4);

  /// Cao độ cho giọng tự nhiên – nâng nhẹ hơn giọng máy để không bị "the thé".
  double get _neuralPitch => (1 + (_pitch - 1) * 0.3).clamp(0.9, 1.2);

  Future<void> _applyVietnamese() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    if (_voice.isNotEmpty) await setVoice(_voice);
    _dirty = false;
    _appliedAt = DateTime.now();
  }

  /// Chạy tuần tự để lệnh đổi giọng không chen giữa câu đang nói.
  Future<T> _run<T>(Future<T> Function() f) {
    final c = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await f());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  Future<void> _ensureVietnamese() async {
    if (_dirty || DateTime.now().difference(_appliedAt) > const Duration(minutes: 3)) {
      await _applyVietnamese();
    }
  }

  Future<List<Map<String, String>>> voicesFor(String lang) async {
    try {
      _voicesCache ??= await _loadVoices();
      return _voicesCache!
          .where((m) => (m['locale'] ?? '').toLowerCase().replaceAll('_', '-').startsWith(lang))
          .toList();
    } catch (e) {
      debugPrint('Không đọc được danh sách giọng: $e');
      return [];
    }
  }

  Future<List<Map<String, String>>> _loadVoices() async {
    final raw = await _tts.getVoices;
    final list = <Map<String, String>>[];
    for (final e in (raw as List? ?? const [])) {
      if (e is! Map) continue;
      list.add(e.map((k, v) => MapEntry('$k', '$v')));
    }
    list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return list;
  }

  /// Đặt giọng Android theo tên (chỉ dùng cho giọng dự phòng). Trả true nếu máy nhận giọng đó.
  Future<bool> setVoice(String name) async {
    try {
      if (name.isEmpty) {
        await _tts.setLanguage('vi-VN');
        return true;
      }
      final voices = await voicesFor('');
      for (final v in voices) {
        if (v['name'] == name) {
          final r = await _tts.setVoice({'name': v['name']!, 'locale': v['locale'] ?? 'vi-VN'});
          return r == 1 || r == true;
        }
      }
    } catch (e) {
      debugPrint('Không đổi được giọng: $e');
    }
    return false;
  }

  static String _clean(String text) =>
      text.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]', unicode: true), '').trim();

  /// Đọc to bằng giọng Cú. Bỏ emoji để không đọc tên biểu tượng. Câu mới luôn ngắt câu đang nói.
  Future<void> say(String text) async {
    final clean = _clean(text);
    if (clean.isEmpty) return;
    final gen = ++_gen;
    await _stopOutput();
    await ready.timeout(const Duration(seconds: 6), onTimeout: () {});
    await _run(() async {
      if (gen != _gen) return;
      // Lần đầu mở app: chờ giọng tự nhiên nạp xong (vài giây) thay vì nói bằng giọng máy.
      final ok = await _neuralStart.timeout(const Duration(seconds: 25), onTimeout: () => false);
      if (gen != _gen) return;
      if (ok && await _sayNatural(clean, gen)) return;
      if (gen != _gen) return;
      await _ensureVietnamese();
      speaking.value = true;
      try {
        await _tts.speak(clean);
      } finally {
        speaking.value = false;
      }
    });
  }

  /// Đọc từng câu: phát câu này trong lúc tạo sẵn câu sau. Trả false nếu câu đầu không tạo được
  /// (để dùng giọng dự phòng).
  Future<bool> _sayNatural(String text, int gen) async {
    final player = _player;
    if (player == null) return false;
    final parts = splitSentences(normalizeVietnamese(text));
    if (parts.isEmpty) return true;
    final speed = _neuralSpeed;
    final pitch = _neuralPitch;
    speaking.value = true;
    try {
      Future<String?>? next = _neural.synthFile(parts.first, speed: speed, pitch: pitch);
      for (var i = 0; i < parts.length; i++) {
        final path = await next;
        if (gen != _gen) return true;
        if (path == null) return i > 0;
        next = i + 1 < parts.length ? _neural.synthFile(parts[i + 1], speed: speed, pitch: pitch) : null;
        await _playFile(player, path, gen);
        if (gen != _gen) return true;
      }
      return true;
    } catch (e) {
      debugPrint('Giọng tự nhiên lỗi khi đọc: $e');
      return false;
    } finally {
      if (gen == _gen) speaking.value = false;
    }
  }

  Future<void> _playFile(AudioPlayer player, String path, int gen) async {
    final done = Completer<void>();
    _playing = done;
    // thời lượng = (kích thước - 44 byte đầu) / 2 byte / 22050 mẫu mỗi giây
    final ms = ((File(path).lengthSync() - 44) / 2 / 22.05).round();
    await player.play(DeviceFileSource(path), volume: 1.0);
    await done.future.timeout(Duration(milliseconds: ms + 2500), onTimeout: () {});
    if (identical(_playing, done)) _playing = null;
  }

  void _donePlaying() {
    final p = _playing;
    if (p != null && !p.isCompleted) p.complete();
  }

  Future<void> _stopOutput() async {
    try {
      await _player?.stop();
    } catch (_) {}
    _donePlaying();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Đọc tiếng Anh (đảo Tiếng Anh) bằng giọng tiếng Anh trên máy.
  Future<void> sayEnglish(String text, {bool slow = false}) async {
    final clean = _clean(text);
    if (clean.isEmpty) return;
    final gen = ++_gen;
    await _stopOutput();
    await ready.timeout(const Duration(seconds: 6), onTimeout: () {});
    await _run(() async {
      if (gen != _gen) return;
      _dirty = true; // sau khi nói tiếng Anh phải áp lại giọng Việt dự phòng
      try {
        await _tts.setLanguage('en-US');
        // ưu tiên giọng tiếng Anh "trên máy" (không cần mạng, luôn giống nhau)
        final en = await voicesFor('en-us');
        final local = en.where((v) => (v['name'] ?? '').contains('local')).toList();
        if (local.isNotEmpty) {
          await _tts.setVoice({'name': local.first['name']!, 'locale': local.first['locale'] ?? 'en-US'});
        }
        await _tts.setSpeechRate(slow ? 0.3 : 0.4);
        await _tts.setPitch(1.1);
        speaking.value = true;
        await _tts.speak(clean);
      } catch (e) {
        debugPrint('TTS tiếng Anh lỗi: $e');
      } finally {
        speaking.value = false;
      }
    });
  }

  Future<void> stop() async {
    _gen++;
    await _stopOutput();
    speaking.value = false;
  }
}
