import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class ReactionService {
  final ApiClient _apiClient;

  ReactionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<void> reactToQuestion({
    required int questionId,
    required String reactionType,
    required String accessToken,
  }) async {
    await _apiClient.post(
      '${ApiConstants.questionReactions}/$questionId/reactions',
      body: {'reaction_type': reactionType},
      accessToken: accessToken,
    );
  }

  Future<void> reactToAnswer({
    required int answerId,
    required String reactionType,
    required String accessToken,
  }) async {
    await _apiClient.post(
      '${ApiConstants.answerReactions}/$answerId/reactions',
      body: {'reaction_type': reactionType},
      accessToken: accessToken,
    );
  }
}
