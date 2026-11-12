import 'package:cbt_mobile/core/api/api_client.dart';

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
      optionText: json['option_text'] ?? json['text'] ?? '',
    );
  }
}

class QuestionModel {
  final dynamic id;
  final String type; // 'multiple_choice' or 'essay'
  final String questionText;
  final double points;
  final String? mediaPath;
  final String? mediaUrl;
  final String? mediaName;
  final bool isImage;
  final String? mediaExt;
  final String? youtubeUrl;
  final String? youtubeEmbedUrl;
  final List<QuestionOption> options;

  // Selected state
  dynamic selectedOptionId;
  String? essayAnswer;

  QuestionModel({
    required this.id,
    required this.type,
    required this.questionText,
    required this.points,
    this.mediaPath,
    this.mediaUrl,
    this.mediaName,
    this.isImage = false,
    this.mediaExt,
    this.youtubeUrl,
    this.youtubeEmbedUrl,
    required this.options,
    this.selectedOptionId,
    this.essayAnswer,
  });

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get hasYoutube => youtubeUrl != null && youtubeUrl!.isNotEmpty;

  bool get isAnswered {
    if (type == 'essay') {
      return essayAnswer != null && essayAnswer!.trim().isNotEmpty;
    }
    return selectedOptionId != null;
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? [];
    final answerObj = json['answer'] as Map<String, dynamic>?;

    final rawMediaUrl = json['media_url']?.toString();
    final mediaPath = json['media_path']?.toString();
    final isImg = json['is_image'] == true ||
        (mediaPath != null &&
            RegExp(r'\.(jpg|jpeg|png|gif|webp)$', caseSensitive: false).hasMatch(mediaPath)) ||
        (rawMediaUrl != null &&
            RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?.*)?$', caseSensitive: false).hasMatch(rawMediaUrl));

    final resolvedMediaUrl = ApiClient.resolveMediaUrl(
      rawMediaUrl ?? (mediaPath != null && mediaPath.isNotEmpty ? '/storage/$mediaPath' : null),
    );

    return QuestionModel(
      id: json['id'],
      type: json['type'] ?? 'multiple_choice',
      questionText: json['question_text'] ?? json['text'] ?? '',
      points: (json['points'] != null) ? (json['points'] as num).toDouble() : 1.0,
      mediaPath: mediaPath,
      mediaUrl: resolvedMediaUrl,
      mediaName: json['media_name']?.toString(),
      isImage: isImg,
      mediaExt: json['media_ext']?.toString() ??
          (mediaPath != null && mediaPath.contains('.') ? mediaPath.split('.').last.toLowerCase() : null),
      youtubeUrl: json['youtube_url']?.toString(),
      youtubeEmbedUrl: json['youtube_embed_url']?.toString(),
      options: rawOptions.map((e) => QuestionOption.fromJson(e as Map<String, dynamic>)).toList(),
      selectedOptionId: answerObj?['selected_option_id'],
      essayAnswer: answerObj?['essay_answer'],
    );
  }
}
