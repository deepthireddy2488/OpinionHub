class AnswerModel {
  final int answerId;
  final int questionId;
  final String publicCode;
  final String content;
  final int helpfulCount;
  final int agreeCount;
  final int goodAnswerCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePictureUrl;

  const AnswerModel({
    required this.answerId,
    required this.questionId,
    required this.publicCode,
    required this.content,
    required this.helpfulCount,
    required this.agreeCount,
    required this.goodAnswerCount,
    required this.createdAt,
    required this.updatedAt,
    this.profilePictureUrl,
  });

  factory AnswerModel.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    String readString(dynamic value) => value is String ? value : '';

    DateTime readDate(dynamic value) {
      return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    final picture = json['profile_picture_url'];

    return AnswerModel(
      answerId: readInt(json['answer_id']),
      questionId: readInt(json['question_id']),
      publicCode: readString(json['public_code']),
      content: readString(json['answer_text'] ?? json['content']),
      helpfulCount: readInt(json['helpful_count']),
      agreeCount: readInt(json['agree_count']),
      goodAnswerCount: readInt(json['good_answer_count']),
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
    );
  }
}
