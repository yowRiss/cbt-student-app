import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalExamStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Base URL
  static String getBaseUrl() {
    final saved = _prefs?.getString(AppConstants.keyBaseUrl);
    // Jika belum pernah disetel atau masih tersimpan IP lokal lama, arahkan default ke demo server
    if (saved == null ||
        saved.isEmpty ||
        saved == 'http://192.168.18.28/api/v1' ||
        saved == 'http://192.168.1.100:8000/api/v1') {
      return AppConstants.defaultBaseUrl;
    }
    return saved;
  }

  static Future<void> setBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    if (!cleanUrl.endsWith('/api/v1')) {
      cleanUrl = '$cleanUrl/api/v1';
    }
    await _prefs?.setString(AppConstants.keyBaseUrl, cleanUrl);
  }

  // Auth Token
  static String? getAuthToken() {
    return _prefs?.getString(AppConstants.keyAuthToken);
  }

  static Future<void> setAuthToken(String token) async {
    await _prefs?.setString(AppConstants.keyAuthToken, token);
  }

  static Future<void> clearAuth() async {
    await _prefs?.remove(AppConstants.keyAuthToken);
    await _prefs?.remove(AppConstants.keyUserData);
    await _prefs?.remove(AppConstants.keyActiveSessionToken);
  }

  // User Profile
  static Map<String, dynamic>? getUserData() {
    final raw = _prefs?.getString(AppConstants.keyUserData);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUserData(Map<String, dynamic> data) async {
    await _prefs?.setString(AppConstants.keyUserData, jsonEncode(data));
  }

  // Local Autosave Jawaban Ujian (Offline-First)
  static Map<String, dynamic> getAnswers(String sessionToken) {
    final raw = _prefs?.getString('${AppConstants.keyCachedAnswersPrefix}$sessionToken');
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveAnswerLocally({
    required String sessionToken,
    required String questionId,
    String? selectedOptionId,
    String? essayAnswer,
  }) async {
    final answers = getAnswers(sessionToken);
    answers[questionId] = {
      'selected_option_id': selectedOptionId,
      'essay_answer': essayAnswer,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _prefs?.setString(
      '${AppConstants.keyCachedAnswersPrefix}$sessionToken',
      jsonEncode(answers),
    );
  }

  static Future<void> clearSessionAnswers(String sessionToken) async {
    await _prefs?.remove('${AppConstants.keyCachedAnswersPrefix}$sessionToken');
  }
}
