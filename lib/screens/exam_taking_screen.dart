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
        _showTerminatedDialog('Ujian dihentikan otomatis karena terdeteksi pelanggaran berulang.');
        return;
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Peringatan Keamanan ($_violationCount): Dilarang keluar dari layar ujian!'),
          duration: const Duration(seconds: 3),
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

      // Pulihkan jawaban yang tersimpan di memori offline jika ada
      final localAnswers = LocalExamStorage.getAnswers(widget.sessionToken);
      for (final q in parsed) {
        if (localAnswers.containsKey(q.id.toString())) {
          final localData = localAnswers[q.id.toString()];
          if (q.selectedOptionId == null && localData['selected_option_id'] != null) {
            q.selectedOptionId = localData['selected_option_id'];
          }
          if (q.essayAnswer == null && localData['essay_answer'] != null) {
            q.essayAnswer = localData['essay_answer'];
          }
        }
      }

      _questions = parsed;
      _startTimer();
      _initQuestionAnswer();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _autoSubmitTimeUp();
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

    // Simpan instan ke penyimpanan lokal
    LocalExamStorage.saveAnswerLocally(
      sessionToken: widget.sessionToken,
      questionId: currentQ.id.toString(),
      selectedOptionId: optionId?.toString(),
    );

    // Kirim asinkron ke server
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
    _showLoadingModal('Waktu ujian telah habis. Mengumpulkan lembar jawaban otomatis...');
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ujian Dihentikan', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
        content: Text(reason),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    if (_questions.isNotEmpty && _questions[_currentIndex].type == 'essay') {
      _saveEssayAnswer(_essayController.text);
    }

    final answeredCount = _questions.where((q) => q.isAnswered).length;
    final totalCount = _questions.length;
    final unAnsweredCount = totalCount - answeredCount;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF059669), size: 22),
            SizedBox(width: 8),
            Text('Kumpulkan Ujian?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('$answeredCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                      const Text('Dijawab', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                  Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                  Column(
                    children: [
                      Text('$unAnsweredCount', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: unAnsweredCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF64748B))),
                      const Text('Belum Dijawab', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
            if (unAnsweredCount > 0) ...[
              const SizedBox(height: 12),
              Text(
                'Perhatian: Masih ada $unAnsweredCount soal yang belum dijawab!',
                style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'Setelah dikumpulkan, jawaban akan disimpan permanen dan tidak dapat diubah.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Periksa Lagi'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Kumpulkan'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _showLoadingModal('Mengumpulkan lembar jawaban...');
      try {
        await ApiClient.submitExam(widget.sessionToken);
        await LocalExamStorage.clearSessionAnswers(widget.sessionToken);
        _closeExamAndNavigateResult();
      } catch (e) {
        _closeExamAndNavigateResult();
      }
    }
  }

  void _closeExamAndNavigateResult() {
    _countdownTimer?.cancel();
    _syncTimer?.cancel();

    if (Navigator.canPop(context)) {
      Navigator.pop(context); // Close loading modal
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExamResultScreen(examTitle: widget.exam.title),
      ),
    );
  }

  void _showLoadingModal(String text) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }

  void _showQuestionGridModal() {
    final answeredCount = _questions.where((q) => q.isAnswered).length;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daftar Nomor Soal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text('$answeredCount dari ${_questions.length} soal terjawab', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: _questions.length,
                    itemBuilder: (_, idx) {
                      final q = _questions[idx];
                      final isCurrent = idx == _currentIndex;
                      final isAnswered = q.isAnswered;

                      Color bg = Colors.white;
                      Color border = const Color(0xFFCBD5E1);
                      Color text = const Color(0xFF0F172A);

                      if (isAnswered) {
                        bg = const Color(0xFF059669);
                        border = const Color(0xFF047857);
                        text = Colors.white;
                      }
                      if (isCurrent) {
                        border = const Color(0xFF0F172A);
                      }

                      return InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          _goToQuestion(idx);
                        },
                        borderRadius: BorderRadius.circular(8),
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
    final answeredCount = _questions.where((q) => q.isAnswered).length;
    final progress = _questions.isNotEmpty ? (answeredCount / _questions.length) : 0.0;
    final isCriticalTimer = _remainingSeconds < 300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tombol kembali dinonaktifkan demi integritas ujian.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.exam.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          actions: [
            // Timer Pill Badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCriticalTimer ? const Color(0xFFFEE2E2) : const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCriticalTimer ? const Color(0xFFFCA5A5) : const Color(0xFF1E293B),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.alarm_rounded,
                    size: 15,
                    color: isCriticalTimer ? const Color(0xFFDC2626) : Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _formatTimer(_remainingSeconds),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: isCriticalTimer ? const Color(0xFFDC2626) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Grid icon button
            IconButton(
              icon: const Icon(Icons.grid_view_rounded, color: Color(0xFF0F172A), size: 20),
              tooltip: 'Daftar Soal',
              onPressed: _questions.isEmpty ? null : _showQuestionGridModal,
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              color: const Color(0xFF0F172A),
              minHeight: 3,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0F172A)))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
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
        // Sub-header status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Soal Nomor ${_currentIndex + 1} dari ${_questions.length}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: currentQ.isAnswered ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: currentQ.isAnswered ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 3,
                      backgroundColor: currentQ.isAnswered ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      currentQ.isAnswered ? 'Jawaban Tersimpan ✓' : 'Belum Dijawab',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: currentQ.isAnswered ? const Color(0xFF065F46) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Question scroll body
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: Text(
                      currentQ.questionText,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Options (Multiple Choice or Essay)
                if (currentQ.type == 'essay') ...[
                  const Text('Tulis Jawaban Uraian / Esai:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _essayController,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: 'Tuliskan jawaban lengkap Anda di sini...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  optionLetter,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  option.optionText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: const Color(0xFF0F172A),
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Dipilih',
                                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF0F172A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isFirst ? null : () => _goToQuestion(_currentIndex - 1),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Sebelumnya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),

            // Question Grid Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _showQuestionGridModal,
              icon: const Icon(Icons.grid_view_rounded, size: 16),
              label: Text('${_currentIndex + 1}/${_questions.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),

            // Next or Submit
            if (isLast)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _confirmSubmit,
                icon: const Icon(Icons.check_circle_rounded, size: 17),
                label: const Text('Kumpulkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _goToQuestion(_currentIndex + 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Selanjutnya', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
