int _questionInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? _questionNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String _questionString(dynamic value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

DateTime _questionDate(dynamic value) {
  if (value is DateTime) return value;

  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

class QuestionModel {
  final int questionId;
  final String publicCode;
  final String title;
  final int? groupId;
  final int? pollId;
  final int likeCount;
  final int interestingCount;
  final int agreeCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? profilePictureUrl;

  const QuestionModel({
    required this.questionId,
    required this.publicCode,
    required this.title,
    required this.groupId,
    required this.pollId,
    required this.likeCount,
    required this.interestingCount,
    required this.agreeCount,
    required this.createdAt,
    required this.updatedAt,
    this.profilePictureUrl,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final created = _questionDate(json['created_at']);
    final picture = json['profile_picture_url'];

    return QuestionModel(
      questionId: _questionInt(json['question_id']),
      publicCode: _questionString(
        json['public_code'],
        fallback: 'Community member',
      ),
      title: _questionString(json['title']),
      groupId: _questionNullableInt(json['group_id']),
      pollId: _questionNullableInt(json['poll_id']),
      likeCount: _questionInt(json['like_count']),
      interestingCount: _questionInt(json['interesting_count']),
      agreeCount: _questionInt(json['agree_count']),
      createdAt: created,
      updatedAt: json['updated_at'] == null
          ? created
          : _questionDate(json['updated_at']),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
    );
  }
}
