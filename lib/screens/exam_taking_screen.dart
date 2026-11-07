import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/security/cbt_security.dart';
import '../core/storage/local_exam_storage.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';
import 'exam_result_screen.dart';

class ExamTakingScreen extends StatefulWidget {
  final ExamModel exam;
  final String sessionToken;

  const ExamTakingScreen({
    super.key,
    required this.exam,
    required this.sessionToken,
  });

  @override
  State<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends State<ExamTakingScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _errorMessage;

  List<QuestionModel> _questions = [];
  int _currentIndex = 0;

  // Timer state
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _syncTimer;

  // Violations
  int _violationCount = 0;

  // Essay controller
  final TextEditingController _essayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Activate Anti-Cheat Lock & Anti-Screenshot
    CbtSecurity.enableAntiScreenshot();
    CbtSecurity.startKioskLock();

    // 2. Load questions
    _loadExamQuestions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _syncTimer?.cancel();
    _essayController.dispose();

    // Release security on exit
    CbtSecurity.stopKioskLock();
    CbtSecurity.disableAntiScreenshot();
    super.dispose();
  }

  // Anti-Cheat Detection: App minimized or switched away
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _handleViolation('LEAVE_APP');
    }
  }

  Future<void> _handleViolation(String type) async {
    _violationCount++;
    try {
      final res = await ApiClient.reportViolation(
        sessionToken: widget.sessionToken,
        violationType: type,
        metadata: {'timestamp': DateTime.now().toIso8601String()},
      );

      if (res != null && res['auto_submitted'] == true) {
        // Exam was terminated by server due to violation threshold
        _showTerminatedDialog('Ujian dihentikan otomatis karena terdeteksi pelanggaran berulang.');
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade900,
          duration: const Duration(seconds: 4),
          content: Text(
            'PERINGATAN! Anda terdeteksi keluar dari aplikasi ujian ($_violationCount kali). '
            'Tindakan ini dicatat oleh pengawas!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Future<void> _loadExamQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient.loadExamTaking(widget.sessionToken);

      final sessionData = res['session'] as Map<String, dynamic>?;
      final rawQuestions = res['questions'] as List<dynamic>? ?? [];

      _remainingSeconds = sessionData?['remaining_seconds'] ?? (widget.exam.durationMinutes * 60);

      final parsed = rawQuestions.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>)).toList();

      // Merge local saved answers if available (offline-first safeguard)
      final localAnswers = LocalExamStorage.getAnswers(widget.sessionToken);
      for (var q in parsed) {
        if (localAnswers.containsKey(q.id.toString())) {
          final localData = localAnswers[q.id.toString()];
          if (q.selectedOptionId == null && localData['selected_option_id'] != null) {
            q.selectedOptionId = localData['selected_option_id'];
          }
          if ((q.essayAnswer == null || q.essayAnswer!.isEmpty) && localData['essay_answer'] != null) {
            q.essayAnswer = localData['essay_answer'];
          }
        }
      }

      setState(() {
        _questions = parsed;
        _isLoading = false;
      });

      _initQuestionAnswer();
      _startTimers();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _autoSubmitTimeUp();
      }
    });

    // Sync remaining time with server every 2 minutes
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      final serverSeconds = await ApiClient.getTimeRemaining(widget.sessionToken);
      if (serverSeconds != null && mounted) {
        setState(() {
          _remainingSeconds = serverSeconds;
        });
      }
    });
  }

  void _initQuestionAnswer() {
    if (_questions.isEmpty) return;
    final currentQ = _questions[_currentIndex];
    if (currentQ.type == 'essay') {
      _essayController.text = currentQ.essayAnswer ?? '';
    }
  }

  void _selectOption(dynamic optionId) {
    final currentQ = _questions[_currentIndex];
    setState(() {
      currentQ.selectedOptionId = optionId;
    });

    // 1. Save locally (instant)
    LocalExamStorage.saveAnswerLocally(
      sessionToken: widget.sessionToken,
      questionId: currentQ.id.toString(),
      selectedOptionId: optionId?.toString(),
    );

    // 2. Sync to server in background
    ApiClient.saveAnswer(
      sessionToken: widget.sessionToken,
      questionId: currentQ.id,
      selectedOptionId: optionId,
    );
  }

  void _saveEssayAnswer(String text) {
    final currentQ = _questions[_currentIndex];
    currentQ.essayAnswer = text;

    LocalExamStorage.saveAnswerLocally(
      sessionToken: widget.sessionToken,
      questionId: currentQ.id.toString(),
      essayAnswer: text,
    );

    ApiClient.saveAnswer(
      sessionToken: widget.sessionToken,
      questionId: currentQ.id,
      essayAnswer: text,
    );
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      // Save current essay if on essay
      if (_questions[_currentIndex].type == 'essay') {
        _saveEssayAnswer(_essayController.text);
      }

      setState(() {
        _currentIndex = index;
      });
      _initQuestionAnswer();
    }
  }

  Future<void> _autoSubmitTimeUp() async {
    _countdownTimer?.cancel();
    _showLoadingModal('Waktu ujian telah habis. Mengumpulkan jawaban otomatis...');
    try {
      await ApiClient.submitExam(widget.sessionToken);
      await LocalExamStorage.clearSessionAnswers(widget.sessionToken);
      _closeExamAndNavigateResult();
    } catch (_) {
      _closeExamAndNavigateResult();
    }
  }

  void _showTerminatedDialog(String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Ujian Dihentikan', style: TextStyle(color: Colors.red)),
        content: Text(reason),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    // Save current essay before check
    if (_questions.isNotEmpty && _questions[_currentIndex].type == 'essay') {
      _saveEssayAnswer(_essayController.text);
    }

    final answeredCount = _questions.where((q) => q.isAnswered).length;
    final totalCount = _questions.length;
    final unAnsweredCount = totalCount - answeredCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Kumpulkan Ujian?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dijawab: $answeredCount dari $totalCount soal'),
            if (unAnsweredCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Perhatian: Masih ada $unAnsweredCount soal yang belum dijawab!',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            const Text('Setelah dikumpulkan, Anda tidak dapat mengubah jawaban lagi.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Periksa Lagi'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669), // Green 600
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kumpulkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoadingModal('Mengumpulkan jawaban...');
      try {
        await ApiClient.submitExam(widget.sessionToken);
        await LocalExamStorage.clearSessionAnswers(widget.sessionToken);
        _closeExamAndNavigateResult();
      } catch (e) {
        if (!mounted) return;
        if (Navigator.canPop(context)) Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text(e.toString())),
        );
      }
    }
  }

  void _closeExamAndNavigateResult() {
    CbtSecurity.stopKioskLock();
    CbtSecurity.disableAntiScreenshot();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ExamResultScreen(examTitle: widget.exam.title)),
    );
  }

  void _showLoadingModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showQuestionGridModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daftar Nomor Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                    ),
                    itemCount: _questions.length,
                    itemBuilder: (_, idx) {
                      final q = _questions[idx];
                      final isCurrent = idx == _currentIndex;
                      final isAnswered = q.isAnswered;

                      Color bg = Colors.white;
                      Color border = Colors.grey.shade400;
                      Color text = Colors.black87;

                      if (isAnswered) {
                        bg = const Color(0xFF10B981); // Emerald
                        border = const Color(0xFF059669);
                        text = Colors.white;
                      }
                      if (isCurrent) {
                        border = const Color(0xFF1E3A8A);
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToQuestion(idx);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border, width: isCurrent ? 2.5 : 1),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: text),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimer(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    // Intercept back button to prevent accidental leave
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tombol kembali dinonaktifkan demi keamanan ujian.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            widget.exam.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          actions: [
            // Timer Badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300 ? Colors.red.shade700 : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alarm, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
            // Question Grid Button
            IconButton(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Daftar Nomor Soal',
              onPressed: _questions.isEmpty ? null : _showQuestionGridModal,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadExamQuestions, child: const Text('Coba Lagi')),
                        ],
                      ),
                    ),
                  )
                : _buildQuestionContent(),
        bottomNavigationBar: (_isLoading || _questions.isEmpty)
            ? null
            : _buildBottomNav(),
      ),
    );
  }

  Widget _buildQuestionContent() {
    final currentQ = _questions[_currentIndex];

    return Column(
      children: [
        // Top status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soal ${_currentIndex + 1} dari ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: currentQ.isAnswered ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  currentQ.isAnswered ? 'Terjawab' : 'Belum Dijawab',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: currentQ.isAnswered ? const Color(0xFF065F46) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Main Question Scroll
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Text Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      currentQ.questionText,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Options (Multiple Choice) or Text Input (Essay)
                if (currentQ.type == 'essay') ...[
                  const Text('Jawaban Essay Anda:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _essayController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Ketik jawaban di sini...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) {
                      _saveEssayAnswer(val);
                    },
                  ),
                ] else ...[
                  ...currentQ.options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final option = entry.value;
                    final optionLetter = String.fromCharCode(65 + idx); // A, B, C, D
                    final isSelected = currentQ.selectedOptionId?.toString() == option.id.toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _selectOption(option.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                child: Text(
                                  optionLetter,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  option.optionText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    final isFirst = _currentIndex == 0;
    final isLast = _currentIndex == _questions.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64748B),
                foregroundColor: Colors.white,
              ),
              onPressed: isFirst ? null : () => _goToQuestion(_currentIndex - 1),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Sebelumnya'),
            ),

            // Next or Submit
            if (isLast)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669), // Green
                  foregroundColor: Colors.white,
                ),
                onPressed: _confirmSubmit,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Kumpulkan'),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _goToQuestion(_currentIndex + 1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Selanjutnya'),
              ),
          ],
        ),
      ),
    );
  }
}
