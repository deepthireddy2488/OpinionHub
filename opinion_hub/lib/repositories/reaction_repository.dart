import '../services/reaction_service.dart';

class ReactionRepository {
  final ReactionService _reactionService;

  ReactionRepository({ReactionService? reactionService})
    : _reactionService = reactionService ?? ReactionService();

  Future<void> reactToQuestion({
    required int questionId,
    required String reactionType,
    required String accessToken,
  }) async {
    return _reactionService.reactToQuestion(
      questionId: questionId,
      reactionType: reactionType,
      accessToken: accessToken,
    );
  }

  Future<void> reactToAnswer({
    required int answerId,
    required String reactionType,
    required String accessToken,
  }) async {
    return _reactionService.reactToAnswer(
      answerId: answerId,
      reactionType: reactionType,
      accessToken: accessToken,
    );
  }
}
