import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

/// Giọng Việt tự nhiên chạy NGAY TRÊN MÁY (không cần mạng, không gửi chữ đi đâu):
///  - mô hình Piper "vi_VN-vais1000-medium" – github.com/rhasspy/piper (MIT),
///    dữ liệu giọng VAIS-1000 (CC BY 4.0);
///  - chạy bằng sherpa-onnx – github.com/k2-fsa/sherpa-onnx (Apache-2.0).
/// Mô hình chạy trong một isolate riêng để giao diện không bị giật. Câu đã đọc được lưu thành
/// file WAV (bộ nhớ đệm) nên những câu hay lặp lại (lời khen, lời chào) phát ngay lập tức.
class NeuralTts {
  static const credit = 'Giọng đọc: Piper vi_VN vais1000 (MIT) · dữ liệu VAIS-1000 (CC BY 4.0) · sherpa-onnx';
  static const _assetDir = 'assets/tts/vi';
  static const _version = 'vais1000-medium-2';

  /// Đổi giá trị này khi đổi bộ chạy mô hình → máy từng bị tắt giọng tự nhiên sẽ được thử lại.
  static const _engine = 'sherpa1.12.29-ort1.17.1-t1';
  static const _files = [
    'vi.onnx',
    'tokens.txt',
    'espeak-ng-data/intonations',
    'espeak-ng-data/phondata',
    'espeak-ng-data/phondata-manifest',
    'espeak-ng-data/phonindex',
    'espeak-ng-data/phontab',
    'espeak-ng-data/vi_dict',
    'espeak-ng-data/en_dict',
    'espeak-ng-data/lang/aav/vi',
    'espeak-ng-data/lang/aav/vi-VN-x-central',
    'espeak-ng-data/lang/aav/vi-VN-x-south',
    'espeak-ng-data/lang/gmw/en',
  ];

  SendPort? _toWorker;
  final _pending = <int, Completer<bool>>{};
  int _nextId = 0;
  Future<bool>? _starting;
  Future<bool>? _localStarting;
  String _cacheDir = '';

  /// Xin máy chủ đọc một câu (cùng giọng Piper, máy chủ tạo nhanh gấp ~30 lần tablet) → byte WAV.
  Future<Uint8List?> Function(String text, double speed, double pitch)? cloud;
  DateTime _cloudDownUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// Bộ tạo giọng ngay trên máy đã sẵn sàng (dùng khi mất mạng).
  bool get localReady => _toWorker != null;

  /// Chuẩn bị bộ nhớ đệm (nhanh). Bộ tạo giọng trên máy chỉ nạp khi cần (mất mạng), vì trên chip
  /// Cortex-A53 việc nạp mất ~17 giây và tạo giọng chậm gấp 3 lần thời lượng câu.
  Future<bool> start() => _starting ??= _prepare();

  Future<bool> _prepare() async {
    if (kIsWeb) return false;
    try {
      final cache = Directory('${(await getTemporaryDirectory()).path}/cu_voice');
      cache.createSync(recursive: true);
      _cacheDir = cache.path;
      _trimCache(cache);
      return true;
    } catch (e) {
      debugPrint('Không chuẩn bị được bộ nhớ đệm giọng: $e');
      return false;
    }
  }

  /// Nạp bộ tạo giọng trên máy (chạy nền, chỉ một lần).
  Future<bool> startLocal() => _localStarting ??= _startLocal();

