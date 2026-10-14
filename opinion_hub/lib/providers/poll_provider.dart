import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/poll_model.dart';
import '../repositories/poll_repository.dart';
import '../services/token_storage_service.dart';

class PollProvider extends ChangeNotifier {
  final PollRepository _repository;
  final TokenStorageService _tokenStorage;

  PollProvider({PollRepository? repository, TokenStorageService? tokenStorage})
    : _repository = repository ?? PollRepository(),
      _tokenStorage = tokenStorage ?? TokenStorageService();

  PollModel? _poll;
  PollVoteResponseModel? _lastVote;

  bool _isLoading = false;
  bool _isCreating = false;
  bool _isVoting = false;
  bool _disposed = false;

  int? _activePollId;
  int _loadGeneration = 0;

  String? _errorMessage;

  PollModel? get poll => _poll;

  PollVoteResponseModel? get lastVote => _lastVote;

  bool get isLoading => _isLoading;

  bool get isCreating => _isCreating;

  bool get isVoting => _isVoting;

  String? get errorMessage => _errorMessage;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  String _getErrorMessage(Object error, {required String fallback}) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return error.message;
    }

    return fallback;
  }

  Future<String?> _getAccessToken() {
    return _tokenStorage.getAccessToken();
  }

  Future<bool> createPoll({
    required int questionId,
    required List<String> options,
  }) async {
    if (_disposed || _isCreating) {
      return false;
    }

    final cleanedOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (cleanedOptions.length < 2) {
      _errorMessage = 'A poll must have at least 2 options.';
      _safeNotify();
      return false;
    }

    if (cleanedOptions.length > 6) {
      _errorMessage = 'A poll can have at most 6 options.';
      _safeNotify();
      return false;
    }

    if (cleanedOptions.any((option) => option.length > 200)) {
      _errorMessage = 'Each poll option must be 200 characters or less.';
      _safeNotify();
      return false;
    }

    _isCreating = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final token = await _getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'Authentication token not found.',
        );
      }

      final createdPoll = await _repository.createPoll(
        questionId: questionId,
        options: cleanedOptions,
        accessToken: token,
      );

      if (_disposed) return true;

      // Invalidate any pending load that belongs to an
      // older poll request.
      _loadGeneration++;
      _activePollId = createdPoll.pollId;
      _poll = createdPoll;
      _lastVote = null;
      _isLoading = false;
      _errorMessage = null;

      return true;
    } catch (error) {
      if (!_disposed) {
        _errorMessage = _getErrorMessage(
          error,
          fallback: 'Unable to create poll.',
        );
      }

      return false;
    } finally {
      _isCreating = false;
      _safeNotify();
    }
  }

  Future<bool> loadPoll(int pollId) async {
    if (_disposed) return false;

    final generation = ++_loadGeneration;

    _activePollId = pollId;
    _isLoading = true;
    _errorMessage = null;

    // Do not show another question's poll while this
    // question's poll is being fetched.
    if (_poll?.pollId != pollId) {
      _poll = null;
      _lastVote = null;
    }

    _safeNotify();

    try {
      final token = await _getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'Authentication token not found.',
        );
      }

      final loadedPoll = await _repository.getPoll(
        pollId: pollId,
        accessToken: token,
      );

      if (_disposed ||
          generation != _loadGeneration ||
          _activePollId != pollId) {
        return false;
      }

      _poll = loadedPoll;
      _errorMessage = null;

      return true;
    } catch (error) {
      if (!_disposed &&
          generation == _loadGeneration &&
          _activePollId == pollId) {
        _errorMessage = _getErrorMessage(
          error,
          fallback: 'Unable to load poll.',
        );
      }

      return false;
    } finally {
      if (!_disposed && generation == _loadGeneration) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Future<bool> vote({required int pollId, required int optionId}) async {
    if (_disposed || _isVoting) {
      return false;
    }

    _isVoting = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final token = await _getAccessToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          statusCode: 401,
          message: 'Authentication token not found.',
        );
      }

      final voteResult = await _repository.vote(
        pollId: pollId,
        optionId: optionId,
        accessToken: token,
      );

      if (_disposed) return true;

      _lastVote = voteResult;

      // The vote succeeded, so try to refresh the poll's
      // counts. Don't replace another poll if the user
      // has already navigated to it.
      if (_activePollId == pollId) {
        try {
          final updatedPoll = await _repository.getPoll(
            pollId: pollId,
            accessToken: token,
          );

          if (!_disposed && _activePollId == pollId) {
            _poll = updatedPoll;
          }
        } catch (_) {
          // Preserve the successful vote response.
        }
      }

      return true;
    } catch (error) {
      if (!_disposed && _activePollId == pollId) {
        _errorMessage = _getErrorMessage(
          error,
          fallback: 'Unable to submit vote.',
        );
      }

      return false;
    } finally {
      _isVoting = false;
      _safeNotify();
    }
  }

  void clearPoll() {
    if (_disposed) return;

    // Invalidate pending loads so they cannot restore
    // stale poll data after this method is called.
    _loadGeneration++;
    _activePollId = null;
    _poll = null;
    _lastVote = null;
    _isLoading = false;
    _errorMessage = null;

    _safeNotify();
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
