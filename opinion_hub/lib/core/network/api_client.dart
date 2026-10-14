import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../../services/token_storage_service.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  static const Duration _requestTimeout = Duration(seconds: 25);

  final http.Client _client;
  final TokenStorageService _tokenStorageService;

  ApiClient({http.Client? client, TokenStorageService? tokenStorageService})
    : _client = client ?? http.Client(),
      _tokenStorageService = tokenStorageService ?? TokenStorageService();

  Uri _uri(String endpoint) {
    final base = ApiConstants.baseUrl;
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';

    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _buildHeaders(String? accessToken) async {
    final headers = <String, String>{'Accept': 'application/json'};

    var token = accessToken;

    if (token == null || token.isEmpty) {
      try {
        token = await _tokenStorageService.getAccessToken();
      } catch (_) {
        // Public endpoints can still be called without a token.
      }
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<http.Response> _getResponse(Future<http.Response> request) {
    return request.timeout(_requestTimeout);
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    String? accessToken,
  }) async {
    final headers = await _buildHeaders(accessToken);

    final response = await _getResponse(
      _client.get(_uri(endpoint), headers: headers),
    );

    return _handleResponse(response);
  }

  Future<List<dynamic>> getList(String endpoint, {String? accessToken}) async {
    final headers = await _buildHeaders(accessToken);

    final response = await _getResponse(
      _client.get(_uri(endpoint), headers: headers),
    );

    return _handleListResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    final headers = await _buildHeaders(accessToken);

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    final response = await _getResponse(
      _client.post(
        _uri(endpoint),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String endpoint, {
    required String filePath,
    required Map<String, String> fields,
    String? accessToken,
  }) async {
    final request = http.MultipartRequest('POST', _uri(endpoint));

    request.headers.addAll(await _buildHeaders(accessToken));

    request.fields.addAll(fields);
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await _client
        .send(request)
        .timeout(_requestTimeout);

    final response = await http.Response.fromStream(streamedResponse)
        .timeout(_requestTimeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    String? accessToken,
  }) async {
    final headers = await _buildHeaders(accessToken);

    final response = await _getResponse(
      _client.delete(_uri(endpoint), headers: headers),
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = _decodeBody(response);

    if (_isSuccess(response.statusCode)) {
      if (body == null) return <String, dynamic>{};

      if (body is Map<String, dynamic>) {
        return body;
      }

      return <String, dynamic>{'data': body};
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: _extractErrorMessage(body),
    );
  }

  List<dynamic> _handleListResponse(http.Response response) {
    final body = _decodeBody(response);

    if (!_isSuccess(response.statusCode)) {
      throw ApiException(
        statusCode: response.statusCode,
        message: _extractErrorMessage(body),
      );
    }

    if (body is List) return body;

    throw ApiException(
      statusCode: response.statusCode,
      message: 'The server returned an unexpected list response.',
    );
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  String _extractErrorMessage(dynamic body) {
    if (body is Map) {
      final detail = body['detail'];

      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }

      if (detail is List && detail.isNotEmpty) {
        return detail
            .map((item) {
              if (item is Map && item['msg'] != null) {
                return item['msg'].toString();
              }
              return item.toString();
            })
            .join('\n');
      }

      final message = body['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    if (body is String && body.trim().isNotEmpty) {
      return body.trim();
    }

    return 'Request failed. Please try again.';
  }

  void dispose() {
    _client.close();
  }
}
