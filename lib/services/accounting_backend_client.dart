import 'dart:convert';

import 'package:http/http.dart' as http;

/// Loads a short-lived user access token from the app's auth provider.
typedef BackendAccessTokenLoader = Future<String?> Function();

class AccountingBackendClient {
  AccountingBackendClient({
    required String baseUrl,
    required BackendAccessTokenLoader accessTokenLoader,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
  })  : _baseUrl = baseUrl.replaceFirst(RegExp(r'/*$'), ''),
        _accessTokenLoader = accessTokenLoader,
        _httpClient = httpClient ?? http.Client();

  final String _baseUrl;
  final BackendAccessTokenLoader _accessTokenLoader;
  final http.Client _httpClient;
  final Duration timeout;

  Future<Map<String, dynamic>?> parseCommand(String text) async {
    final input = text.trim();
    if (input.isEmpty) return null;

    final token = (await _accessTokenLoader())?.trim();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _httpClient
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

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } on Object {
      // The caller must use the deterministic local parser on all failures.
      return null;
    }
  }
}
