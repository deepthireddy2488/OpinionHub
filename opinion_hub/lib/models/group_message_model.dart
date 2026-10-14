class GroupMessageModel {
  final int messageId;
  final int groupId;
  final String publicCode;
  final String nickname;
  final String? profilePictureUrl;
  final String content;
  final DateTime createdAt;
  final bool isMine;
  final int? voiceNoteId;
  final double? durationSeconds;
  final String? audioUrl;

  const GroupMessageModel({
    required this.messageId,
    required this.groupId,
    required this.publicCode,
    required this.nickname,
    this.profilePictureUrl,
    required this.content,
    required this.createdAt,
    required this.isMine,
    this.voiceNoteId,
    this.durationSeconds,
    this.audioUrl,
  });

  bool get hasVoiceNote =>
      voiceNoteId != null || (audioUrl?.isNotEmpty ?? false);

  // Compatibility with code that uses the older property name.
  double? get voiceNoteDurationSeconds => durationSeconds;

  factory GroupMessageModel.fromJson(Map<String, dynamic> json) {
    return GroupMessageModel(
      messageId: (json['message_id'] as num).toInt(),
      groupId: (json['group_id'] as num).toInt(),
      publicCode: json['public_code'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'User',
      profilePictureUrl: json['profile_picture_url'] as String?,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      isMine: json['is_mine'] as bool? ?? false,
      voiceNoteId: json['voice_note_id'] is num
          ? (json['voice_note_id'] as num).toInt()
          : null,
      durationSeconds: json['duration_seconds'] is num
          ? (json['duration_seconds'] as num).toDouble()
          : null,
      audioUrl: json['audio_url'] as String?,
    );
  }
}
