import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Nhạc nền vui nhộn cho trò chơi (tự tổng hợp bằng tool/gen_music.py → không lo bản quyền).
/// Tự nhỏ lại khi Cú nói hoặc khi phát lời của bố mẹ; tạm dừng khi app chạy nền.
class MusicService with WidgetsBindingObserver {
  MusicService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _player = AudioPlayer();
  bool enabled = true;
  String? _track; // bài đang (hoặc lẽ ra đang) phát
  bool _playing = false;
  int _duckers = 0; // số nguồn đang yêu cầu nhỏ nhạc (Cú nói, lời bố mẹ)
  static const _volume = 0.30;
  static const _duckedVolume = 0.07;

  double get _targetVolume => _duckers > 0 ? _duckedVolume : _volume;

  Future<void> init() async {
    try {
      // Trộn cùng giọng Cú: không giành "audio focus" để TTS không làm nhạc tắt hẳn (và ngược lại).
      await _player.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      await _player.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Nhạc nền: $e');
    }
  }

  /// Phát lặp một bài trong assets/music/ (blocks | runner).
  Future<void> play(String track) async {
    _track = track;
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('music/$track.wav'), volume: _targetVolume);
      _playing = true;
    } catch (e) {
      debugPrint('Không phát được nhạc $track: $e');
    }
  }

  Future<void> stop() async {
    _track = null;
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Bật/tắt nhạc (nút 🎵 trong trò chơi, hoặc cài đặt của bố mẹ).
  Future<void> setEnabled(bool v) async {
    enabled = v;
    if (!v) {
      _playing = false;
      try {
        await _player.pause();
      } catch (_) {}
    } else if (_track != null) {
      await play(_track!);
    }
  }

  /// Nhỏ nhạc khi có tiếng nói quan trọng (gọi theo cặp duck(true) … duck(false)).
  void duck(bool on) {
    _duckers = on ? _duckers + 1 : (_duckers > 0 ? _duckers - 1 : 0);
    if (_playing) _player.setVolume(_targetVolume).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_track == null || !enabled) return;
    if (state == AppLifecycleState.resumed) {
      _player.resume().catchError((_) {});
      _playing = true;
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _player.pause().catchError((_) {});
      _playing = false;
    }
  }
}
