import 'package:flutter/services.dart';

class CbtSecurity {
  static const MethodChannel _channel = MethodChannel('id.sch.cbt.mobile/security');
  static Function(String event)? _eventCallback;

  /// Inisialisasi listener untuk event dari native (misal saat kehilangan fokus karena Google Assistant)
  static void initializeSecurityListener(Function(String event)? onEvent) {
    _eventCallback = onEvent;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWindowFocusLost' || call.method == 'onAssistAttempted') {
        _eventCallback?.call('FOCUS_LOST');
      }
    });
  }

  /// Mengaktifkan mode pengawasan keamanan ujian secara ketat
  static Future<void> setSecurityMode(bool active) async {
    try {
      await _channel.invokeMethod('setSecurityMode', {'active': active});
    } catch (_) {}
  }

  /// Mengizinkan/membuka akses sementara jika siswa membuka lampiran resmi (misal YouTube)
  static Future<void> setExternalResourceAllowed(bool allowed) async {
    try {
      await _channel.invokeMethod('setExternalResourceAllowed', {'allowed': allowed});
    } catch (_) {}
  }

  /// Membuka halaman pengaturan aplikasi Asisten Digital di Android jika ingin dinonaktifkan
  static Future<bool> openAssistSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAssistSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mencegah screenshot & screen recording (Layar hitam jika direkam / dicapture Google)
  static Future<void> enableAntiScreenshot() async {
    try {
      await _channel.invokeMethod('enableSecureScreen');
    } catch (_) {
      // Ignored on unsupported devices
    }
  }

  /// Mengembalikan layar normal saat selesai ujian
  static Future<void> disableAntiScreenshot() async {
    try {
      await _channel.invokeMethod('disableSecureScreen');
    } catch (_) {
      // Ignored
    }
  }

  /// Menjaga layar HP tetap menyala selama ujian agar tidak mati otomatis saat siswa membaca soal
  static Future<void> keepScreenOn(bool enable) async {
    try {
      await _channel.invokeMethod('keepScreenOn', {'enable': enable});
    } catch (_) {
      // Ignored
    }
  }

  /// Memeriksa apakah layar aktif dan interaktif (bukan layar mati otomatis/terkunci)
  static Future<bool> isScreenInteractive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isScreenInteractive');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Kiosk / Lock Task Mode: Mengunci HP agar siswa tidak bisa menekan Home / Recent Apps
  static Future<bool> startKioskLock() async {
    try {
      final res = await _channel.invokeMethod<bool>('startLockTask');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Membuka kunci layar saat selesai atau keluar ujian
  static Future<bool> stopKioskLock() async {
    try {
      final res = await _channel.invokeMethod<bool>('stopLockTask');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
