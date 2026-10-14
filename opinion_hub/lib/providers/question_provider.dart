import 'package:flutter/foundation.dart';

import '../models/question_model.dart';
import '../repositories/question_repository.dart';

class QuestionProvider extends ChangeNotifier {
  final QuestionRepository _questionRepository;

  QuestionProvider({QuestionRepository? questionRepository})
    : _questionRepository = questionRepository ?? QuestionRepository();

  List<QuestionModel> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _disposed = false;
  int _requestVersion = 0;

  List<QuestionModel> get questions => List.unmodifiable(_questions);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadQuestions() async {
    if (_disposed || _isLoading) return;

    await _fetchQuestions(showLoading: true);
  }

  Future<void> refreshQuestions() async {
    if (_disposed) return;

    // The newest request becomes authoritative even if an
    // older request is still running.
    await _fetchQuestions(showLoading: _questions.isEmpty);
  }

  Future<void> _fetchQuestions({required bool showLoading}) async {
    final requestVersion = ++_requestVersion;

    if (showLoading) {
      _isLoading = true;
    }

    _errorMessage = null;
    _notifyIfAlive();

    try {
      final questions = await _questionRepository.getPublicQuestions();

      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      _questions = questions;
      _errorMessage = null;
    } catch (_) {
      if (_disposed || requestVersion != _requestVersion) {
        return;
      }

      _errorMessage = _questions.isEmpty
          ? 'Unable to load questions. Please try again.'
          : 'Unable to refresh questions. Showing previously loaded results.';
    } finally {
      if (!_disposed && requestVersion == _requestVersion) {
        _isLoading = false;
        _notifyIfAlive();
      }
    }
  }

  void clearError() {
    if (_disposed || _errorMessage == null) return;

    _errorMessage = null;
    _notifyIfAlive();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
