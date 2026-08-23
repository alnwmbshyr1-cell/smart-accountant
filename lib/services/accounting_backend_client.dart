import 'dart:convert';

import 'package:http/http.dart' as http;

typedef BackendAccessTokenLoader = Future<String?> Function();

class AccountingBackendClient {
  AccountingBackendClient({
    required String baseUrl,
    required BackendAccessTokenLoader accessTokenLoader,
    BackendAccessTokenLoader? refreshAccessToken,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/*$'), ''),
        _accessTokenLoader = accessTokenLoader,
        _refreshAccessToken = refreshAccessToken,
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final BackendAccessTokenLoader _accessTokenLoader;
  final BackendAccessTokenLoader? _refreshAccessToken;
  final http.Client _httpClient;
  final Duration timeout;

  Future<Map<String, dynamic>?> parseCommand(String text) async {
    final input = text.trim();
    if (input.isEmpty) return null;

    final token = await _readToken(_accessTokenLoader);
    if (token == null) return null;

    try {
      var response = await _send(input, token);
      if (response.statusCode == 401 && _refreshAccessToken != null) {
        final refreshed = await _readToken(_refreshAccessToken!);
        if (refreshed != null && refreshed != token) {
          response = await _send(input, refreshed);
        }
      }

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on Object {
      // Every transport/auth/JSON failure goes to the deterministic local parser.
      return null;
    }
  }

  Future<String?> _readToken(BackendAccessTokenLoader loader) async {
    try {
      final token = (await loader())?.trim();
      return token == null || token.isEmpty ? null : token;
    } on Object {
      return null;
    }
  }

  Future<http.Response> _send(String input, String token) {
    return _httpClient
        .post(
          Uri.parse('$_baseUrl/v1/accounting/parse'),
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json',
            'authorization': 'Bearer $token',
          },
          body: jsonEncode({'text': input}),
        )
        .timeout(timeout);
  }
}
