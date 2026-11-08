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
  final int initialTab;

  const StudentHomeScreen({super.key, this.initialTab = 0});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  UserModel? _user;
  DashboardSummaryModel? _summary;
  ActiveSessionModel? _activeSession;
  List<ExamModel> _availableExams = [];
  List<ExamModel> _upcomingExams = [];
  List<ExamHistoryModel> _examHistory = [];

  bool _isLoading = true;
  String? _errorMessage;

  // Exams tab search & filter
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, available, upcoming, completed
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _loadUser();
    _fetchDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

      // Parse User Data if available
      if (data['user'] is Map<String, dynamic>) {
        final u = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        await LocalExamStorage.setUserData(data['user'] as Map<String, dynamic>);
        _user = u;
      }

      // Parse Summary
      if (data['summary'] is Map<String, dynamic>) {
        _summary = DashboardSummaryModel.fromJson(data['summary'] as Map<String, dynamic>);
      }

      // Parse Active Session
      if (data['active_session'] is Map<String, dynamic>) {
        _activeSession = ActiveSessionModel.fromJson(data['active_session'] as Map<String, dynamic>);
      } else {
        _activeSession = null;
      }

      // Parse Available Exams
      final rawAvailable = (data['available_exams'] as List<dynamic>?) ?? [];
      _availableExams = rawAvailable.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();

      // Parse Upcoming Exams
      final rawUpcoming = (data['upcoming_exams'] as List<dynamic>?) ?? [];
      _upcomingExams = rawUpcoming.map((e) => ExamModel.fromJson(e as Map<String, dynamic>)).toList();

      // Parse Exam History
      final rawHistory = (data['exam_history'] as List<dynamic>?) ?? [];
      _examHistory = rawHistory.map((e) => ExamHistoryModel.fromJson(e as Map<String, dynamic>)).toList();

      // Fallback summary if not provided by backend
      _summary ??= DashboardSummaryModel(
        totalAssigned: _availableExams.length + _upcomingExams.length + _examHistory.length,
        availableCount: _availableExams.length,
        upcomingCount: _upcomingExams.length,
        completedCount: _examHistory.length,
      );
    } catch (e) {
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
        if (exam.requiresToken) {
          final token = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => ExamTokenDialog(examTitle: exam.title),
          );

          if (token == null) return;

          _showLoadingOverlay('Memverifikasi token ujian...');
          await ApiClient.enterExam(exam.id, token);
          _hideLoadingOverlay();
        }

        _showLoadingOverlay('Menyiapkan lembar soal...');
        final startRes = await ApiClient.startExam(exam.id);
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
            tooltip: 'Segarkan Data',
            onPressed: _fetchDashboardData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildCurrentTab(),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: const Color(0xFFF1F5F9),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, size: 20),
              selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFFEA580C), size: 20),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined, size: 20),
              selectedIcon: Icon(Icons.assignment_rounded, color: Color(0xFFEA580C), size: 20),
              label: 'Ujian',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined, size: 20),
              selectedIcon: Icon(Icons.analytics_rounded, color: Color(0xFFEA580C), size: 20),
              label: 'Riwayat & Nilai',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, size: 20),
              selectedIcon: Icon(Icons.person_rounded, color: Color(0xFFEA580C), size: 20),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
            SizedBox(height: 14),
            Text('Sinkronisasi data siswa...', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
            ],
          ),
        ),
      );
    }

    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildExamsTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildProfileTab();
      default:
        return _buildDashboardTab();
    }
  }

  // -------------------------------------------------------------
  // TAB 1: BERANDA / DASHBOARD
  // -------------------------------------------------------------
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Student Profile Slate Hero Card
          _buildStudentHero(),
          const SizedBox(height: 16),

          // 3 Architectural Summary Cards (1-to-1 match with Web Dashboard)
          _buildSummaryCardsRow(),
          const SizedBox(height: 16),

          // Active Exam Banner (if active session exists)
          if (_activeSession != null) ...[
            _buildActiveSessionCard(),
            const SizedBox(height: 16),
          ],

          // Ujian Tersedia Sekarang
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ujian Tersedia Sekarang',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 1),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_availableExams.isEmpty)
            _buildEmptyStateCard(
              icon: Icons.event_available_rounded,
              title: 'Tidak Ada Ujian Aktif Saat Ini',
              subtitle: 'Semua jadwal ujian untuk kelas Anda akan muncul di sini saat dibuka oleh guru.',
            )
          else
            ..._availableExams.take(3).map((exam) => _buildExamCard(exam)),

          const SizedBox(height: 16),

          // Riwayat Ujian Terkini
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hasil & Nilai Terkini',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 2),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_examHistory.isEmpty)
            _buildEmptyStateCard(
              icon: Icons.history_rounded,
              title: 'Belum Ada Riwayat Ujian',
              subtitle: 'Nilai dan hasil ujian yang telah Anda selesaikan akan otomatis tercatat di sini.',
            )
          else
            ..._examHistory.take(3).map((history) => _buildHistoryCard(history)),
        ],
      ),
    );
  }

  Widget _buildStudentHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF1E293B),
            child: Text(
              _user?.name.isNotEmpty == true ? _user!.name.substring(0, 1).toUpperCase() : 'S',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.name ?? 'Siswa CBT',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        'NISN: ${_user?.studentNumber ?? "-"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Text(
                        'Kelas: ${_user?.studentClass ?? "-"}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE2E8F0), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCardsRow() {
    final summary = _summary ?? DashboardSummaryModel(totalAssigned: 0, availableCount: 0, upcomingCount: 0, completedCount: 0);

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Terdaftar',
            count: summary.totalAssigned,
            color: const Color(0xFF0F172A),
            icon: Icons.list_alt_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Tersedia',
            count: summary.availableCount,
            color: const Color(0xFFEA580C),
            icon: Icons.play_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildSummaryCard(
            title: 'Selesai',
            count: summary.completedCount,
            color: const Color(0xFF059669),
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
              Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSessionCard() {
    final active = _activeSession!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEA580C), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.white),
                    SizedBox(width: 5),
                    Text(
                      'SESI SEDANG BERLANGSUNG',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${active.durationMinutes} Menit',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            active.examTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text(
            'Anda memiliki sesi ujian yang belum diselesaikan. Lanjutkan segera sebelum waktu habis.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('LANJUTKAN UJIAN SEKARANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: DAFTAR UJIAN (SEARCH & FILTER TABS)
  // -------------------------------------------------------------
  Widget _buildExamsTab() {
    final allExams = [..._availableExams, ..._upcomingExams];

    // Apply Filter
    List<ExamModel> filtered = allExams.where((exam) {
      if (_selectedFilter == 'available') return exam.isActive;
      if (_selectedFilter == 'upcoming') return exam.isUpcoming;
      return true;
    }).toList();

    // Apply Search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((exam) {
        return exam.title.toLowerCase().contains(q) ||
            (exam.subject?.toLowerCase().contains(q) ?? false) ||
            (exam.teacherName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari mata pelajaran, judul ujian, atau guru...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips (Semua, Tersedia, Akan Datang, Selesai)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua Ujian', 'all', allExams.length),
                const SizedBox(width: 8),
                _buildFilterChip('Tersedia', 'available', _availableExams.length),
                const SizedBox(width: 8),
                _buildFilterChip('Akan Datang', 'upcoming', _upcomingExams.length),
                const SizedBox(width: 8),
                _buildFilterChip('Selesai', 'completed', _examHistory.length),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render list
          if (_selectedFilter == 'completed') ...[
            if (_examHistory.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.task_alt_rounded,
                title: 'Belum Ada Ujian Selesai',
                subtitle: 'Riwayat ujian yang Anda selesaikan akan tercatat di tab ini.',
              )
            else
              ..._examHistory.map((history) => _buildHistoryCard(history)),
          ] else ...[
            if (filtered.isEmpty)
              _buildEmptyStateCard(
                icon: Icons.search_off_rounded,
                title: 'Tidak Ada Ujian Ditemukan',
                subtitle: 'Coba ubah kata kunci pencarian atau ganti filter kategori.',
              )
            else
              ...filtered.map((exam) => _buildExamCard(exam)),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, int count) {
    final isSelected = _selectedFilter == key;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedFilter = key;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: RIWAYAT & NILAI (1-TO-1 MATCH WITH WEB)
  // -------------------------------------------------------------
  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_rounded, size: 22, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Nilai & Hasil Ujian',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total ${_examHistory.length} ujian telah Anda selesaikan',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_examHistory.isEmpty)
            _buildEmptyStateCard(
              icon: Icons.history_edu_rounded,
              title: 'Belum Ada Hasil Ujian',
              subtitle: 'Nilai ujian pilihan ganda dan koreksi esai akan muncul di sini setelah Anda selesai mengerjakan ujian.',
            )
          else
            ..._examHistory.map((history) => _buildHistoryCard(history)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 4: PROFIL & PENGATURAN SISWA
  // -------------------------------------------------------------
  Widget _buildProfileTab() {
    final currentServer = LocalExamStorage.getBaseUrl();

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Profile Info Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF0F172A),
                child: Text(
                  _user?.name.isNotEmpty == true ? _user!.name.substring(0, 1).toUpperCase() : 'S',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _user?.name ?? 'Nama Siswa',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                _user?.email ?? 'akun.siswa@cbt.sch.id',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildProfileStat('KELAS', _user?.studentClass ?? '-'),
                  Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                  _buildProfileStat('NISN', _user?.studentNumber ?? '-'),
                  Container(height: 24, width: 1, color: const Color(0xFFE2E8F0)),
                  _buildProfileStat('PERAN', 'Siswa'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Server Connection Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.dns_rounded, size: 18, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text('Koneksi Server CBT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  currentServer,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _handleChangeServerIp,
                  icon: const Icon(Icons.settings_ethernet_rounded, size: 16),
                  label: const Text('Ubah Alamat IP Server', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // App Version & Update Check
        Container(
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
                  const Text('Versi Aplikasi CBT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text('v${AppConstants.appVersion}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    UpdateCheckerService.checkAndShowDialog(context, manualCheck: true);
                  },
                  icon: const Icon(Icons.system_update_rounded, size: 16),
                  label: const Text('Periksa Pembaruan APK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Logout Button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 17),
            label: const Text('KELUAR DARI APLIKASI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
      ],
    );
  }

  // -------------------------------------------------------------
  // REUSABLE CARDS: EXAM & HISTORY
  // -------------------------------------------------------------
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

          // Title
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
                _buildSmallChip(Icons.key_rounded, 'Perlu Token', isHighlight: true),
            ],
          ),
          const SizedBox(height: 14),

          // Action Button
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
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
