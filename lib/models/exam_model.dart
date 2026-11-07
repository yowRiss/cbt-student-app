class ExamModel {
  final dynamic id;
  final String title;
  final String? subject;
  final int durationMinutes;
  final int questionCount;
  final String status;
  final String? startTime;
  final String? endTime;
  final String? sessionToken;
  final String? sessionStatus;

  ExamModel({
    required this.id,
    required this.title,
    this.subject,
    required this.durationMinutes,
    required this.questionCount,
    required this.status,
    this.startTime,
    this.endTime,
    this.sessionToken,
    this.sessionStatus,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'],
      title: json['title'] ?? 'Ujian',
      subject: json['subject'] ?? json['subject_name'],
      durationMinutes: json['duration_minutes'] ?? json['duration'] ?? 60,
      questionCount: json['question_count'] ?? json['questions_count'] ?? 0,
      status: json['status'] ?? 'published',
      startTime: json['start_time'],
      endTime: json['end_time'],
      sessionToken: json['session_token'] ?? json['active_session']?['token'],
      sessionStatus: json['session_status'] ?? json['active_session']?['status'],
    );
  }
}
