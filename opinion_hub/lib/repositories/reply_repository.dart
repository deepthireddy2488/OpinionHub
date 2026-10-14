import '../models/reply_model.dart';
import '../services/reply_service.dart';

class ReplyRepository {
  final ReplyService _replyService;

  ReplyRepository({ReplyService? replyService})
    : _replyService = replyService ?? ReplyService();

  Future<List<ReplyModel>> getReplies(int answerId) {
    return _replyService.getReplies(answerId);
  }

  Future<ReplyModel> createReply({
    required int answerId,
    required String content,
    required String accessToken,
  }) {
    return _replyService.createReply(
      answerId: answerId,
      content: content,
      accessToken: accessToken,
    );
  }
}
