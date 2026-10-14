import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants/app_constants.dart';

class TokenStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> saveAccessToken(String accessToken) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
  }

  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();

    return token != null && token.isNotEmpty;
  }
}
