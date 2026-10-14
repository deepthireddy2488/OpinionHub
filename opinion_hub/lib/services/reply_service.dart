import '../core/network/api_client.dart';
import '../models/reply_model.dart';

class ReplyService {
  final ApiClient _apiClient;

  ReplyService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<ReplyModel>> getReplies(int answerId) async {
    final response = await _apiClient.getList('/replies/answer/$answerId');

    return response
        .whereType<Map>()
        .map((item) => ReplyModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ReplyModel> createReply({
    required int answerId,
    required String content,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      '/replies',
      body: {'answer_id': answerId, 'reply_text': content.trim()},
      accessToken: accessToken,
    );

    return ReplyModel.fromJson(response);
  }
}
