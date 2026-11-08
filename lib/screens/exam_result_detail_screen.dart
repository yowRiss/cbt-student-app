import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../models/exam_result_detail_model.dart';

class ExamResultDetailScreen extends StatefulWidget {
  final dynamic examId;
  final String? sessionToken;
  final String? initialExamTitle;

  const ExamResultDetailScreen({
    super.key,
    this.examId,
    this.sessionToken,
    this.initialExamTitle,
  });

  @override
  State<ExamResultDetailScreen> createState() => _ExamResultDetailScreenState();
}

class _ExamResultDetailScreenState extends State<ExamResultDetailScreen> {
  ExamResultDetailModel? _result;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic> raw;
      if (widget.sessionToken != null && widget.sessionToken!.isNotEmpty) {
        raw = await ApiClient.getSessionResult(widget.sessionToken!);
      } else if (widget.examId != null) {
        raw = await ApiClient.getExamResult(widget.examId);
      } else {
        throw ApiException('Parameter ujian atau sesi tidak valid.');
      }

      setState(() {
        _result = ExamResultDetailModel.fromJson(raw);
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        title: Text(
          widget.initialExamTitle ?? _result?.examTitle ?? 'Rincian Hasil Ujian',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
            SizedBox(height: 14),
            Text('Memuat rincian hasil...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nilai Belum Dapat Ditampilkan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: _fetchResult,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final res = _result!;
    final bool hasScore = res.showResult && res.percentage != null;
    final bool isPassed = res.isPassed;

    return RefreshIndicator(
      onRefresh: _fetchResult,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: res.isAutoSubmitted ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: res.isAutoSubmitted ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                        ),
                      ),
                      child: Text(
                        res.isAutoSubmitted ? 'Terkirim Otomatis' : 'Selesai Terverifikasi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: res.isAutoSubmitted ? const Color(0xFF92400E) : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                    if (res.submittedAt != null)
                      Text(
                        '${res.submittedAt!.day}/${res.submittedAt!.month}/${res.submittedAt!.year}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  res.examTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ujian telah selesai dikerjakan dan tersimpan di sistem.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Score Hero Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: hasScore
                  ? (isPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2))
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: hasScore
                    ? (isPassed ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA))
                    : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Text(
                  res.pendingManualGrading ? 'NILAI SEMENTARA' : 'SKOR NILAI AKHIR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: hasScore
                        ? (isPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B))
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      hasScore ? res.percentage!.toStringAsFixed(1).replaceAll('.0', '') : '?',
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        color: hasScore
                            ? (isPassed ? const Color(0xFF047857) : const Color(0xFFDC2626))
                            : const Color(0xFF0F172A),
                        letterSpacing: -1,
                      ),
                    ),
                    if (hasScore)
                      Text(
                        ' / 100',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isPassed ? const Color(0xFF059669) : const Color(0xFFEF4444),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: hasScore
                        ? (isPassed ? const Color(0xFF059669) : const Color(0xFFDC2626))
                        : const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    hasScore
                        ? (isPassed ? 'LULUS (MEMENUHI KKM)' : 'BELUM MEMENUHI KKM')
                        : 'NILAI DISEMBUNYIKAN GURU',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (res.pendingManualGrading) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '* Nilai akhir masih menunggu penilaian koreksi soal esai dari guru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Score Breakdown Grid
          const Text(
            'Rincian Komponen Penilaian',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.checklist_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Pilihan Ganda',
                  value: res.multipleChoiceScore != null
                      ? res.multipleChoiceScore!.toStringAsFixed(1).replaceAll('.0', '')
                      : (res.showResult ? '-' : '?'),
                  subtitle: res.multipleChoiceMax != null ? 'Maks: ${res.multipleChoiceMax}' : 'Skor PG',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.edit_note_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: 'Soal Esai',
                  value: res.essayScore != null
                      ? res.essayScore!.toStringAsFixed(1).replaceAll('.0', '')
                      : (res.essayGraded ? '0' : 'Menunggu'),
                  subtitle: res.essayGraded ? 'Sudah dinilai' : 'Belum dikoreksi',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.security_rounded,
                  iconColor: res.violationCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  title: 'Pelanggaran',
                  value: '${res.violationCount}',
                  subtitle: res.violationCount == 0 ? 'Sesi Bersih' : 'Terdeteksi keluar app',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFF475569),
                  title: 'Waktu Selesai',
                  value: res.submittedAt != null
                      ? '${res.submittedAt!.hour.toString().padLeft(2, '0')}:${res.submittedAt!.minute.toString().padLeft(2, '0')}'
                      : '-',
                  subtitle: 'Waktu Pengumpulan',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Return Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('KEMBALI KE BERANDA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
