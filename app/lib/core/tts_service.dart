import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Giọng Cú (TTS tiếng Việt trên máy – miễn phí, mục 12.1).
/// Cần cài "Giọng Tiếng Việt" cho Google Text-to-Speech trên máy tính bảng.
class TtsService {
  final _tts = FlutterTts();
  final speaking = ValueNotifier<bool>(false);
  bool available = false;

  Future<void> init({double rate = 0.42, double pitch = 1.35, String voice = ''}) async {
    try {
      final ok = await _tts.isLanguageAvailable('vi-VN');
      available = ok == true || ok == 1;
      await _tts.setLanguage('vi-VN');
      await apply(rate: rate, pitch: pitch, voice: voice);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
    } catch (e) {
      debugPrint('TTS init lỗi: $e');
    }
  }

  /// Tốc độ: thang 0..1 trên Android – trẻ nhỏ nên 0.4–0.5. Cao độ > 1 nghe trong trẻo, "dễ thương" hơn.
  Future<void> apply({required double rate, required double pitch, String voice = ''}) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
    await setVoice(voice);
  }

  /// Các giọng tiếng Việt có trên máy (Google TTS thường có vài giọng nữ/nam, bản trên máy và bản cần mạng).
  Future<List<Map<String, String>>> vietnameseVoices() async {
    try {
      final raw = await _tts.getVoices;
      final list = <Map<String, String>>[];
      for (final e in (raw as List? ?? const [])) {
        if (e is! Map) continue;
        final m = e.map((k, v) => MapEntry('$k', '$v'));
        if ((m['locale'] ?? '').toLowerCase().replaceAll('_', '-').startsWith('vi')) list.add(m);
      }
      list.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
      return list;
    } catch (e) {
      debugPrint('Không đọc được danh sách giọng: $e');
      return [];
    }
  }

  /// Đổi giọng theo tên ("" = giọng tiếng Việt mặc định của máy).
  Future<void> setVoice(String name) async {
    try {
      if (name.isEmpty) {
        await _tts.setLanguage('vi-VN');
        return;
      }
      final voices = await vietnameseVoices();
      for (final v in voices) {
        if (v['name'] == name) {
          await _tts.setVoice({'name': v['name']!, 'locale': v['locale'] ?? 'vi-VN'});
          return;
        }
      }
    } catch (e) {
      debugPrint('Không đổi được giọng: $e');
    }
  }

  /// Đọc to. Bỏ emoji để TTS không đọc tên biểu tượng.
  Future<void> say(String text) async {
    final clean = text
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true), '')
        .trim();
    if (clean.isEmpty) return;
    await _tts.stop();
    speaking.value = true;
    try {
      await _tts.speak(clean);
    } finally {
      speaking.value = false;
    }
  }

  Future<void> stop() async {
    await _tts.stop();
    speaking.value = false;
  }
}
