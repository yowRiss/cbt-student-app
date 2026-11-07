import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../storage/local_exam_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  static final http.Client _client = http.Client();

  static Map<String, String> _buildHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = LocalExamStorage.getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri _buildUri(String path, [Map<String, String>? queryParams]) {
    final baseUrl = LocalExamStorage.getBaseUrl();
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$baseUrl/$cleanPath').replace(queryParameters: queryParams);
  }

  // Auth: Login
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    try {
      final response = await _client.post(
        _buildUri('auth/login'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email': identifier,
          'password': password,
        }),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['token'] as String;
        await LocalExamStorage.setAuthToken(token);
        if (data['user'] != null) {
          await LocalExamStorage.setUserData(data['user']);
        }
        return data;
      } else {
        throw ApiException(data['message'] ?? 'Login gagal. Periksa username dan password.', response.statusCode);
      }
    } on SocketException {
      throw ApiException('Tidak dapat terhubung ke server CBT. Periksa alamat IP atau jaringan Wi-Fi.');
    } on TimeoutException {
      throw ApiException('Koneksi ke server timeout. Silakan coba kembali.');
    }
  }

  // Auth: Logout
  static Future<void> logout() async {
    try {
      await _client.post(
        _buildUri('auth/logout'),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
    await LocalExamStorage.clearAuth();
  }

  // Student: Get Exams List
  static Future<List<dynamic>> getStudentExams() async {
    try {
      final response = await _client.get(
        _buildUri('student/exams'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Backend returns either list of exams or dashboard data containing exams
        if (data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data['exams'] is List) {
          return data['exams'] as List<dynamic>;
        } else if (data['data'] != null && data['data']['exams'] is List) {
          return data['data']['exams'] as List<dynamic>;
        }
        return [];
      } else {
        throw ApiException(data['message'] ?? 'Gagal memuat daftar ujian.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal memuat ujian: $e');
    }
  }

  // Student: Enter Exam with Token
  static Future<Map<String, dynamic>> enterExam(dynamic examId, String token) async {
    try {
      final response = await _client.post(
        _buildUri('student/exams/$examId/enter'),
        headers: _buildHeaders(),
        body: jsonEncode({'token': token}),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Token ujian salah atau tidak valid.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal verifikasi token ujian: $e');
    }
  }

  // Student: Start Exam Session
  static Future<Map<String, dynamic>> startExam(dynamic examId) async {
    try {
      final response = await _client.post(
        _buildUri('student/exams/$examId/start'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal memulai ujian.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal memulai sesi ujian: $e');
    }
  }

  // Student: Load Exam Taking (Questions & Existing Answers)
  static Future<Map<String, dynamic>> loadExamTaking(String sessionToken) async {
    try {
      final response = await _client.get(
        _buildUri('student/exam-sessions/$sessionToken'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal memuat soal ujian.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal memuat soal: $e');
    }
  }

  // Student: Save Answer (Autosave)
  static Future<bool> saveAnswer({
    required String sessionToken,
    required dynamic questionId,
    dynamic selectedOptionId,
    String? essayAnswer,
  }) async {
    try {
      final response = await _client.post(
        _buildUri('student/exam-sessions/$sessionToken/answers'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'question_id': questionId.toString(),
          'selected_option_id': selectedOptionId?.toString(),
          'essay_answer': essayAnswer,
        }),
      ).timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Local fallback handles offline scenario
      return false;
    }
  }

  // Student: Report Violation
  static Future<Map<String, dynamic>?> reportViolation({
    required String sessionToken,
    required String violationType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _client.post(
        _buildUri('student/exam-sessions/$sessionToken/violation'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'violation_type': violationType,
          'metadata': metadata ?? {},
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return (data['data'] ?? data) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Student: Submit Exam
  static Future<Map<String, dynamic>> submitExam(String sessionToken) async {
    try {
      final response = await _client.post(
        _buildUri('student/exam-sessions/$sessionToken/submit'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal menyelesaikan ujian.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal mengumpulkan ujian: $e');
    }
  }

  // Student: Time Remaining Check
  static Future<int?> getTimeRemaining(String sessionToken) async {
    try {
      final response = await _client.get(
        _buildUri('student/exam-sessions/$sessionToken/time-remaining'),
        headers: _buildHeaders(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final res = data['data'] ?? data;
        return res['remaining_seconds'] as int?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
