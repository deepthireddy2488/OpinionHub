class ReplyModel {
  final int replyId;
  final int answerId;
  final String publicCode;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePictureUrl;

  const ReplyModel({
    required this.replyId,
    required this.answerId,
    required this.publicCode,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.profilePictureUrl,
  });

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
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

    return ReplyModel(
      replyId: readInt(json['reply_id']),
      answerId: readInt(json['answer_id']),
      publicCode: readString(json['public_code']),
      content: readString(json['reply_text'] ?? json['content']),
      createdAt: readDate(json['created_at']),
      updatedAt: readDate(json['updated_at']),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
    );
  }
}
