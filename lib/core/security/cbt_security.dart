import 'package:flutter/services.dart';

class CbtSecurity {
  static const MethodChannel _channel = MethodChannel('id.sch.cbt.mobile/security');

  /// Mencegah screenshot & screen recording (Layar hitam jika direkam)
  static Future<void> enableAntiScreenshot() async {
    try {
      await _channel.invokeMethod('enableSecureScreen');
    } catch (e) {
      // Ignored on unsupported devices
    }
  }

  /// Mengembalikan layar normal saat selesai ujian
  static Future<void> disableAntiScreenshot() async {
    try {
      await _channel.invokeMethod('disableSecureScreen');
    } catch (e) {
      // Ignored
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
