class ExamHistoryModel {
  final dynamic participantId;
  final dynamic examId;
  final String examTitle;
  final String? examDescription;
  final String? teacherName;
  final String status;
  final double? score;
  final double passingScore;
  final bool? passed;
  final double? multipleChoiceScore;
  final double? essayScore;
  final bool essayGraded;
  final String essayStatus;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final int violationCount;
  final bool isAutoSubmitted;
  final bool showResult;

  ExamHistoryModel({
    required this.participantId,
    required this.examId,
    required this.examTitle,
    this.examDescription,
    this.teacherName,
    required this.status,
    this.score,
    this.passingScore = 75.0,
    this.passed,
    this.multipleChoiceScore,
    this.essayScore,
    required this.essayGraded,
    required this.essayStatus,
    this.startedAt,
    this.submittedAt,
    this.violationCount = 0,
    this.isAutoSubmitted = false,
    this.showResult = true,
  });

  factory ExamHistoryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final examObj = json['exam'] is Map<String, dynamic> ? json['exam'] as Map<String, dynamic> : null;
    final showRes = json['show_result'] == true || (examObj != null && examObj['show_result_after_submission'] != false);
    final passingScore = double.tryParse(json['passing_score']?.toString() ?? examObj?['passing_score']?.toString() ?? '75.0') ?? 75.0;

    double? parsedScore;
    if (showRes && json['score'] != null) {
      parsedScore = double.tryParse(json['score'].toString());
    } else if (showRes && json['multiple_choice_score'] != null) {
      parsedScore = double.tryParse(json['multiple_choice_score'].toString());
    }

    bool? isPassed;
    if (parsedScore != null) {
      isPassed = parsedScore >= passingScore;
    }

    return ExamHistoryModel(
      participantId: json['participant_id'] ?? json['id'],
      examId: json['exam_id'] ?? examObj?['id'],
      examTitle: (examObj?['title'] ?? json['exam_title'] ?? 'Ujian Selesai').toString(),
      examDescription: examObj?['description']?.toString(),
      teacherName: examObj?['teacher_name']?.toString() ?? 'Guru Pengampu',
      status: json['status']?.toString() ?? 'completed',
      score: parsedScore,
      passingScore: passingScore,
      passed: isPassed,
      multipleChoiceScore: showRes && json['multiple_choice_score'] != null
          ? double.tryParse(json['multiple_choice_score'].toString())
          : null,
      essayScore: showRes && json['essay_score'] != null
          ? double.tryParse(json['essay_score'].toString())
          : null,
      essayGraded: json['essay_graded'] == true,
      essayStatus: json['essay_status']?.toString() ?? 'graded',
      startedAt: parseDate(json['started_at']),
      submittedAt: parseDate(json['submitted_at']),
      violationCount: int.tryParse(json['violation_count']?.toString() ?? '0') ?? 0,
      isAutoSubmitted: json['is_auto_submitted'] == true || json['status'] == 'auto_submitted',
      showResult: showRes,
    );
  }

  String get submittedDateFormatted {
    if (submittedAt == null) return '-';
    final dt = submittedAt!;
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day} ${months[dt.month]} ${dt.year}, $time';
  }
}
