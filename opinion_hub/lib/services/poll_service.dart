import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/poll_model.dart';

class PollService {
  final ApiClient _apiClient;

  PollService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<PollModel> createPoll({
    required int questionId,
    required List<String> options,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.polls,
      body: {
        'question_id': questionId,
        'options': options
            .map((option) => {'option_text': option.trim()})
            .toList(),
      },
      accessToken: accessToken,
    );

    return PollModel.fromJson(response);
  }

  Future<PollModel> getPoll({
    required int pollId,
    required String accessToken,
  }) async {
    final response = await _apiClient.get(
      '${ApiConstants.polls}/$pollId',
      accessToken: accessToken,
    );

    return PollModel.fromJson(response);
  }

  Future<PollVoteResponseModel> vote({
    required int pollId,
    required int optionId,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '${ApiConstants.polls}/$pollId/vote',
      body: {'option_id': optionId},
      accessToken: accessToken,
    );

    return PollVoteResponseModel.fromJson(response);
  }
}
