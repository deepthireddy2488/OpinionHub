import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/question_model.dart';

class QuestionService {
  final ApiClient _apiClient;

  QuestionService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<List<QuestionModel>> getPublicQuestions() async {
    final response = await _apiClient.getList(ApiConstants.questions);

    return response
        .whereType<Map>()
        .map((item) => QuestionModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  void dispose() {
    _apiClient.dispose();
  }
}
