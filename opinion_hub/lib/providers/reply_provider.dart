import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/reply_model.dart';
import '../repositories/reply_repository.dart';
import '../services/token_storage_service.dart';

class ReplyProvider extends ChangeNotifier {
  final ReplyRepository _replyRepository;
  final TokenStorageService _tokenStorageService;

  ReplyProvider({
    ReplyRepository? replyRepository,
    TokenStorageService? tokenStorageService,
  }) : _replyRepository = replyRepository ?? ReplyRepository(),
       _tokenStorageService = tokenStorageService ?? TokenStorageService();

  final Map<int, List<ReplyModel>> _replies = {};
  final Set<int> _loadingAnswers = {};
  final Set<int> _submittingAnswers = {};
  final Map<int, String> _errors = {};

  bool _disposed = false;

  List<ReplyModel> getRepliesForAnswer(int answerId) {
    return List.unmodifiable(_replies[answerId] ?? const <ReplyModel>[]);
  }

  bool isLoading(int answerId) => _loadingAnswers.contains(answerId);

  bool isSubmitting(int answerId) => _submittingAnswers.contains(answerId);

  String? errorForAnswer(int answerId) => _errors[answerId];

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadReplies(int answerId) async {
    if (_loadingAnswers.contains(answerId)) {
      return;
    }

    _loadingAnswers.add(answerId);
    _errors.remove(answerId);
    _safeNotify();

    try {
      final loaded = await _replyRepository.getReplies(answerId);

      if (!_disposed) {
        _replies[answerId] = loaded;
      }
    } catch (error) {
      if (!_disposed) {
        _errors[answerId] = _getErrorMessage(error);
      }
    } finally {
      _loadingAnswers.remove(answerId);
      _safeNotify();
    }
  }

  Future<bool> submitReply({
    required int answerId,
    required String content,
  }) async {
    final trimmedContent = content.trim();

    if (trimmedContent.isEmpty) {
      _errors[answerId] = 'Please enter a reply.';
      _safeNotify();
      return false;
    }

    if (_submittingAnswers.contains(answerId)) {
      return false;
    }

    _submittingAnswers.add(answerId);
    _errors.remove(answerId);
    _safeNotify();

    try {
      final accessToken = await _tokenStorageService.getAccessToken();

      if (accessToken == null || accessToken.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'You must be logged in to reply.',
        );
      }

      final reply = await _replyRepository.createReply(
        answerId: answerId,
        content: trimmedContent,
        accessToken: accessToken,
      );

      if (_disposed) return true;

      final current = _replies[answerId] ?? const <ReplyModel>[];

      _replies[answerId] = [
        ...current.where((item) => item.replyId != reply.replyId),
        reply,
      ];

      return true;
    } catch (error) {
      if (!_disposed) {
        _errors[answerId] = _getErrorMessage(error);
      }
      return false;
    } finally {
      _submittingAnswers.remove(answerId);
      _safeNotify();
    }
  }

  void clearError(int answerId) {
    _errors.remove(answerId);
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
