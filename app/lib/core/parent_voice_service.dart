import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/game_models.dart';
import 'local_store.dart';
import 'music_service.dart';
import 'tts_service.dart';

/// Lời ghi âm của bố mẹ: lưu file trên máy, phát đúng lúc (khen khi làm xong bài, động viên khi gặp khó…).
class ParentVoiceService {
  ParentVoiceService(this._store, this._tts, this._music);

  final LocalStore _store;
  final TtsService _tts;
  final MusicService _music;
  final _player = AudioPlayer();
  final _rnd = Random();
  final _lastPlayedAt = <String, DateTime>{};
  String? _lastId;

  /// Đoạn đang phát → hiện băng "💌 Lời nhắn của bố mẹ" trên mọi màn hình.
  final nowPlaying = ValueNotifier<ParentVoice?>(null);

  static bool get supported => !kIsWeb;

  /// Các đoạn dùng được cho một mục đích + bé (đoạn "cho mọi bé" luôn dùng được).
  List<ParentVoice> available(String purpose, String? childId) {
    if (!supported) return const [];
    return _store
        .voices()
        .where((v) =>
            v.enabled &&
            v.purpose == purpose &&
            (v.childId.isEmpty || v.childId == childId) &&
            File(v.path).existsSync())
        .toList();
  }

  bool has(String purpose, String? childId) => available(purpose, childId).isNotEmpty;

  /// Phát một đoạn ngẫu nhiên (khác đoạn vừa phát nếu được). Trả false nếu không có đoạn nào
  /// hoặc vừa phát cùng loại trong khoảng [cooldown] (để lời khen của bố mẹ luôn "đặc biệt").
  Future<bool> play(String purpose, {String? childId, Duration cooldown = const Duration(seconds: 90)}) async {
    final list = available(purpose, childId);
    if (list.isEmpty) return false;
    final last = _lastPlayedAt[purpose];
    if (last != null && DateTime.now().difference(last) < cooldown) return false;
    var pick = list[_rnd.nextInt(list.length)];
    if (list.length > 1 && pick.id == _lastId) {
      pick = list.firstWhere((v) => v.id != _lastId, orElse: () => pick);
    }
    _lastPlayedAt[purpose] = DateTime.now();
    await playOne(pick);
    return true;
  }

  /// Phát đúng một đoạn (bố mẹ nghe thử, hoặc do [play] chọn). Chờ phát xong.
  Future<void> playOne(ParentVoice v) async {
    if (!supported) return;
    await stop();
    await _tts.stop(); // không để giọng Cú đè lên giọng bố mẹ
    _lastId = v.id;
    nowPlaying.value = v;
    _music.duck(true);
    try {
      final done = _player.onPlayerComplete.first;
      await _player.play(DeviceFileSource(v.path), volume: 1.0);
      await done.timeout(Duration(milliseconds: max(4000, v.durationMs + 2500)), onTimeout: () {});
    } catch (e) {
      debugPrint('Không phát được lời bố mẹ: $e');
    } finally {
      _music.duck(false);
      if (nowPlaying.value?.id == v.id) nowPlaying.value = null;
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    if (nowPlaying.value != null) {
      nowPlaying.value = null;
      _music.duck(false);
    }
  }

  // ------------------------------------------------------------------ lưu / xóa
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/parent_voices');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Đường dẫn file mới cho một lần ghi âm.
  static Future<String> newPath(String id) async => '${(await _dir()).path}/$id.m4a';

  Future<void> save(ParentVoice v) => _store.saveVoice(v);

  Future<void> delete(ParentVoice v) async {
    await _store.deleteVoice(v.id);
    try {
      final f = File(v.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  static Future<void> deleteFile(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }
}

/// Ghi âm giọng bố mẹ (AAC .m4a, mono, nhỏ gọn ~ 0,5 MB/phút). Tối đa [maxSeconds] giây.
class VoiceRecorder {
  final _rec = AudioRecorder();
  final level = ValueNotifier<double>(0); // 0..1 – vẽ thanh âm lượng
  final elapsed = ValueNotifier<int>(0); // giây
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  Stopwatch? _sw;
  String? _path;
  static const maxSeconds = 30;

  bool get recording => _sw != null;

  /// Bắt đầu ghi vào [path]. Trả false nếu không có quyền micro hoặc lỗi thiết bị.
  Future<bool> start(String path, {VoidCallback? onAutoStop}) async {
    try {
      if (!await _rec.hasPermission()) return false;
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
    } catch (e) {
      debugPrint('Không ghi âm được: $e');
      return false;
    }
    _path = path;
    _sw = Stopwatch()..start();
    elapsed.value = 0;
    _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 120)).listen((a) {
      // dBFS: -45 (im lặng) … 0 (rất to)
      level.value = ((a.current + 45) / 45).clamp(0.0, 1.0).toDouble();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final s = (_sw?.elapsedMilliseconds ?? 0) ~/ 1000;
      if (s != elapsed.value) elapsed.value = s;
      if (s >= maxSeconds) onAutoStop?.call();
    });
    return true;
  }

  /// Dừng ghi. Trả (đường dẫn, thời lượng ms) hoặc null nếu chưa ghi.
  Future<(String, int)?> stop() async {
    if (_sw == null) return null;
    final ms = _sw!.elapsedMilliseconds;
    _sw = null;
    _timer?.cancel();
    await _ampSub?.cancel();
    level.value = 0;
    String? out;
    try {
      out = await _rec.stop();
    } catch (e) {
      debugPrint('Lỗi dừng ghi âm: $e');
    }
    final p = out ?? _path;
    return p == null ? null : (p, ms);
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _ampSub?.cancel();
    try {
      if (_sw != null) await _rec.cancel();
      await _rec.dispose();
    } catch (_) {}
  }
}
