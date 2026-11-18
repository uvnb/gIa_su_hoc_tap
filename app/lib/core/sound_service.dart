import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Hiệu ứng âm thanh ngắn (< 1 giây): pop, ting, tada + âm trò chơi – nhỏ hơn giọng Cú (mục 6.3).
class SoundService {
  final _players = <String, AudioPlayer>{};
  bool enabled = true;
  static const _volume = 0.45;

  Future<void> init() async {
    for (final name in ['pop', 'ting', 'tada', 'jump', 'bump', 'clear', 'unlock', 'oops', 'coin']) {
      final p = AudioPlayer();
      _players[name] = p;
      try {
        if (!kIsWeb) await p.setPlayerMode(PlayerMode.lowLatency); // trình duyệt không hỗ trợ chế độ này
        await p.setReleaseMode(ReleaseMode.stop);
        // trộn cùng nhạc nền + giọng Cú, không làm tắt tiếng nào
        await p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      } catch (_) {
        // vẫn phát được với cấu hình mặc định
      }
    }
  }

  Future<void> _play(String name) async {
    if (!enabled) return;
    final p = _players[name];
    if (p == null) return;
    try {
      await p.stop();
      await p.play(AssetSource('sounds/$name.wav'), volume: _volume);
    } catch (_) {
      // âm thanh hiệu ứng không quan trọng – bỏ qua lỗi
    }
  }

  Future<void> pop() => _play('pop');
  Future<void> ting() => _play('ting');
  Future<void> tada() => _play('tada');

  // ---- trò chơi ----
  Future<void> jump() => _play('jump');
  Future<void> bump() => _play('bump');
  Future<void> clear() => _play('clear');
  Future<void> unlock() => _play('unlock');
  Future<void> oops() => _play('oops'); // "ơ…" nhẹ nhàng khi chưa đúng – không phải tiếng phạt
  Future<void> coin() => _play('coin');
}
