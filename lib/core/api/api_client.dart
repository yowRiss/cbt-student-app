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

  /// Menyesuaikan URL gambar / file lampiran dari backend
  static String? resolveMediaUrl(String? pathOrUrl) {
    if (pathOrUrl == null || pathOrUrl.trim().isEmpty) return null;
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final baseUrl = LocalExamStorage.getBaseUrl();
    try {
      final baseUri = Uri.parse(baseUrl);
      final origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
      if (trimmed.startsWith('/')) {
        return '$origin$trimmed';
      }
      return '$origin/$trimmed';
    } catch (_) {
      return trimmed;
    }
  }

  /// Mengekstrak video ID YouTube dari berbagai format tautan
  static String? extractYoutubeVideoId(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final regExp = RegExp(
      r'(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url.trim());
    return match?.group(1);
  }

  /// Mendapatkan URL thumbnail YouTube berkualitas tinggi
  static String? getYoutubeThumbnail(String? url) {
    final videoId = extractYoutubeVideoId(url);
    if (videoId == null) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
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

  // Student: Get Full Dashboard Data
  static Future<Map<String, dynamic>> getStudentDashboard() async {
    try {
      final response = await _client.get(
        _buildUri('student/dashboard'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal memuat dashboard siswa.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal terhubung ke dashboard: $e');
    }
  }

  // Student: Get Exam Result Detail
  static Future<Map<String, dynamic>> getExamResult(dynamic examId) async {
    try {
      final response = await _client.get(
        _buildUri('student/exams/$examId/result'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal memuat rincian nilai.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal memuat rincian hasil: $e');
    }
  }

  // Student: Get Session Result Detail
  static Future<Map<String, dynamic>> getSessionResult(String sessionToken) async {
    try {
      final response = await _client.get(
        _buildUri('student/exam-sessions/$sessionToken/result'),
        headers: _buildHeaders(),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        throw ApiException(data['message'] ?? 'Gagal memuat rincian hasil sesi.', response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal memuat hasil sesi: $e');
    }
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
        if (data['data'] is List) {
          return data['data'] as List<dynamic>;
        } else if (data['data'] is Map && data['data']['available_exams'] is List) {
          final avail = data['data']['available_exams'] as List<dynamic>;
          final upcoming = (data['data']['upcoming_exams'] as List<dynamic>?) ?? [];
          return [...avail, ...upcoming];
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
      final trimmedToken = token.trim();
      final response = await _client.post(
        _buildUri('student/exams/$examId/enter'),
        headers: _buildHeaders(),
        body: jsonEncode({
          'token': trimmedToken,
          'exam_access_token': trimmedToken,
        }),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        String errorMsg = data['message'] ?? 'Token ujian salah atau tidak valid.';
        if (data['errors'] != null && data['errors'] is Map) {
          final errMap = data['errors'] as Map;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null && errMap[firstKey] is List && (errMap[firstKey] as List).isNotEmpty) {
            errorMsg = errMap[firstKey][0].toString();
          }
        }
        throw ApiException(errorMsg, response.statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Gagal verifikasi token ujian: $e');
    }
  }

  // Student: Start Exam Session
  static Future<Map<String, dynamic>> startExam(dynamic examId, {String? token}) async {
    try {
      final body = <String, dynamic>{
        'consent_confirmed_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (token != null && token.trim().isNotEmpty) {
        final trimmedToken = token.trim();
        body['exam_access_token'] = trimmedToken;
        body['token'] = trimmedToken;
      }

      final response = await _client.post(
        _buildUri('student/exams/$examId/start'),
        headers: _buildHeaders(),
        body: jsonEncode(body),
      ).timeout(AppConstants.timeout);

      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (data['data'] ?? data) as Map<String, dynamic>;
      } else {
        String errorMsg = data['message'] ?? 'Gagal memulai ujian.';
        if (data['errors'] != null && data['errors'] is Map) {
          final errMap = data['errors'] as Map;
          final firstKey = errMap.keys.firstOrNull;
          if (firstKey != null && errMap[firstKey] is List && (errMap[firstKey] as List).isNotEmpty) {
            errorMsg = errMap[firstKey][0].toString();
          }
        }
        throw ApiException(errorMsg, response.statusCode);
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