  Future<bool> _startLocal() async {
    if (kIsWeb) return false;
    try {
      final support = await getApplicationSupportDirectory();
      // CHỐNG VĂNG APP: nếu lần trước app bị tắt đột ngột lúc đang nạp / thử giọng (máy không chạy
      // được bộ mô hình), lần này không dùng giọng tự nhiên nữa – Cú dùng giọng dự phòng.
      final disabled = File('${support.path}/tts_disabled');
      final probe = File('${support.path}/tts_probe');
      if (disabled.existsSync() && disabled.readAsStringSync() == _engine) return false;
      if (probe.existsSync() && probe.readAsStringSync() == _engine) {
        disabled.writeAsStringSync(_engine);
        probe.deleteSync();
        debugPrint('Giọng tự nhiên đã làm app dừng ở lần trước – tắt, dùng giọng dự phòng');
        return false;
      }
      _synthProbe = File('${support.path}/tts_synth_probe');
      _synthFails = File('${support.path}/tts_synth_fails');
      if (_synthProbe!.existsSync()) {
        // app dừng giữa lúc đang tạo giọng: đếm, 2 lần liên tiếp thì tắt hẳn
        final n = (int.tryParse(_synthFails!.existsSync() ? _synthFails!.readAsStringSync() : '0') ?? 0) + 1;
        _synthProbe!.deleteSync();
        if (n >= 2) {
          disabled.writeAsStringSync(_engine);
          _synthFails!.deleteSync();
          return false;
        }
        _synthFails!.writeAsStringSync('$n');
      }
      final dir = Directory('${support.path}/tts_vi');
      final marker = File('${dir.path}/.ok');
      if (!marker.existsSync() || marker.readAsStringSync() != _version) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
        for (final f in _files) {
          final data = await rootBundle.load('$_assetDir/$f');
          final out = File('${dir.path}/$f');
          out.parent.createSync(recursive: true);
          await out.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
        }
        marker.writeAsStringSync(_version);
      }

      final fromWorker = ReceivePort();
      final ready = Completer<bool>();
      fromWorker.listen((msg) {
        if (msg is SendPort) {
          _toWorker = msg;
        } else if (msg is List && msg.length == 2 && msg[0] == 'ready') {
          debugPrint('Cú: nạp + thử giọng tự nhiên mất ${msg[1]} ms');
          try {
            if (probe.existsSync()) probe.deleteSync();
          } catch (_) {}
          if (!ready.isCompleted) ready.complete(true);
        } else if (msg is String && msg.startsWith('error')) {
          debugPrint('Giọng tự nhiên lỗi: $msg');
          _toWorker = null;
          if (!ready.isCompleted) ready.complete(false);
        } else if (msg is List && msg.length == 4) {
          _pending.remove(msg[0] as int)?.complete(msg[1] == true);
          if (_pending.isEmpty) _clearSynthProbe(success: msg[1] == true);
          debugPrint('Cú giọng tự nhiên: tạo ${msg[3]} ms âm thanh mất ${msg[2]} ms');
        }
      });
      probe.writeAsStringSync(_engine, flush: true);
      await Isolate.spawn(_worker, [fromWorker.sendPort, dir.path]);
      final ok = await ready.future.timeout(const Duration(seconds: 60), onTimeout: () => false);
      if (!ok) _toWorker = null;
      return ok;
    } catch (e) {
      debugPrint('Không khởi động được giọng tự nhiên: $e');
      _toWorker = null;
      return false;
    }
  }

  File? _synthProbe;
  File? _synthFails;

  void _clearSynthProbe({required bool success}) {
    try {
      if (_synthProbe?.existsSync() ?? false) _synthProbe!.deleteSync();
      if (success && (_synthFails?.existsSync() ?? false)) _synthFails!.deleteSync();
    } catch (_) {}
  }

  /// Giữ bộ nhớ đệm gọn: quá 400 câu thì xóa bớt những câu cũ nhất.
  static void _trimCache(Directory cache) {
    try {
      final files = cache.listSync().whereType<File>().toList();
      if (files.length <= 400) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - 300)) {
        f.deleteSync();
      }
    } catch (_) {}
  }

  /// Tạo (hoặc lấy từ bộ nhớ đệm) file WAV cho một câu. [speed] > 1 nói nhanh hơn,
  /// [pitch] > 1 giọng cao, trong trẻo hơn. Trả null nếu không tạo được.
  Future<String?> synthFile(String text, {double speed = 1.0, double pitch = 1.0}) async {
    if (_cacheDir.isEmpty) return null;
    final key = cacheKey('$_version|${speed.toStringAsFixed(2)}|${pitch.toStringAsFixed(2)}|$text');
    final path = '$_cacheDir/$key.wav';
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > 44) {
      try {
        f.setLastModifiedSync(DateTime.now());
      } catch (_) {}
      return path;
    }
    // 1) máy chủ (nhanh)
    final c0 = cloud;
    if (c0 != null && DateTime.now().isAfter(_cloudDownUntil)) {
      final sw = Stopwatch()..start();
      Uint8List? bytes;
      try {
        bytes = await c0(text, speed, pitch).timeout(const Duration(seconds: 12), onTimeout: () => null);
      } catch (_) {
        bytes = null;
      }
      if (bytes != null && bytes.length > 44 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF') {
        final tmp = File('$path.tmp');
        tmp.writeAsBytesSync(bytes, flush: true);
        tmp.renameSync(path);
        debugPrint('Cú giọng tự nhiên (máy chủ): ${((bytes.length - 44) / 44.1).round()} ms âm thanh, chờ ${sw.elapsedMilliseconds} ms');
        return path;
      }
      // không tới được máy chủ: 1 phút tới dùng bộ tạo giọng trên máy, khỏi chờ mạng mỗi câu
      _cloudDownUntil = DateTime.now().add(const Duration(minutes: 1));
    }
    // 2) ngay trên máy (mất mạng): chưa nạp thì nạp nền, câu này tạm dùng giọng dự phòng
    final port = _toWorker;
    if (port == null) {
      unawaited(startLocal());
      return null;
    }
    final id = _nextId++;
    final c = Completer<bool>();
    _pending[id] = c;
    try {
      _synthProbe?.writeAsStringSync('1');
    } catch (_) {}
    port.send([id, text, speed, pitch, path]);
    final ok = await c.future.timeout(const Duration(seconds: 40), onTimeout: () {
      _pending.remove(id);
      return false;
    });
    return ok ? path : null;
  }

  static void _worker(List args) {
    final toMain = args[0] as SendPort;
    final dir = args[1] as String;
    final inbox = ReceivePort();
    toMain.send(inbox.sendPort);
    sherpa.OfflineTts? tts;
    try {
      final sw = Stopwatch()..start();
      sherpa.initBindings();
      tts = sherpa.OfflineTts(sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: '$dir/vi.onnx',
            tokens: '$dir/tokens.txt',
            dataDir: '$dir/espeak-ng-data',
            // ít "dao động" hơn mặc định (0.667 / 0.8) một chút → giọng đều, rõ, dễ nghe cho trẻ
            noiseScale: 0.6,
            noiseScaleW: 0.75,
          ),
          // 1 luồng: trên chip Cortex-A53 (MT8765) nhóm luồng của ONNX Runtime làm hỏng bộ nhớ → app văng.
          numThreads: 1,
          debug: false,
        ),
        maxNumSenetences: 1,
      ));
      // Thử tạo một câu ngắn ngay: máy nào không chạy được mô hình sẽ lộ ra ở đây (lúc còn đang nạp),
      // và lần tạo câu đầu tiên thật sự cũng nhanh hơn.
      tts.generate(text: 'Xin chào.', sid: 0, speed: 1.0);
      toMain.send(['ready', sw.elapsedMilliseconds]);
    } catch (e) {
      toMain.send('error $e');
      return;
    }
    inbox.listen((msg) {
      final m = msg as List;
      final id = m[0] as int;
      try {
        final text = m[1] as String;
        final speed = (m[2] as num).toDouble();
        final pitch = (m[3] as num).toDouble();
        final path = m[4] as String;
        // Nâng cao độ bằng cách phát nhanh hơn [pitch] lần → tạo giọng chậm hơn đúng chừng ấy để bù.
        final sw = Stopwatch()..start();
        final a = tts!.generate(text: text, sid: 0, speed: speed / pitch);
        final samples = resample(a.samples, pitch);
        final tmp = File('$path.tmp');
        tmp.writeAsBytesSync(wavBytes(samples, a.sampleRate), flush: true);
        tmp.renameSync(path);
        toMain.send([id, true, sw.elapsedMilliseconds, samples.length * 1000 ~/ a.sampleRate]);
      } catch (e) {
        toMain.send([id, false, 0, 0]);
      }
    });
  }
}

