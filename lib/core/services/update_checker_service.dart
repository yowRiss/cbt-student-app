import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class ReleaseInfo {
  final String tagName;
  final String cleanVersion;
  final String releaseName;
  final String body;
  final String? apkDownloadUrl;
  final String? htmlUrl;

  ReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.releaseName,
    required this.body,
    this.apkDownloadUrl,
    this.htmlUrl,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawTag = (json['tag_name'] ?? '').toString();
    final cleanVer = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;

    String? apkUrl;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (var asset in assets) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String?;
        break;
      }
    }

    return ReleaseInfo(
      tagName: rawTag,
      cleanVersion: cleanVer,
      releaseName: json['name'] ?? rawTag,
      body: json['body'] ?? '',
      apkDownloadUrl: apkUrl,
      htmlUrl: json['html_url'] as String?,
    );
  }
}

class UpdateCheckerService {
  /// Membandingkan dua string versi semver (misal: "1.1.0" vs "1.0.0")
  static bool isNewerVersion(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = lParts.length > cParts.length ? lParts.length : cParts.length;
      for (int i = 0; i < maxLen; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Cek release terbaru dari GitHub Releases
  static Future<ReleaseInfo?> getLatestRelease() async {
    try {
      final response = await http.get(
        Uri.parse(AppConstants.githubLatestReleaseApi),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CBT-Student-App',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Eksekusi proses unduh APK dengan loading, konfirmasi, dan fallback salin link
  static Future<void> downloadApk(BuildContext context, ReleaseInfo release) async {
    final targetUrl = release.apkDownloadUrl ?? release.htmlUrl;

    if (targetUrl == null || targetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File APK belum tersedia di rilis GitHub.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    // 1. Tampilkan Dialog Konfirmasi Unduhan
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: Color(0xFF1E40AF)),
            SizedBox(width: 10),
            Text('Konfirmasi Unduhan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi browser akan dibuka untuk mengunduh installer APK terbaru:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('File: cbt-student-app-universal.apk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Versi Baru: v${release.cleanVersion}', style: const TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setelah selesai diunduh, klik file pada bilah notifikasi HP Anda untuk memasang.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: const Text('Ya, Buka Browser & Unduh'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // 2. Tampilkan Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1E40AF)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Membuka browser dan menyiapkan unduhan APK...',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );

    bool launched = false;
    try {
      final uri = Uri.parse(targetUrl);
      // Coba mode external application terlebih dahulu
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback ke platform default jika external gagal
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      launched = false;
    }

    if (!context.mounted) return;
    if (Navigator.canPop(context)) Navigator.pop(context); // Tutup loading dialog

    if (launched) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Browser sedang mengunduh file APK. Periksa bilah notifikasi HP Anda.'),
          backgroundColor: Color(0xFF059669),
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      // Jika browser tidak dapat dibuka otomatis, berikan dialog dengan tombol salin link
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tautan Unduhan Langsung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Browser otomatis tidak dapat dibuka. Silakan salin tautan berikut dan buka di Google Chrome atau browser HP Anda:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              SelectableText(
                targetUrl,
                style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: targetUrl));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tautan unduhan berhasil disalin ke clipboard!')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Salin Link Unduhan'),
            ),
          ],
        ),
      );
    }
  }

  /// Cek update dan tampilkan dialog jika ada versi baru
  static Future<void> checkAndShowDialog(
    BuildContext context, {
    bool manualCheck = false,
  }) async {
    // Jika manual check, tampilkan loading dialog
    if (manualCheck) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF1E40AF)),
              SizedBox(width: 20),
              Expanded(
                child: Text('Memeriksa rilis terbaru di GitHub...'),
              ),
            ],
          ),
        ),
      );
    }

    final release = await getLatestRelease();

    if (!context.mounted) return;
    if (manualCheck && Navigator.canPop(context)) {
      Navigator.pop(context); // Tutup loading dialog manual check
    }

    if (release == null) {
      if (manualCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat memeriksa pembaruan. Periksa koneksi internet atau Wi-Fi.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
      return;
    }

    final hasUpdate = isNewerVersion(release.cleanVersion, AppConstants.appVersion);

    if (hasUpdate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Color(0xFF1E40AF)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pembaruan Tersedia!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Versi saat ini: v${AppConstants.appVersion}',
                        style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      Text(
                        'Baru: v${release.cleanVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (release.body.trim().isNotEmpty) ...[
                  const Text(
                    'Catatan Pembaruan:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      release.body.trim(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text(
                  'Siswa disarankan memperbarui aplikasi untuk memastikan kelancaran pengerjaan ujian.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Nanti Saja'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669), // Green
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                downloadApk(context, release);
              },
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Unduh APK Baru'),
            ),
          ],
        ),
      );
    } else if (manualCheck) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplikasi Anda sudah versi terbaru (v${AppConstants.appVersion}).'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }
}
