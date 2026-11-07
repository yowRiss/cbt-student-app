class QuestionOption {
  final dynamic id;
  final String optionText;

  QuestionOption({
    required this.id,
    required this.optionText,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'],
      optionText: json['option_text'] ?? '',
    );
  }
}

class QuestionModel {
  final dynamic id;
  final String type; // 'multiple_choice' or 'essay'
  final String questionText;
  final double points;
  final List<QuestionOption> options;

  // Selected state
  dynamic selectedOptionId;
  String? essayAnswer;

  QuestionModel({
    required this.id,
    required this.type,
    required this.questionText,
    required this.points,
    required this.options,
    this.selectedOptionId,
    this.essayAnswer,
  });

  bool get isAnswered {
    if (type == 'essay') {
      return essayAnswer != null && essayAnswer!.trim().isNotEmpty;
    }
    return selectedOptionId != null;
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final answerObj = json['answer'] as Map<String, dynamic>?;

    return QuestionModel(
      id: json['id'],
      type: json['type'] ?? 'multiple_choice',
      questionText: json['question_text'] ?? '',
      points: (json['points'] != null) ? (json['points'] as num).toDouble() : 1.0,
      options: rawOptions.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>)).toList(),
      selectedOptionId: answerObj?['selected_option_id'],
      essayAnswer: answerObj?['essay_answer'],
    );
  }
}
