class ExamResultDetailModel {
  final String sessionToken;
  final dynamic examId;
  final String examTitle;
  final String status;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final bool isAutoSubmitted;
  final String? autoSubmitReason;
  final double? percentage;
  final double? totalScore;
  final double? maxScore;
  final double? multipleChoiceScore;
  final double? multipleChoiceMax;
  final double? essayScore;
  final double? essayMax;
  final bool essayGraded;
  final String essayStatus;
  final bool pendingManualGrading;
  final String passFail;
  final bool showResult;
  final int violationCount;

  ExamResultDetailModel({
    required this.sessionToken,
    required this.examId,
    required this.examTitle,
    required this.status,
    this.startedAt,
    this.submittedAt,
    this.isAutoSubmitted = false,
    this.autoSubmitReason,
    this.percentage,
    this.totalScore,
    this.maxScore,
    this.multipleChoiceScore,
    this.multipleChoiceMax,
    this.essayScore,
    this.essayMax,
    this.essayGraded = true,
    this.essayStatus = 'graded',
    this.pendingManualGrading = false,
    this.passFail = 'passed',
    this.showResult = true,
    this.violationCount = 0,
  });

  factory ExamResultDetailModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final session = json['session'] is Map<String, dynamic> ? json['session'] as Map<String, dynamic> : json;
    final exam = json['exam'] is Map<String, dynamic> ? json['exam'] as Map<String, dynamic> : {};
    final score = json['score'] is Map<String, dynamic> ? json['score'] as Map<String, dynamic> : {};
    final reviewRules = json['review_rules'] is Map<String, dynamic> ? json['review_rules'] as Map<String, dynamic> : {};

    final showRes = reviewRules['show_result_after_submission'] != false && json['show_result'] != false;

    return ExamResultDetailModel(
      sessionToken: (session['token'] ?? '').toString(),
      examId: exam['id'] ?? session['exam_id'],
      examTitle: (exam['title'] ?? session['exam_title'] ?? 'Hasil Ujian').toString(),
      status: (session['status'] ?? 'submitted').toString(),
      startedAt: parseDate(session['started_at']),
      submittedAt: parseDate(session['submitted_at']),
      isAutoSubmitted: session['is_auto_submitted'] == true,
      autoSubmitReason: session['auto_submit_reason']?.toString(),
      percentage: showRes && score['percentage'] != null ? double.tryParse(score['percentage'].toString()) : null,
      totalScore: showRes && score['total'] != null ? double.tryParse(score['total'].toString()) : null,
      maxScore: showRes && score['max'] != null ? double.tryParse(score['max'].toString()) : null,
      multipleChoiceScore: showRes && score['multiple_choice_score'] != null ? double.tryParse(score['multiple_choice_score'].toString()) : null,
      multipleChoiceMax: showRes && score['multiple_choice_max'] != null ? double.tryParse(score['multiple_choice_max'].toString()) : null,
      essayScore: showRes && score['essay_score'] != null ? double.tryParse(score['essay_score'].toString()) : null,
      essayMax: showRes && score['essay_max'] != null ? double.tryParse(score['essay_max'].toString()) : null,
      essayGraded: score['essay_graded'] == true,
      essayStatus: (score['essay_status'] ?? 'graded').toString(),
      pendingManualGrading: score['pending_manual_grading'] == true,
      passFail: (json['pass_fail'] ?? 'passed').toString(),
      showResult: showRes,
      violationCount: int.tryParse(session['violation_count']?.toString() ?? '0') ?? 0,
    );
  }

  bool get isPassed => passFail.toLowerCase() == 'passed';
}
