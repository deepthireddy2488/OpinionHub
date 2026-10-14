import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/answer_model.dart';

class AnswerService {
  final ApiClient _apiClient;

  AnswerService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<AnswerModel>> getAnswers(int questionId) async {
    final response = await _apiClient.getList('/answers/question/$questionId');

    return response
        .whereType<Map>()
        .map((item) => AnswerModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<AnswerModel> createAnswer({
    required int questionId,
    required String content,
    required String accessToken,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.answers,
      body: {'question_id': questionId, 'answer_text': content.trim()},
      accessToken: accessToken,
    );

    return AnswerModel.fromJson(response);
  }
}
