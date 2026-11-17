import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/tutor_models.dart';

/// Mất mạng / không tới được máy chủ → app chuyển sang chế độ offline (FR-70).
class ApiOffline implements Exception {
  final String message;
  ApiOffline([this.message = 'offline']);
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
  ApiClient(String baseUrl, String appSecret)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 45),
          headers: {'x-app-secret': appSecret},
        ));

  final Dio _dio;

  // ------------------------------------------------------------------ tiện ích
  /// FR-71: tự thử lại tối đa 3 lần khi mạng chập chờn (chỉ lỗi kết nối – yêu cầu chưa tới máy chủ).
  Future<Response> _send(Future<Response> Function() f, {int times = 3}) async {
    for (var i = 0;; i++) {
      try {
        return await f();
      } on DioException catch (e) {
        final connection = e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout;
        if (connection && i < times - 1) {
          await Future.delayed(Duration(milliseconds: 800 * (1 << i)));
          continue;
        }
        if (connection || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.unknown) {
          throw ApiOffline(e.message ?? e.type.name);
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
    final r = await _send(() =>
        _dio.post('/v1/session/select', data: {'session_id': sessionId, 'problem_id': problemId}));
    return StartResult.fromJson(_map(r));
  }

  Future<TurnResult> confirm(String sessionId) async {
    final r = await _send(() => _dio.post('/v1/session/confirm', data: {'session_id': sessionId}));
    return TurnResult.fromJson(_map(r));
  }

  Future<TurnResult> turn(String sessionId, String input, String mode) async {
    final r = await _send(() => _dio.post('/v1/session/turn',
        data: {'session_id': sessionId, 'child_input': input, 'input_mode': mode}));
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

  Future<ParentReport> parentReport(String deviceId, String childId, String token,
      {String period = 'day'}) async {
    final r = await _send(() => _dio.get('/v1/parent/report',
        queryParameters: {'device_id': deviceId, 'child_id': childId, 'period': period},
        options: _parent(token)));
    return ParentReport.fromJson(_map(r));
  }

  Future<Map<String, dynamic>> parentAnswer(String sessionId, String token) async {
    final r = await _send(() => _dio.get('/v1/parent/answer',
        queryParameters: {'session_id': sessionId}, options: _parent(token)));
    return _map(r);
  }

  Future<void> deleteChild(String deviceId, String childId, String token) async {
    await _send(() => _dio.delete('/v1/parent/child',
        queryParameters: {'device_id': deviceId, 'child_id': childId}, options: _parent(token)));
  }
}
