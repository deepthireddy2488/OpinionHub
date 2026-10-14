int _groupInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String _groupString(dynamic value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

DateTime _groupDate(dynamic value) {
  if (value is DateTime) return value;

  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

class GroupModel {
  final int groupId;
  final String groupName;
  final int createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const GroupModel({
    required this.groupId,
    required this.groupName,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      groupId: _groupInt(json['group_id']),
      groupName: _groupString(json['group_name']),
      createdByUserId: _groupInt(json['created_by_user_id']),
      createdAt: _groupDate(json['created_at']),
      updatedAt: _groupDate(json['updated_at'] ?? json['created_at']),
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
    );
  }

  GroupModel copyWith({
    String? groupName,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return GroupModel(
      groupId: groupId,
      groupName: groupName ?? this.groupName,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

class GroupMemberModel {
  final int groupMemberId;
  final int? userId;
  final String publicCode;
  final String nickname;
  final String? profilePictureUrl;
  final String role;
  final DateTime joinedAt;

  const GroupMemberModel({
    required this.groupMemberId,
    this.userId,
    required this.publicCode,
    required this.nickname,
    this.profilePictureUrl,
    required this.role,
    required this.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final rawUserId = json['user_id'];
    final picture = json['profile_picture_url'];

    return GroupMemberModel(
      groupMemberId: _groupInt(json['group_member_id'] ?? json['member_id']),
      userId: rawUserId == null ? null : _groupInt(rawUserId),
      publicCode: _groupString(json['public_code']),
      nickname: _groupString(json['nickname'], fallback: 'Member'),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
      role: _groupString(json['role'], fallback: 'member'),
      joinedAt: _groupDate(json['joined_at']),
    );
  }
}

class GroupInvitationModel {
  final int invitationId;
  final int groupId;
  final String groupName;
  final String invitedUserPublicCode;
  final String invitedByUserPublicCode;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const GroupInvitationModel({
    required this.invitationId,
    required this.groupId,
    required this.groupName,
    required this.invitedUserPublicCode,
    required this.invitedByUserPublicCode,
    required this.status,
    required this.createdAt,
    required this.respondedAt,
  });

  factory GroupInvitationModel.fromJson(Map<String, dynamic> json) {
    final rawRespondedAt = json['responded_at'];

    return GroupInvitationModel(
      invitationId: _groupInt(json['invitation_id']),
      groupId: _groupInt(json['group_id']),
      groupName: _groupString(json['group_name']),
      invitedUserPublicCode: _groupString(json['invited_user_public_code']),
      invitedByUserPublicCode: _groupString(
        json['invited_by_user_public_code'],
      ),
      status: _groupString(json['status']),
      createdAt: _groupDate(json['created_at']),
      respondedAt: rawRespondedAt == null ? null : _groupDate(rawRespondedAt),
    );
  }
}
