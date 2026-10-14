import 'question_model.dart';

int _featureInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _featureString(dynamic value) => value is String ? value : '';

DateTime _featureDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class CommunityProfileModel {
  final int userId;
  final String nickname;
  final String publicCode;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final int questionCount;
  final int answerCount;
  final int receivedReactions;
  final int reputationPoints;
  final List<CommunityBadgeModel> badges;
  final List<QuestionModel> recentQuestions;

  const CommunityProfileModel({
    required this.userId,
    required this.nickname,
    required this.publicCode,
    required this.profilePictureUrl,
    required this.createdAt,
    required this.questionCount,
    required this.answerCount,
    required this.receivedReactions,
    required this.reputationPoints,
    required this.badges,
    required this.recentQuestions,
  });

  factory CommunityProfileModel.fromJson(Map<String, dynamic> json) {
    final picture = json['profile_picture_url'];
    final badgeList = json['badges'];
    final questions = json['recent_questions'];

    return CommunityProfileModel(
      userId: _featureInt(json['user_id']),
      nickname: _featureString(json['nickname']),
      publicCode: _featureString(json['public_code']),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
      createdAt: _featureDate(json['created_at']),
      questionCount: _featureInt(json['question_count']),
      answerCount: _featureInt(json['answer_count']),
      receivedReactions: _featureInt(json['received_reactions']),
      reputationPoints: _featureInt(json['reputation_points']),
      badges: badgeList is List
          ? badgeList
                .whereType<Map>()
                .map(
                  (item) => CommunityBadgeModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      recentQuestions: questions is List
          ? questions
                .whereType<Map>()
                .map(
                  (item) =>
                      QuestionModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
    );
  }
}

class CommunityBadgeModel {
  final String code;
  final String title;
  final String description;

  const CommunityBadgeModel({
    required this.code,
    required this.title,
    required this.description,
  });

  factory CommunityBadgeModel.fromJson(Map<String, dynamic> json) {
    return CommunityBadgeModel(
      code: _featureString(json['code']),
      title: _featureString(json['title']),
      description: _featureString(json['description']),
    );
  }
}

class CommunityBookmarkModel {
  final int bookmarkId;
  final DateTime bookmarkedAt;
  final QuestionModel question;

  const CommunityBookmarkModel({
    required this.bookmarkId,
    required this.bookmarkedAt,
    required this.question,
  });

  factory CommunityBookmarkModel.fromJson(Map<String, dynamic> json) {
    return CommunityBookmarkModel(
      bookmarkId: _featureInt(json['bookmark_id']),
      bookmarkedAt: _featureDate(json['bookmarked_at']),
      question: QuestionModel.fromJson(
        Map<String, dynamic>.from(json['question'] as Map),
      ),
    );
  }
}

class CommunityNotificationModel {
  final int notificationId;
  final String notificationType;
  final String title;
  final String body;
  final String? targetType;
  final int? targetId;
  final bool isRead;
  final DateTime createdAt;
  final String? actorNickname;
  final String? actorPublicCode;
  final String? actorProfilePictureUrl;

  const CommunityNotificationModel({
    required this.notificationId,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
    required this.actorNickname,
    required this.actorPublicCode,
    required this.actorProfilePictureUrl,
  });

  factory CommunityNotificationModel.fromJson(Map<String, dynamic> json) {
    final targetId = json['target_id'];
    final picture = json['actor_profile_picture_url'];

    return CommunityNotificationModel(
      notificationId: _featureInt(json['notification_id']),
      notificationType: _featureString(json['notification_type']),
      title: _featureString(json['title']),
      body: _featureString(json['body']),
      targetType: json['target_type'] is String
          ? json['target_type'] as String
          : null,
      targetId: targetId == null ? null : _featureInt(targetId),
      isRead: json['is_read'] == true,
      createdAt: _featureDate(json['created_at']),
      actorNickname: json['actor_nickname'] as String?,
      actorPublicCode: json['actor_public_code'] as String?,
      actorProfilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
    );
  }
}

class CommunityAISummaryModel {
  final int questionId;
  final String questionTitle;
  final String summary;
  final List<String> commonGround;
  final List<String> differentViewpoints;
  final List<String> questionsToConsider;
  final bool aiGenerated;
  final DateTime generatedAt;

  const CommunityAISummaryModel({
    required this.questionId,
    required this.questionTitle,
    required this.summary,
    required this.commonGround,
    required this.differentViewpoints,
    required this.questionsToConsider,
    required this.aiGenerated,
    required this.generatedAt,
  });

  factory CommunityAISummaryModel.fromJson(Map<String, dynamic> json) {
    List<String> readStrings(dynamic value) {
      if (value is! List) return const [];
      return value.whereType<String>().toList();
    }

    return CommunityAISummaryModel(
      questionId: _featureInt(json['question_id']),
      questionTitle: _featureString(json['question_title']),
      summary: _featureString(json['summary']),
      commonGround: readStrings(json['common_ground']),
      differentViewpoints: readStrings(json['different_viewpoints']),
      questionsToConsider: readStrings(json['questions_to_consider']),
      aiGenerated: json['ai_generated'] == true,
      generatedAt: _featureDate(json['generated_at']),
    );
  }
}

class CommunityAdminReportModel {
  final int reportId;
  final int reporterUserId;
  final int? questionId;
  final int? answerId;
  final int? replyId;
  final String reason;
  final String? description;
  final String status;
  final String? aiStatus;
  final bool? aiFlagged;
  final DateTime createdAt;

  const CommunityAdminReportModel({
    required this.reportId,
    required this.reporterUserId,
    required this.questionId,
    required this.answerId,
    required this.replyId,
    required this.reason,
    required this.description,
    required this.status,
    required this.aiStatus,
    required this.aiFlagged,
    required this.createdAt,
  });

  factory CommunityAdminReportModel.fromJson(Map<String, dynamic> json) {
    int? nullableInt(dynamic value) =>
        value == null ? null : _featureInt(value);

    return CommunityAdminReportModel(
      reportId: _featureInt(json['report_id']),
      reporterUserId: _featureInt(json['reporter_user_id']),
      questionId: nullableInt(json['question_id']),
      answerId: nullableInt(json['answer_id']),
      replyId: nullableInt(json['reply_id']),
      reason: _featureString(json['reason']),
      description: json['description'] as String?,
      status: _featureString(json['status']),
      aiStatus: json['ai_status'] as String?,
      aiFlagged: json['ai_flagged'] as bool?,
      createdAt: _featureDate(json['created_at']),
    );
  }
}
