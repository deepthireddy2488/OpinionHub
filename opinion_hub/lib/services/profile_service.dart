import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';
import 'token_storage_service.dart';

class ProfileService {
  final ApiClient _apiClient;
  final TokenStorageService _tokenStorage;

  ProfileService({ApiClient? apiClient, TokenStorageService? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorageService();

  Future<String> _requireToken() async {
    final token = await _tokenStorage.getAccessToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Please log in again.',
      );
    }

    return token;
  }

  Future<UserModel> uploadProfilePicture(String filePath) async {
    final token = await _requireToken();

    final response = await _apiClient.postMultipart(
      ApiConstants.profilePicture,
      filePath: filePath,
      fields: const {},
      accessToken: token,
    );

    return UserModel.fromJson(response);
  }

  Future<UserModel> removeProfilePicture() async {
    final token = await _requireToken();

    final response = await _apiClient.delete(
      ApiConstants.profilePicture,
      accessToken: token,
    );

    return UserModel.fromJson(response);
  }

  void dispose() {
    _apiClient.dispose();
  }
}
