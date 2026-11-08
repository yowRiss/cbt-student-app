class ExamModel {
  final dynamic id;
  final String title;
  final String? description;
  final String? subject;
  final String? teacherName;
  final int durationMinutes;
  final int questionCount;
  final int maxViolations;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool requiresToken;
  final double passingScore;
  final String? sessionToken;
  final String? sessionStatus;

  ExamModel({
    required this.id,
    required this.title,
    this.description,
    this.subject,
    this.teacherName,
    required this.durationMinutes,
    required this.questionCount,
    this.maxViolations = 3,
    required this.status,
    this.startsAt,
    this.endsAt,
    this.requiresToken = false,
    this.passingScore = 75.0,
    this.sessionToken,
    this.sessionStatus,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return ExamModel(
      id: json['id'],
      title: (json['title'] ?? 'Ujian Tanpa Judul').toString(),
      description: json['description']?.toString(),
      subject: json['subject']?.toString() ?? json['subject_name']?.toString() ?? 'Ujian Sekolah',
      teacherName: json['teacher_name']?.toString() ?? json['creator']?['name']?.toString() ?? 'Guru Pengampu',
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? json['duration']?.toString() ?? '60') ?? 60,
      questionCount: int.tryParse(json['question_count']?.toString() ?? json['questions_count']?.toString() ?? '0') ?? 0,
      maxViolations: int.tryParse(json['max_violations']?.toString() ?? '3') ?? 3,
      status: json['status']?.toString() ?? (json['is_published'] == true ? 'published' : 'draft'),
      startsAt: parseDate(json['starts_at'] ?? json['start_time']),
      endsAt: parseDate(json['ends_at'] ?? json['end_time']),
      requiresToken: json['requires_token'] == true || (json['access_token'] != null && json['access_token'].toString().isNotEmpty),
      passingScore: double.tryParse(json['passing_score']?.toString() ?? '75.0') ?? 75.0,
      sessionToken: json['session_token']?.toString() ?? json['active_session']?['token']?.toString(),
      sessionStatus: json['session_status']?.toString() ?? json['active_session']?['status']?.toString(),
    );
  }

  bool get isActive {
    final now = DateTime.now();
    if (startsAt == null && endsAt == null) return true;
    if (startsAt != null && now.isBefore(startsAt!)) return false;
    if (endsAt != null && now.isAfter(endsAt!)) return false;
    return true;
  }

  bool get isUpcoming {
    if (startsAt == null) return false;
    return DateTime.now().isBefore(startsAt!);
  }

  bool get isExpired {
    if (endsAt == null) return false;
    return DateTime.now().isAfter(endsAt!);
  }

  String get scheduleFormatted {
    if (startsAt == null && endsAt == null) return 'Waktu Bebas';
    String formatTime(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    String formatDate(DateTime dt) =>
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

    if (startsAt != null && endsAt != null) {
      return '${formatDate(startsAt!)} • ${formatTime(startsAt!)} - ${formatTime(endsAt!)}';
    } else if (startsAt != null) {
      return '${formatDate(startsAt!)} • ${formatTime(startsAt!)}';
    }
    return 'Hingga ${formatTime(endsAt!)}';
  }
}
