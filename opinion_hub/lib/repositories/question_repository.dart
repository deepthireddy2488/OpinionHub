import '../models/question_model.dart';
import '../services/question_service.dart';

class QuestionRepository {
  final QuestionService _questionService;

  QuestionRepository({QuestionService? questionService})
    : _questionService = questionService ?? QuestionService();

  Future<List<QuestionModel>> getPublicQuestions() async {
    return _questionService.getPublicQuestions();
  }
}
