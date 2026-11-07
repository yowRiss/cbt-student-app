import 'dart:convert';
import 'package:flutter/material.dart';
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
  /// Membandingkan dua string versi semver (misal: "1.0.1" vs "1.0.0")
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
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ReleaseInfo.fromJson(data);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Cek update dan tampilkan dialog jika ada versi baru
  static Future<void> checkAndShowDialog(
    BuildContext context, {
    bool manualCheck = false,
  }) async {
    final release = await getLatestRelease();

    if (!context.mounted) return;

    if (release == null) {
      if (manualCheck) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat memeriksa pembaruan. Periksa koneksi internet.')),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFF1E3A8A)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
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
                          color: Color(0xFF1E3A8A),
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
              onPressed: () async {
                final targetUrl = release.apkDownloadUrl ?? release.htmlUrl;
                if (targetUrl != null) {
                  final uri = Uri.parse(targetUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              icon: const Icon(Icons.download, size: 18),
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
