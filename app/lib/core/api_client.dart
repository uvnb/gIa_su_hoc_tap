import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/tutor_models.dart';

/// Mất mạng / không tới được máy chủ → app chuyển sang chế độ offline (FR-70).
class ApiOffline implements Exception {
  final String message;

  /// true = yêu cầu chưa tới được máy chủ (an toàn để thử địa chỉ khác).
  final bool notReached;
  ApiOffline(this.message, {this.notReached = false});
  @override
  String toString() => 'ApiOffline($message)';
}

class ApiError implements Exception {
  final int status;
  final String message;
  ApiError(this.status, this.message);
  @override
  String toString() => 'ApiError($status, $message)';
}

/// Gọi backend "Cú Brain". App KHÔNG có khóa AI và KHÔNG bao giờ nhận đáp án.
class ApiClient {
  /// [aiHeaders]: khóa AI riêng của phụ huynh (x-ai-provider, x-ai-key, x-ai-model) – gửi kèm qua HTTPS,
  /// máy chủ chỉ dùng trong yêu cầu đó, không lưu.
  ApiClient(String baseUrl, String appSecret, {Map<String, String> aiHeaders = const {}})
      : _primary = baseUrl,
        _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          // Không tới được máy chủ thì báo nhanh (≈5 giây) thay vì để bé chờ lâu.
          connectTimeout: const Duration(seconds: 4),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 45),
          headers: {'x-app-secret': appSecret, ...aiHeaders},
        ));

  final Dio _dio;
  final String _primary;

  /// Đường cáp USB: máy tính chạy `adb reverse tcp:8090 tcp:8090` thì 127.0.0.1:8090 trên tablet
  /// chính là máy chủ trên máy tính – dùng được cả khi Wi-Fi không cho hai máy thấy nhau.
  static const usbUrl = 'http://127.0.0.1:8090';

  /// Địa chỉ đang dùng (để Góc phụ huynh hiển thị).
  String get currentBaseUrl => _dio.options.baseUrl;

  // ------------------------------------------------------------------ tiện ích
  /// Gửi yêu cầu; không tới được địa chỉ đang dùng thì thử địa chỉ còn lại (Wi-Fi ↔ cáp USB)
  /// và nhớ địa chỉ chạy được cho các lần sau.
  Future<Response> _send(Future<Response> Function() f, {int times = 2}) async {
    try {
      return await _sendOnce(f, times: times);
    } on ApiOffline catch (e) {
      if (kIsWeb || !e.notReached || _primary == usbUrl) rethrow;
      final current = _dio.options.baseUrl;
      _dio.options.baseUrl = current == usbUrl ? _primary : usbUrl;
      try {
        return await _sendOnce(f, times: 1);
      } on ApiOffline {
        _dio.options.baseUrl = current;
        rethrow;
      }
    }
  }

  /// FR-71: tự thử lại khi mạng chập chờn (chỉ lỗi kết nối – yêu cầu chưa tới máy chủ).
  /// 2 lần × 4 giây: đủ vượt một lần chập chờn mà bé không phải chờ lâu khi máy chủ tắt.
  Future<Response> _sendOnce(Future<Response> Function() f, {int times = 2}) async {
    for (var i = 0;; i++) {
      try {
        return await f();
      } on DioException catch (e) {
        final connection = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout;
        if (connection && i < times - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        if (connection || e.type == DioExceptionType.unknown) {
          throw ApiOffline(e.message ?? e.type.name, notReached: true);
        }
        if (e.type == DioExceptionType.receiveTimeout) {
          throw ApiOffline(e.message ?? e.type.name); // đã tới máy chủ – không gửi lại kẻo trùng lượt
        }
        final status = e.response?.statusCode ?? 0;
        final data = e.response?.data;
        final msg = data is Map && data['detail'] != null ? data['detail'].toString() : (e.message ?? 'lỗi');
        throw ApiError(status, msg);
      }
    }
  }

  Map<String, dynamic> _map(Response r) => Map<String, dynamic>.from(r.data as Map);

  // ------------------------------------------------------------------ thiết bị
  Future<(String, String)> registerDevice() async {
    final r = await _send(() => _dio.post('/v1/device/register'));
    final m = _map(r);
    return (m['device_id'] as String, m['parent_token'] as String);
  }

  /// Bố mẹ bấm "Lưu & kiểm tra": thử khóa AI (không dùng khóa đang lưu, dùng khóa vừa nhập).
  /// Trả (ok, model, lỗi dễ hiểu).
  Future<(bool, String, String)> checkAiKey(String provider, String key) async {
    try {
      final r = await _send(() => _dio.post('/v1/ai/check',
          options: Options(
            headers: {'x-ai-provider': provider, 'x-ai-key': key, 'x-ai-model': ''},
            receiveTimeout: const Duration(seconds: 60),
          )));
      final m = r.data as Map;
      return (m['ok'] == true, '${m['model'] ?? ''}', '${m['error'] ?? ''}');
    } on ApiOffline {
      return (false, '', 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.');
    } catch (e) {
      return (false, '', 'Máy chủ chưa kiểm tra được khóa ($e).');
    }
  }

  Future<bool> health() async {
    try {
      final r = await _dio.get('/v1/health');
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------ phiên học
  Future<StartResult> startSession({
    Uint8List? jpeg,
    String questionText = '',
    required int grade,
    required String subject,
    required String nickname,
    String deviceId = '',
    String childId = '',
    String provider = '',
    String tier = '',
  }) async {
    final r = await _send(() {
      final form = FormData.fromMap({
        'grade': grade,
        'subject': subject,
        'child_nickname': nickname,
        'question_text': questionText,
        'device_id': deviceId,
        'child_id': childId,
        if (provider.isNotEmpty) 'provider': provider,
        if (tier.isNotEmpty) 'tier': tier,
        if (jpeg != null) 'image': MultipartFile.fromBytes(jpeg, filename: 'q.jpg'),
      });
      return _dio.post('/v1/session/start', data: form);
    });
    return StartResult.fromJson(_map(r));
  }

  Future<StartResult> selectProblem(String sessionId, int problemId) async {
    final r =
        await _send(() => _dio.post('/v1/session/select', data: {'session_id': sessionId, 'problem_id': problemId}));
    return StartResult.fromJson(_map(r));
  }

  Future<TurnResult> confirm(String sessionId) async {
    final r = await _send(() => _dio.post('/v1/session/confirm', data: {'session_id': sessionId}));
    return TurnResult.fromJson(_map(r));
  }

  Future<TurnResult> turn(String sessionId, String input, String mode) async {
    final r = await _send(
        () => _dio.post('/v1/session/turn', data: {'session_id': sessionId, 'child_input': input, 'input_mode': mode}));
    return TurnResult.fromJson(_map(r));
  }

  Future<TurnResult> scratch(String sessionId, Uint8List image) async {
    final r = await _send(() => _dio.post('/v1/session/scratch',
        data: FormData.fromMap({
          'session_id': sessionId,
          'image': MultipartFile.fromBytes(image, filename: 'nhap.png'),
        })));
    return TurnResult.fromJson(_map(r));
  }

  Future<StartResult> challenge(String sessionId) async {
    final r = await _send(() => _dio.post('/v1/session/challenge', data: {'session_id': sessionId}));
    return StartResult.fromJson(_map(r));
  }

  Future<Map<String, dynamic>> mysteryBox(int grade) async {
    final r = await _send(() => _dio.get('/v1/mystery-box', queryParameters: {'grade': grade}));
    return _map(r);
  }

  // ------------------------------------------------------------------ Góc phụ huynh
  Options _parent(String token) => Options(headers: {'x-parent-token': token});

  Future<ParentReport> parentReport(String deviceId, String childId, String token, {String period = 'day'}) async {
    final r = await _send(() => _dio.get('/v1/parent/report',
        queryParameters: {'device_id': deviceId, 'child_id': childId, 'period': period}, options: _parent(token)));
    return ParentReport.fromJson(_map(r));
  }

  Future<Map<String, dynamic>> parentAnswer(String sessionId, String token) async {
    final r = await _send(
        () => _dio.get('/v1/parent/answer', queryParameters: {'session_id': sessionId}, options: _parent(token)));
    return _map(r);
  }

  Future<void> deleteChild(String deviceId, String childId, String token) async {
    await _send(() => _dio.delete('/v1/parent/child',
        queryParameters: {'device_id': deviceId, 'child_id': childId}, options: _parent(token)));
  }
}
