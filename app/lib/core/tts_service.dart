import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Giọng Cú (TTS tiếng Việt trên máy – miễn phí, mục 12.1).
/// Cần cài "Giọng Tiếng Việt" cho Google Text-to-Speech trên máy tính bảng.
class TtsService {
  final _tts = FlutterTts();
  final speaking = ValueNotifier<bool>(false);
  bool available = false;

  Future<void> init({double rate = 0.45, double pitch = 1.1}) async {
    try {
      final ok = await _tts.isLanguageAvailable('vi-VN');
      available = ok == true || ok == 1;
      await _tts.setLanguage('vi-VN');
      await apply(rate: rate, pitch: pitch);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
    } catch (e) {
      debugPrint('TTS init lỗi: $e');
    }
  }

  /// Tốc độ: thang 0..1 trên Android ⚠️ VERIFY – nghe thử, trẻ nhỏ nên 0.4–0.5.
  Future<void> apply({required double rate, required double pitch}) async {
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
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
