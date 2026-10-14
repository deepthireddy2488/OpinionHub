import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../repositories/reaction_repository.dart';
import '../services/token_storage_service.dart';

class ReactionProvider extends ChangeNotifier {
  final ReactionRepository _reactionRepository;
  final TokenStorageService _tokenStorageService;

  ReactionProvider({
    ReactionRepository? reactionRepository,
    TokenStorageService? tokenStorageService,
  }) : _reactionRepository = reactionRepository ?? ReactionRepository(),
       _tokenStorageService = tokenStorageService ?? TokenStorageService();

  bool _isLoading = false;
  bool _disposed = false;

  String? _errorMessage;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<bool> reactToQuestion({
    required int questionId,
    required String reactionType,
  }) {
    return _submit(
      action: (accessToken) => _reactionRepository.reactToQuestion(
        questionId: questionId,
        reactionType: reactionType,
        accessToken: accessToken,
      ),
    );
  }

  Future<bool> reactToAnswer({
    required int answerId,
    required String reactionType,
  }) {
    return _submit(
      action: (accessToken) => _reactionRepository.reactToAnswer(
        answerId: answerId,
        reactionType: reactionType,
        accessToken: accessToken,
      ),
    );
  }

  Future<bool> _submit({
    required Future<void> Function(String accessToken) action,
  }) async {
    if (_disposed || _isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final accessToken = await _tokenStorageService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'You must be logged in to react.',
        );
      }

      await action(accessToken);

      return true;
    } catch (error) {
      if (!_disposed) {
        if (error is ApiException) {
          _errorMessage = error.message;
        } else {
          _errorMessage = 'Unable to save reaction. Please try again.';
        }
      }

      return false;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void clearError() {
    if (_disposed) return;

    _errorMessage = null;
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
