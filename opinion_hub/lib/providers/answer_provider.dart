import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/answer_model.dart';
import '../repositories/answer_repository.dart';
import '../services/token_storage_service.dart';

class AnswerProvider extends ChangeNotifier {
  final AnswerRepository _answerRepository;
  final TokenStorageService _tokenStorageService;

  AnswerProvider({
    AnswerRepository? answerRepository,
    TokenStorageService? tokenStorageService,
  }) : _answerRepository = answerRepository ?? AnswerRepository(),
       _tokenStorageService = tokenStorageService ?? TokenStorageService();

  final Map<int, List<AnswerModel>> _answers = {};
  final Set<int> _loadingQuestions = {};
  final Set<int> _submittingQuestions = {};
  final Map<int, String> _errors = {};
  final Map<int, int> _requestVersions = {};

  int? _currentQuestionId;
  bool _disposed = false;

  List<AnswerModel> get answers {
    final id = _currentQuestionId;
    if (id == null) return const [];
    return answersForQuestion(id);
  }

  bool get isLoading {
    final id = _currentQuestionId;
    return id != null && isLoadingForQuestion(id);
  }

  bool get isSubmitting {
    final id = _currentQuestionId;
    return id != null && isSubmittingForQuestion(id);
  }

  String? get errorMessage {
    final id = _currentQuestionId;
    return id == null ? null : errorForQuestion(id);
  }

  List<AnswerModel> answersForQuestion(int questionId) {
    return List.unmodifiable(_answers[questionId] ?? const <AnswerModel>[]);
  }

  bool isLoadingForQuestion(int questionId) {
    return _loadingQuestions.contains(questionId);
  }

  bool isSubmittingForQuestion(int questionId) {
    return _submittingQuestions.contains(questionId);
  }

  String? errorForQuestion(int questionId) {
    return _errors[questionId];
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadAnswers(int questionId, {bool forceRefresh = false}) async {
    _currentQuestionId = questionId;

    if (_loadingQuestions.contains(questionId)) {
      return;
    }

    _loadingQuestions.add(questionId);
    _errors.remove(questionId);

    final version = (_requestVersions[questionId] ?? 0) + 1;
    _requestVersions[questionId] = version;

    _safeNotify();

    try {
      final loaded = await _answerRepository.getAnswers(questionId);

      if (_disposed || _requestVersions[questionId] != version) {
        return;
      }

      _answers[questionId] = loaded;
    } catch (error) {
      if (!_disposed) {
        _errors[questionId] = _getErrorMessage(error);
      }
    } finally {
      _loadingQuestions.remove(questionId);
      _safeNotify();
    }
  }

  Future<bool> submitAnswer({
    required int questionId,
    required String content,
  }) async {
    _currentQuestionId = questionId;

    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) {
      _errors[questionId] = 'Please enter your opinion.';
      _safeNotify();
      return false;
    }

    if (_submittingQuestions.contains(questionId)) {
      return false;
    }

    _submittingQuestions.add(questionId);
    _errors.remove(questionId);
    _safeNotify();

    try {
      final accessToken = await _tokenStorageService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'You must be logged in to answer.',
        );
      }

      final answer = await _answerRepository.createAnswer(
        questionId: questionId,
        content: trimmedContent,
        accessToken: accessToken,
      );

      if (_disposed) return true;

      // Invalidate any older in-flight request so it
      // cannot replace the latest cached answer list.
      _requestVersions[questionId] = (_requestVersions[questionId] ?? 0) + 1;

      final existing = _answers[questionId] ?? const <AnswerModel>[];

      _answers[questionId] = [
        answer,
        ...existing.where((item) => item.answerId != answer.answerId),
      ];

      return true;
    } catch (error) {
      if (!_disposed) {
        _errors[questionId] = _getErrorMessage(error);
      }

      return false;
    } finally {
      _submittingQuestions.remove(questionId);
      _safeNotify();
    }
  }

  void clearError([int? questionId]) {
    if (questionId == null) {
      _errors.clear();
    } else {
      _errors.remove(questionId);
    }

    _safeNotify();
  }

  String _getErrorMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }

    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
