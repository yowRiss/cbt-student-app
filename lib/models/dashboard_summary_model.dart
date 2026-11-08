class DashboardSummaryModel {
  final int totalAssigned;
  final int availableCount;
  final int upcomingCount;
  final int completedCount;

  DashboardSummaryModel({
    required this.totalAssigned,
    required this.availableCount,
    required this.upcomingCount,
    required this.completedCount,
  });

  factory DashboardSummaryModel.fromJson(Map<String, dynamic> json) {
    return DashboardSummaryModel(
      totalAssigned: int.tryParse(json['total_assigned']?.toString() ?? json['assigned_exams']?.toString() ?? '0') ?? 0,
      availableCount: int.tryParse(json['available_count']?.toString() ?? json['active_exams']?.toString() ?? '0') ?? 0,
      upcomingCount: int.tryParse(json['upcoming_count']?.toString() ?? '0') ?? 0,
      completedCount: int.tryParse(json['completed_count']?.toString() ?? json['submitted_exams']?.toString() ?? '0') ?? 0,
    );
  }
}

class ActiveSessionModel {
  final String token;
  final dynamic examId;
  final String examTitle;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int durationMinutes;
  final int maxViolations;

  ActiveSessionModel({
    required this.token,
    required this.examId,
    required this.examTitle,
    this.startedAt,
    this.expiresAt,
    this.durationMinutes = 60,
    this.maxViolations = 3,
  });

  factory ActiveSessionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return ActiveSessionModel(
      token: (json['token'] ?? '').toString(),
      examId: json['exam_id'],
      examTitle: (json['exam_title'] ?? 'Ujian Sedang Berjalan').toString(),
      startedAt: parseDate(json['started_at']),
      expiresAt: parseDate(json['expires_at']),
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? '60') ?? 60,
      maxViolations: int.tryParse(json['max_violations']?.toString() ?? '3') ?? 3,
    );
  }
}
