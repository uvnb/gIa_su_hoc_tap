import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Giọng Cú (TTS trên máy – miễn phí, mục 12.1). Cần "Giọng Tiếng Việt" cho Google Text-to-Speech.
///
/// GIỮ GIỌNG ĐÃ CHỌN: mọi câu nói đều chờ áp xong giọng/tốc độ/cao độ đã lưu rồi mới đọc
/// (trước đây câu chào lúc mở app đọc bằng giọng mặc định vì app nói trước khi kịp áp giọng).
/// Giọng được áp lại khi app quay lại tiền cảnh, sau khi đọc tiếng Anh, và định kỳ (phòng khi
/// dịch vụ TTS của Android khởi động lại làm mất giọng).
class TtsService with WidgetsBindingObserver {
  TtsService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _tts = FlutterTts();
  final speaking = ValueNotifier<bool>(false);
  bool available = false;
  bool englishAvailable = false;

  final _ready = Completer<void>();
  double _rate = 0.42;
  double _pitch = 1.35;
  String _voice = '';
  bool _dirty = true; // cần áp lại giọng tiếng Việt trước câu nói tới
  DateTime _appliedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _lock = Future.value(); // tuần tự hóa các lệnh nói / đổi giọng
  List<Map<String, String>>? _voicesCache;

  /// Xong khi đã áp giọng đã lưu lần đầu.
  Future<void> get ready => _ready.future;

  Future<void> init({double rate = 0.42, double pitch = 1.35, String voice = ''}) async {
    _rate = rate;
    _pitch = pitch;
    _voice = voice;
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
  }

  /// Đổi tốc độ / cao độ / giọng (Góc phụ huynh). Lưu lại để áp lại bất cứ lúc nào cần.
  Future<void> apply({required double rate, required double pitch, String voice = ''}) async {
    _rate = rate;
    _pitch = pitch;
    _voice = voice;
    await _run(_applyVietnamese);
  }

  Future<void> _applyVietnamese() async {
    await _tts.setLanguage('vi-VN');
    await _tts.setSpeechRate(_rate);
    await _tts.setPitch(_pitch);
    if (_voice.isNotEmpty) {
      final ok = await setVoice(_voice);
      if (!ok) debugPrint('TTS: chưa tìm thấy giọng $_voice – dùng giọng tiếng Việt mặc định');
    }
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

  /// Các giọng tiếng Việt có trên máy (Google TTS có vài giọng nữ/nam, bản trên máy và bản cần mạng).
  Future<List<Map<String, String>>> vietnameseVoices() => voicesFor('vi');

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

  /// Đặt giọng theo tên. Trả true nếu máy nhận giọng đó.
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
      text.replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '').trim();

  /// Đọc to bằng giọng Cú đã chọn. Bỏ emoji để TTS không đọc tên biểu tượng.
  Future<void> say(String text) async {
    final clean = _clean(text);
    if (clean.isEmpty) return;
    await ready.timeout(const Duration(seconds: 6), onTimeout: () {});
    await _tts.stop();
    await _run(() async {
      await _ensureVietnamese();
      speaking.value = true;
      try {
        await _tts.speak(clean);
      } finally {
        speaking.value = false;
      }
    });
  }

  /// Đọc tiếng Anh (đảo Tiếng Anh) bằng giọng tiếng Anh trên máy, rồi trả lại đúng giọng Cú đã chọn.
  Future<void> sayEnglish(String text, {bool slow = false}) async {
    final clean = _clean(text);
    if (clean.isEmpty) return;
    await ready.timeout(const Duration(seconds: 6), onTimeout: () {});
    await _tts.stop();
    await _run(() async {
      _dirty = true; // sau khi nói tiếng Anh phải áp lại giọng Việt
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
        await _applyVietnamese();
      }
    });
  }

  Future<void> stop() async {
    await _tts.stop();
    speaking.value = false;
  }
}
