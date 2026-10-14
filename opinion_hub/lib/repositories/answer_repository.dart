import '../models/answer_model.dart';
import '../services/answer_service.dart';

class AnswerRepository {
  final AnswerService _answerService;

  AnswerRepository({AnswerService? answerService})
    : _answerService = answerService ?? AnswerService();

  Future<List<AnswerModel>> getAnswers(int questionId) {
    return _answerService.getAnswers(questionId);
  }

  Future<AnswerModel> createAnswer({
    required int questionId,
    required String content,
    required String accessToken,
  }) {
    return _answerService.createAnswer(
      questionId: questionId,
      content: content,
      accessToken: accessToken,
    );
  }
}
