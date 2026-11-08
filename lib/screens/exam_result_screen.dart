import 'package:flutter/material.dart';
import 'exam_result_detail_screen.dart';

class ExamResultScreen extends StatelessWidget {
  final String examTitle;
  final dynamic examId;
  final String? sessionToken;

  const ExamResultScreen({
    super.key,
    required this.examTitle,
    this.examId,
    this.sessionToken,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          title: const Text(
            'Hasil Penyerahan Ujian',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Celebratory Success Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 48,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Main Title
                    const Text(
                      'Ujian Berhasil Dikumpulkan!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Exam Title Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        examTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    const Text(
                      'Seluruh lembar jawaban Anda telah tersimpan dan terverifikasi secara aman di server CBT sekolah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 26),

                    // View Result Detail Button
                    if (sessionToken != null || examId != null) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEA580C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ExamResultDetailScreen(
                                  examId: examId,
                                  sessionToken: sessionToken,
                                  initialExamTitle: examTitle,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics_rounded, size: 17),
                          label: const Text(
                            'LIHAT RINCIAN HASIL & NILAI',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Return Button
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back_rounded, size: 17),
                        label: const Text(
                          'KEMBALI KE BERANDA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
