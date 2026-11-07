import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/storage/local_exam_storage.dart';
import '../models/exam_model.dart';
import '../models/user_model.dart';
import 'exam_token_dialog.dart';
import 'exam_taking_screen.dart';
import 'login_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  UserModel? _user;
  List<ExamModel> _exams = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchExams();
  }

  void _loadUser() {
    final userData = LocalExamStorage.getUserData();
    if (userData != null) {
      _user = UserModel.fromJson(userData);
    }
  }

  Future<void> _fetchExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawList = await ApiClient.getStudentExams();
      final parsed = rawList.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _exams = parsed;
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

  Future<void> _handleStartExam(ExamModel exam) async {
    try {
      // 1. If exam has no active session, ask for token
      if (exam.sessionToken == null || exam.sessionToken!.isEmpty) {
        final token = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ExamTokenDialog(examTitle: exam.title),
        );

        if (token == null) return; // User cancelled

        // Enter exam token
        _showLoadingOverlay();
        await ApiClient.enterExam(exam.id, token);

        // Start session
        final startRes = await ApiClient.startExam(exam.id);
        _hideLoadingOverlay();

        final sessionToken = startRes['token'] as String;
        _navigateToExamTaking(exam, sessionToken);
      } else {
        // Resume active session
        _navigateToExamTaking(exam, exam.sessionToken!);
      }
    } catch (e) {
      _hideLoadingOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  void _navigateToExamTaking(ExamModel exam, String sessionToken) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakingScreen(
          exam: exam,
          sessionToken: sessionToken,
        ),
      ),
    ).then((_) {
      // Refresh exam list when returning
      _fetchExams();
    });
  }

  void _showLoadingOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  void _hideLoadingOverlay() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Aplikasi?'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiClient.logout();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: AppBar(
        title: const Text('Daftar Ujian', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _fetchExams,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExams,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Student Profile Banner
            if (_user != null) ...[
              Card(
                elevation: 0,
                color: const Color(0xFFEFF6FF), // Blue 50
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF1E3A8A),
                        child: Icon(Icons.person, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user!.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIS: ${_user!.studentNumber ?? "-"} | Kelas: ${_user!.studentClass ?? "-"}',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Jadwal Ujian Tersedia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),

            // Loading / Error / List
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchExams,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_exams.isEmpty) ...[
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 56, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak ada jadwal ujian aktif saat ini.',
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              ..._exams.map((exam) => _buildExamCard(exam)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    final bool isSessionActive = exam.sessionStatus == 'in_progress';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    exam.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (exam.subject != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      exam.subject!,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text('${exam.durationMinutes} Menit', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(width: 16),
                const Icon(Icons.help_outline, size: 16, color: Colors.black54),
                const SizedBox(width: 4),
                Text('${exam.questionCount} Soal', style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSessionActive ? const Color(0xFF059669) : const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _handleStartExam(exam),
                icon: Icon(isSessionActive ? Icons.play_arrow : Icons.login),
                label: Text(
                  isSessionActive ? 'LANJUTKAN UJIAN' : 'MULAI UJIAN',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