/// Tên file ổn định cho một câu (2 lần FNV-1a 32-bit, xuôi và ngược).
String cacheKey(String s) {
  int fnv(Iterable<int> units) {
    var h = 0x811c9dc5;
    for (final u in units) {
      h = ((h ^ u) * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  final a = fnv(s.codeUnits);
  final b = fnv(s.codeUnits.reversed);
  return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}${s.length}';
}

/// "Đọc nhanh" các mẫu theo hệ số [factor] (nội suy tuyến tính). factor > 1 → giọng cao hơn và ngắn hơn.
Float32List resample(Float32List samples, double factor) {
  if ((factor - 1).abs() < 0.01 || samples.isEmpty) return samples;
  final n = (samples.length / factor).floor();
  final out = Float32List(n);
  for (var i = 0; i < n; i++) {
    final x = i * factor;
    final j = x.floor();
    final t = x - j;
    final a = samples[j];
    final b = j + 1 < samples.length ? samples[j + 1] : a;
    out[i] = a + (b - a) * t;
  }
  return out;
}

/// WAV PCM 16-bit mono. Thêm 60 ms lặng ở đầu để loa không "nuốt" chữ đầu tiên.
Uint8List wavBytes(Float32List samples, int sampleRate) {
  final lead = sampleRate * 60 ~/ 1000;
  final count = lead + samples.length;
  final data = ByteData(44 + count * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + count * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final v = (samples[i] * 32767).round().clamp(-32768, 32767);
    data.setInt16(44 + (lead + i) * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Tách đoạn dài thành câu ngắn để vừa phát câu trước vừa tạo câu sau (Cú bắt đầu nói sớm hơn).
/// Câu quá dài thì tách thêm ở dấu phẩy.
List<String> splitSentences(String text) {
  final parts = <String>[];
  final buf = StringBuffer();
  void flush() {
    final s = buf.toString().trim();
    if (s.isNotEmpty) parts.add(s);
    buf.clear();
  }

  final chars = text.split('');
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    buf.write(ch);
    final next = i + 1 < chars.length ? chars[i + 1] : ' ';
    final atBreak = next.trim().isEmpty;
    final len = buf.toString().trim().length;
    if ('.!?…;\n'.contains(ch) && atBreak && len > 12) {
      flush();
    } else if (ch == ',' && atBreak && len > 70) {
      flush();
    }
  }
  flush();
  return parts.where((p) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(p)).toList();
}

/// Đổi ký hiệu toán và cách viết số sang chữ để giọng đọc đúng kiểu cô giáo đọc:
/// "15 + 6 = 21" → "15 cộng 6 bằng 21", "3/4" → "3 phần 4", "1,5" → "1 phẩy 5", "5 × 3" → "5 nhân 3"…
String normalizeVietnamese(String input) {
  var s = input;
  s = s.replaceAll(RegExp(r'[*_#`]{2,}|[*#`]'), ' '); // dấu định dạng markdown
  for (var i = 0; i < 3; i++) {
    s = s.replaceAllMapped(RegExp(r'(\d)\.(\d{3})(?!\d)'), (m) => '${m[1]}${m[2]}'); // 1.000.000 → 1000000
  }
  s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]} phẩy ${m[2]}');
  s = s.replaceAllMapped(RegExp(r'(\d)\s*/\s*(\d)'), (m) => '${m[1]} phần ${m[2]}');
  s = s.replaceAllMapped(RegExp(r'(\d|\?)\s*[x×✕*]\s*(?=\d|\?)'), (m) => '${m[1]} nhân ');
  // "12 : 3" (cách viết phép chia trong sách giáo khoa, có dấu cách) – không đụng "Câu 1: …" hay "10:30"
  s = s.replaceAllMapped(RegExp(r'(\d|\?)\s+:\s+(?=\d|\?)'), (m) => '${m[1]} chia ');
  s = s.replaceAllMapped(RegExp(r'(\d|\?)\s*÷\s*(?=\d|\?)'), (m) => '${m[1]} chia ');
  // phép trừ: "15 - 6" (có dấu cách), hoặc "15-6" khi đang là một phép tính có dấu "="
  final minus = s.contains('=') ? RegExp(r'(\d|\?)\s*[-–−]\s*(?=\d|\?)') : RegExp(r'(\d|\?)\s+[-–−]\s+(?=\d|\?)');
  s = s.replaceAllMapped(minus, (m) => '${m[1]} trừ ');
  s = s.replaceAll('+', ' cộng ');
  s = s.replaceAll(RegExp(r'\s*=\s*'), ' bằng ');
  s = s.replaceAll(RegExp(r'\s*≤\s*'), ' bé hơn hoặc bằng ');
  s = s.replaceAll(RegExp(r'\s*≥\s*'), ' lớn hơn hoặc bằng ');
  s = s.replaceAll(RegExp(r'\s*<\s*'), ' bé hơn ');
  s = s.replaceAll(RegExp(r'\s*>\s*'), ' lớn hơn ');
  s = s.replaceAll('%', ' phần trăm');
  const units = {
    'cm²': 'xăng-ti-mét vuông',
    'm²': 'mét vuông',
    'km': 'ki-lô-mét',
    'cm': 'xăng-ti-mét',
    'mm': 'mi-li-mét',
    'dm': 'đề-xi-mét',
    'kg': 'ki-lô-gam',
    'g': 'gam',
    'm': 'mét',
    'l': 'lít',
    'ml': 'mi-li-lít',
    'đ': 'đồng',
  };
  s = s.replaceAllMapped(
    RegExp(r'(\d)\s*(cm²|m²|km|cm|mm|dm|kg|ml|g|m|l|đ)(?![\p{L}\p{N}])', unicode: true),
    (m) => '${m[1]} ${units[m[2]]}',
  );
  s = s.replaceAll('?', '? ').replaceAll('…', '. ');
  s = s.replaceAll(RegExp(r'[“”"()\[\]{}]'), ' ');
  return s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}
