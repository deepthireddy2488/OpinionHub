import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, loading, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthProvider({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  AuthStatus _status = AuthStatus.unknown;
  UserModel? _user;
  String? _errorMessage;

  bool _isLoading = false;
  bool _registrationCompleted = false;
  bool _initializationStarted = false;
  bool _disposed = false;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  bool get registrationCompleted => _registrationCompleted;

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Updates the signed-in user's details throughout the app.
  /// Used after changing or removing a profile picture.
  void updateUserProfile(UserModel updatedUser) {
    if (_disposed || _user == null) return;

    if (_user!.userId != updatedUser.userId) {
      return;
    }

    _user = updatedUser;
    _notifyIfAlive();
  }

  Future<void> initialize() async {
    if (_initializationStarted || _disposed) {
      return;
    }

    _initializationStarted = true;

    try {
      final isLoggedIn = await _authRepository.isLoggedIn();

      if (_disposed) return;

      if (!isLoggedIn) {
        _user = null;
        _status = AuthStatus.unauthenticated;
        return;
      }

      _user = await _authRepository.getCurrentUser();

      if (_disposed) return;

      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (_) {
      if (_disposed) return;

      try {
        await _authRepository.logout();
      } catch (_) {
        // Continue to the unauthenticated state.
      }

      if (_disposed) return;

      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    } finally {
      _notifyIfAlive();
    }
  }

  Future<void> login({required String email, required String password}) async {
    if (_isLoading || _disposed) return;

    _isLoading = true;
    _errorMessage = null;
    _registrationCompleted = false;
    _notifyIfAlive();

    try {
      final authenticatedUser = await _authRepository.login(
        email: email,
        password: password,
      );

      if (_disposed) return;

      _user = authenticatedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (error) {
      if (_disposed) return;

      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = _getErrorMessage(error);
    } finally {
      _isLoading = false;
      _notifyIfAlive();
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    if (_isLoading || _disposed) return;

    _isLoading = true;
    _errorMessage = null;
    _registrationCompleted = false;
    _notifyIfAlive();

    try {
      await _authRepository.register(
        email: email,
        password: password,
        nickname: nickname,
      );

      if (_disposed) return;

      _registrationCompleted = true;

      try {
        final authenticatedUser = await _authRepository.login(
          email: email,
          password: password,
        );

        if (_disposed) return;

        _user = authenticatedUser;
        _status = AuthStatus.authenticated;
        _errorMessage = null;
      } catch (_) {
        if (_disposed) return;

        _user = null;
        _status = AuthStatus.unauthenticated;
        _errorMessage =
            'Your account was created, but automatic sign-in failed. '
            'Please log in with your new account.';
      }
    } catch (error) {
      if (_disposed) return;

      _user = null;
      _status = AuthStatus.unauthenticated;
      _registrationCompleted = false;
      _errorMessage = _getErrorMessage(error);
    } finally {
      _isLoading = false;
      _notifyIfAlive();
    }
  }

  Future<void> logout() async {
    if (_disposed || _isLoading) return;

    try {
      await _authRepository.logout();
    } catch (_) {
      // Clear the authenticated UI even if token cleanup fails.
    } finally {
      if (!_disposed) {
        _user = null;
        _errorMessage = null;
        _registrationCompleted = false;
        _status = AuthStatus.unauthenticated;
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
