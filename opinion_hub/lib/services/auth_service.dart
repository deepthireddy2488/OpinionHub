import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import 'token_storage_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorageService _tokenStorageService;

  AuthService({ApiClient? apiClient, TokenStorageService? tokenStorageService})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorageService = tokenStorageService ?? TokenStorageService();

  Future<UserModel> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.register,
      body: {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
      },
    );

    return UserModel.fromJson(response);
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {'email': email.trim(), 'password': password},
    );

    final accessToken = response['access_token'];

    if (accessToken is! String || accessToken.isEmpty) {
      throw const ApiException(
        statusCode: 500,
        message: 'Login response did not contain an access token.',
      );
    }

    await _tokenStorageService.saveAccessToken(accessToken);

    try {
      return await getCurrentUser();
    } catch (_) {
      // Avoid leaving a token behind if validating the
      // newly created session fails.
      try {
        await _tokenStorageService.deleteAccessToken();
      } catch (_) {
        // Preserve the original authentication error.
      }

      rethrow;
    }
  }

  Future<UserModel> getCurrentUser() async {
    final accessToken = await _tokenStorageService.getAccessToken();

    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'No authentication token found.',
      );
    }

    final response = await _apiClient.get(
      ApiConstants.currentUser,
      accessToken: accessToken,
    );

    return UserModel.fromJson(response);
  }

  Future<void> logout() async {
    await _tokenStorageService.deleteAccessToken();
  }

  Future<bool> isLoggedIn() async {
    return _tokenStorageService.hasAccessToken();
  }
}
