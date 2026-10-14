int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _readString(dynamic value) {
  return value?.toString() ?? '';
}

DateTime _readDate(dynamic value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final normalized = value?.toString().toLowerCase();
  return normalized == 'true' || normalized == '1';
}

class PollOptionModel {
  final int optionId;
  final String optionText;
  final int optionOrder;
  final int voteCount;

  const PollOptionModel({
    required this.optionId,
    required this.optionText,
    required this.optionOrder,
    required this.voteCount,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      optionId: _readInt(json['option_id']),
      optionText: _readString(json['option_text']),
      optionOrder: _readInt(json['option_order']),
      voteCount: _readInt(json['vote_count']),
    );
  }
}

class PollModel {
  final int pollId;
  final int questionId;
  final List<PollOptionModel> options;
  final int totalVotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const PollModel({
    required this.pollId,
    required this.questionId,
    required this.options,
    required this.totalVotes,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];

    final options = rawOptions is List
        ? rawOptions
              .whereType<Map>()
              .map(
                (item) =>
                    PollOptionModel.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <PollOptionModel>[];

    return PollModel(
      pollId: _readInt(json['poll_id']),
      questionId: _readInt(json['question_id']),
      options: List.unmodifiable(options),
      totalVotes: _readInt(json['total_votes']),
      createdAt: _readDate(json['created_at']),
      updatedAt: _readDate(json['updated_at']),
      isActive: _readBool(json['is_active']),
    );
  }
}

class PollVoteResponseModel {
  final int pollId;
  final int optionId;
  final int totalVotes;

  const PollVoteResponseModel({
    required this.pollId,
    required this.optionId,
    required this.totalVotes,
  });

  factory PollVoteResponseModel.fromJson(Map<String, dynamic> json) {
    return PollVoteResponseModel(
      pollId: _readInt(json['poll_id']),
      optionId: _readInt(json['option_id']),
      totalVotes: _readInt(json['total_votes']),
    );
  }
}
