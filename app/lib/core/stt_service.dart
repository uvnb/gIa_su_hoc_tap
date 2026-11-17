import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nhận dạng giọng nói tiếng Việt trên máy (mục 12.1). Không giữ micro mở liên tục (tiết kiệm pin).
class SttService {
  final _stt = SpeechToText();
  bool _ready = false;
  // Android dùng dạng vi_VN; trình duyệt (bản web chạy thử) cần dạng BCP-47 vi-VN.
  String _localeId = kIsWeb ? 'vi-VN' : 'vi_VN';
  final level = ValueNotifier<double>(0); // âm lượng – vẽ sóng âm
  final listening = ValueNotifier<bool>(false);
  String? lastError;

  bool get ready => _ready;

  Future<bool> init() async {
    if (_ready) return true;
    try {
      _ready = await _stt.initialize(
        onError: (SpeechRecognitionError e) {
          lastError = e.errorMsg;
          listening.value = false;
        },
        onStatus: (s) => listening.value = s == 'listening',
      );
      if (_ready) {
        final locales = await _stt.locales();
        final vi = locales.where((l) => l.localeId.toLowerCase().startsWith('vi'));
        if (vi.isNotEmpty && !kIsWeb) _localeId = vi.first.localeId;
      }
    } catch (e) {
      debugPrint('STT init lỗi: $e');
      _ready = false;
    }
    return _ready;
  }

  /// Bắt đầu nghe. onResult(text, isFinal) được gọi liên tục khi có chữ mới.
  Future<void> listen(void Function(String text, bool isFinal) onResult) async {
    if (!await init()) return;
    lastError = null;
    await _stt.listen(
      localeId: _localeId,
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 4),
      onSoundLevelChange: (l) => level.value = l,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
    );
    listening.value = true;
  }

  Future<void> stop() async {
    await _stt.stop();
    listening.value = false;
    level.value = 0;
  }

  Future<void> cancel() async {
    await _stt.cancel();
    listening.value = false;
    level.value = 0;
  }
}
