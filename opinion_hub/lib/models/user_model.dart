int _userInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _userString(dynamic value, {String fallback = ''}) {
  return value is String ? value : fallback;
}

DateTime _userDate(dynamic value) {
  if (value is DateTime) return value;

  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  return DateTime.fromMillisecondsSinceEpoch(0);
}

class UserModel {
  final int userId;
  final String nickname;
  final String publicCode;
  final DateTime createdAt;
  final String? profilePictureUrl;
  final bool isAdmin;

  const UserModel({
    required this.userId,
    required this.nickname,
    required this.publicCode,
    required this.createdAt,
    this.profilePictureUrl,
    this.isAdmin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final picture = json['profile_picture_url'];

    return UserModel(
      userId: _userInt(json['user_id']),
      nickname: _userString(json['nickname'], fallback: 'Member'),
      publicCode: _userString(json['public_code']),
      createdAt: _userDate(json['created_at']),
      profilePictureUrl: picture is String && picture.trim().isNotEmpty
          ? picture.trim()
          : null,
      isAdmin: json['is_admin'] == true,
    );
  }
}
