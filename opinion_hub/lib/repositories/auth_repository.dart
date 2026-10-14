import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository({AuthService? authService})
    : _authService = authService ?? AuthService();

  Future<UserModel> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    return _authService.register(
      email: email,
      password: password,
      nickname: nickname,
    );
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    return _authService.login(email: email, password: password);
  }

  Future<UserModel> getCurrentUser() async {
    return _authService.getCurrentUser();
  }

  Future<void> logout() async {
    await _authService.logout();
  }

  Future<bool> isLoggedIn() async {
    return _authService.isLoggedIn();
  }
}
