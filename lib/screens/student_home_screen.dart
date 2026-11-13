import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_constants.dart';
import '../core/services/update_checker_service.dart';
import '../core/storage/local_exam_storage.dart';
import '../models/dashboard_summary_model.dart';
import '../models/exam_history_model.dart';
import '../models/exam_model.dart';
import '../models/user_model.dart';
import 'exam_result_detail_screen.dart';
import 'exam_taking_screen.dart';
import 'exam_token_dialog.dart';
import 'login_screen.dart';

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> with SingleTickerProviderStateMixin {
  UserModel? _user;
  ActiveSessionModel? _activeSession;
  List<ExamModel> _availableExams = [];
  List<ExamModel> _upcomingExams = [];
  List<ExamHistoryModel> _examHistory = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Search filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUser();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadUser() {
    final userData = LocalExamStorage.getUserData();
    if (userData != null) {
      setState(() {
        _user = UserModel.fromJson(userData);
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiClient.getStudentDashboard();

      // User data
      if (data['user'] is Map<String, dynamic>) {
        final u = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await LocalExamStorage.setUserData(data['user'] as Map<String, dynamic>);
        _user = u;
      }

      // Active Session
      if (data['active_session'] is Map<String, dynamic>) {
        _activeSession = ActiveSessionModel.fromJson(data['active_session'] as Map<String, dynamic>);
      } else {
        _activeSession = null;
      }

      // Available Exams
      final rawAvailable = (data['available_exams'] as List<dynamic>?) ?? [];
      _availableExams = rawAvailable.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();

      // Upcoming Exams
      final rawUpcoming = (data['upcoming_exams'] as List<dynamic>?) ?? [];
      _upcomingExams = rawUpcoming.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();

      // Exam History
      final rawHistory = (data['exam_history'] as List<dynamic>?) ?? [];
      _examHistory = rawHistory.map((e) => ExamHistoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401) {
        if (mounted) {
          await ApiClient.handleUnauthenticated();
        }
        return;
      }
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleStartExam(ExamModel exam) async {
    try {
      String sessionToken = exam.sessionToken ?? '';

      if (sessionToken.isEmpty) {
        String? token;
        // Masuk ujian pakai token jika diperlukan
        if (exam.requiresToken) {
          final tokenInput = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ExamTokenDialog(examTitle: exam.title),
          );

          if (tokenInput == null || tokenInput.trim().isEmpty) return;
          token = tokenInput.trim();

          _showLoadingOverlay('Memverifikasi token ujian...');
          await ApiClient.enterExam(exam.id, token);
          _hideLoadingOverlay();
        }

        _showLoadingOverlay('Menyiapkan lembar soal...');
        final startRes = await ApiClient.startExam(exam.id, token: token);
        _hideLoadingOverlay();

        sessionToken = (startRes['token'] ?? '').toString();
      }

      if (sessionToken.isNotEmpty && mounted) {
        _navigateToExamTaking(exam, sessionToken);
      }
    } catch (e) {
      _hideLoadingOverlay();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  void _navigateToExamTaking(ExamModel exam, String sessionToken) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamTakingScreen(
          exam: exam,
          sessionToken: sessionToken,
        ),
      ),
    ).then((_) {
      _fetchDashboardData();
    });
  }

  void _showLoadingOverlay(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
                const SizedBox(width: 16),
                Text(message, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Aplikasi?'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ujian siswa ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
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

  void _handleChangeServerIp() {
    final controller = TextEditingController(text: LocalExamStorage.getBaseUrl());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pengaturan IP Server CBT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat lengkap URL server CBT sekolah:',
              style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.100:8000/api/v1',
                prefixIcon: Icon(Icons.dns_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newUrl = controller.text.trim();
              if (newUrl.isNotEmpty) {
                await LocalExamStorage.setBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                _fetchDashboardData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alamat server CBT berhasil disimpan!')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CBT ULANGAN SD',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  _user != null ? '${_user!.name} • ${_user!.studentClass ?? "Siswa"}' : 'Portal Siswa',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF475569), size: 20),
            tooltip: 'Segarkan Ujian',
            onPressed: _fetchDashboardData,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569), size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'server') {
                _handleChangeServerIp();
              } else if (val == 'update') {
                UpdateCheckerService.checkAndShowDialog(context, manualCheck: true);
              } else if (val == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'server',
                child: Row(
                  children: [
                    const Icon(Icons.dns_rounded, size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    Text('IP Server (${LocalExamStorage.getBaseUrl().replaceAll('http://', '').split('/').first})', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'update',
                child: Row(
                  children: [
                    Icon(Icons.system_update_rounded, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 10),
                    Text('Cek Update APK (v${AppConstants.appVersion})', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Text('Keluar Akun', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
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
            Text('Memuat daftar ujian...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                onPressed: _fetchDashboardData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFF64748B)),
                label: const Text('Keluar / Ganti Akun', style: TextStyle(color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
      );
    }

    final allActiveExams = [..._availableExams, ..._upcomingExams];

    // Filter by search query
    List<ExamModel> filteredExams = allActiveExams;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredExams = allActiveExams.where((exam) {
        return exam.title.toLowerCase().contains(q) ||
            (exam.subject?.toLowerCase().contains(q) ?? false) ||
            (exam.teacherName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    List<ExamHistoryModel> filteredHistory = _examHistory;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredHistory = _examHistory.where((h) {
        return h.examTitle.toLowerCase().contains(q) || (h.teacherName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return Column(
      children: [
        // Top Header: Active session banner & tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Active Session Quick Card (if session in progress)
              if (_activeSession != null) ...[
                _buildActiveSessionBanner(),
                const SizedBox(height: 12),
              ],

              // Search bar
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari mata pelajaran atau ujian...',
                    hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const SizedBox(height: 8),

              // Two Core Tabs: List Ujian & Riwayat Nilai
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFFEA580C),
                indicatorWeight: 2.5,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.format_list_bulleted_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Daftar Ujian (${allActiveExams.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.task_alt_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text('Riwayat & Nilai (${_examHistory.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: LIST UJIAN (CORE FLOW)
              RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: filteredExams.isEmpty
                    ? _buildEmptyStateCard(
                        icon: Icons.event_note_rounded,
                        title: 'Tidak Ada Ujian Tersedia',
                        subtitle: 'Semua jadwal ujian untuk kelas Anda akan muncul di sini saat dibuka pengawas.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredExams.length,
                        itemBuilder: (ctx, idx) => _buildExamCard(filteredExams[idx]),
                      ),
              ),

              // TAB 2: RIWAYAT NILAI
              RefreshIndicator(
                onRefresh: _fetchDashboardData,
                child: filteredHistory.isEmpty
                    ? _buildEmptyStateCard(
                        icon: Icons.history_edu_rounded,
                        title: 'Belum Ada Hasil Ujian',
                        subtitle: 'Ujian yang telah Anda kumpulkan akan tercatat di sini beserta rincian nilainya.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: filteredHistory.length,
                        itemBuilder: (ctx, idx) => _buildHistoryCard(filteredHistory[idx]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveSessionBanner() {
    final active = _activeSession!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEA580C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SESI UJIAN BERJALAN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFFB923C), letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  active.examTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final dummyExam = ExamModel(
                id: active.examId,
                title: active.examTitle,
                durationMinutes: active.durationMinutes,
                questionCount: 0,
                status: 'in_progress',
                sessionToken: active.token,
              );
              _navigateToExamTaking(dummyExam, active.token);
            },
            child: const Text('LANJUTKAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(ExamModel exam) {
    final bool isSessionActive = exam.sessionStatus == 'in_progress' || (_activeSession?.examId == exam.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Subject & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  exam.subject ?? 'Ujian Siswa',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ),
              if (isSessionActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: Color(0xFF059669)),
                      SizedBox(width: 5),
                      Text('Sedang Berjalan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    ],
                  ),
                )
              else if (exam.isUpcoming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Text('Akan Datang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Text('Tersedia', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Exam Title
          Text(
            exam.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
          ),
          const SizedBox(height: 4),

          // Teacher
          Text(
            'Guru: ${exam.teacherName ?? "Pengampu"}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),

          // Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildSmallChip(Icons.schedule_rounded, '${exam.durationMinutes} Menit'),
              _buildSmallChip(Icons.calendar_today_rounded, exam.scheduleFormatted),
              if (exam.questionCount > 0)
                _buildSmallChip(Icons.format_list_numbered_rounded, '${exam.questionCount} Soal'),
              if (exam.requiresToken)
                _buildSmallChip(Icons.vpn_key_rounded, 'Perlu Token', isHighlight: true),
            ],
          ),
          const SizedBox(height: 14),

          // Start Exam Button (Core Action)
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSessionActive
                    ? const Color(0xFF059669)
                    : (exam.isUpcoming ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: exam.isUpcoming ? null : () => _handleStartExam(exam),
              icon: Icon(
                isSessionActive
                    ? Icons.play_arrow_rounded
                    : (exam.requiresToken ? Icons.vpn_key_rounded : Icons.login_rounded),
                size: 16,
              ),
              label: Text(
                isSessionActive
                    ? 'LANJUTKAN UJIAN'
                    : (exam.isUpcoming
                        ? 'MENUNGGU WAKTU UJIAN'
                        : (exam.requiresToken ? 'MASUKKAN TOKEN & MULAI' : 'MULAI UJIAN')),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(ExamHistoryModel history) {
    final bool hasScore = history.showResult && history.score != null;
    final bool isPassed = history.passed == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: history.isAutoSubmitted ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: history.isAutoSubmitted ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                  ),
                ),
                child: Text(
                  history.isAutoSubmitted ? 'Terkirim Otomatis' : 'Selesai',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: history.isAutoSubmitted ? const Color(0xFF92400E) : const Color(0xFF065F46),
                  ),
                ),
              ),
              Text(
                history.submittedDateFormatted,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Exam Title
          Text(
            history.examTitle,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
          ),
          const SizedBox(height: 12),

          // Score Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hasScore
                  ? (isPassed ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2))
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: hasScore
                    ? (isPassed ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA))
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasScore ? (isPassed ? 'LULUS (KKM: ${history.passingScore})' : 'BELUM MEMENUHI KKM') : 'NILAI HASIL UJIAN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: hasScore
                            ? (isPassed ? const Color(0xFF065F46) : const Color(0xFF991B1B))
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      history.essayGraded
                          ? 'Semua jawaban dinilai'
                          : (history.essayScore != null ? 'Menunggu koreksi esai' : 'Pilihan Ganda & Esai'),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                Text(
                  hasScore ? '${history.score!.toStringAsFixed(1).replaceAll('.0', '')}%' : '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: hasScore
                        ? (isPassed ? const Color(0xFF047857) : const Color(0xFFDC2626))
                        : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExamResultDetailScreen(
                      examId: history.examId,
                      sessionToken: history.sessionToken,
                      initialExamTitle: history.examTitle,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 15),
              label: const Text('LIHAT RINCIAN NILAI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(IconData icon, String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isHighlight ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isHighlight ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isHighlight ? const Color(0xFFB45309) : const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isHighlight ? const Color(0xFF92400E) : const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Icon(icon, size: 32, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
