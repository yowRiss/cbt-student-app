class AppConstants {
  // App Version
  static const String appVersion = '1.4.7';

  // GitHub Auto-Update Configuration
  static const String githubOwner = 'yowRiss';
  static const String githubRepo = 'cbt-student-app';
  static const String githubLatestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  // Default server URL (Otomatis default ke API Demo Cloudflare)
  static const String defaultBaseUrl = 'https://demo-cbt.nerct.dev/api/v1';
  static const String localFallbackBaseUrl = 'http://192.168.18.28/api/v1';

  // Shared Preferences keys
  static const String keyBaseUrl = 'cbt_base_url';
  static const String keyAuthToken = 'cbt_auth_token';
  static const String keyUserData = 'cbt_user_data';
  static const String keyCachedAnswersPrefix = 'cbt_cached_answers_';
  static const String keyActiveSessionToken = 'cbt_active_session_token';

  // Request timeout
  static const Duration timeout = Duration(seconds: 15);
}
