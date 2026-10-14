import '../models/poll_model.dart';
import '../services/poll_service.dart';

class PollRepository {
  final PollService _pollService;

  PollRepository({PollService? pollService})
    : _pollService = pollService ?? PollService();

  Future<PollModel> createPoll({
    required int questionId,
    required List<String> options,
    required String accessToken,
  }) {
    return _pollService.createPoll(
      questionId: questionId,
      options: options,
      accessToken: accessToken,
    );
  }

  Future<PollModel> getPoll({
    required int pollId,
    required String accessToken,
  }) {
    return _pollService.getPoll(pollId: pollId, accessToken: accessToken);
  }

  Future<PollVoteResponseModel> vote({
    required int pollId,
    required int optionId,
    required String accessToken,
  }) {
    return _pollService.vote(
      pollId: pollId,
      optionId: optionId,
      accessToken: accessToken,
    );
  }
}
