import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_accountant/services/accounting_backend_client.dart';

void main() {
  test('returns map and sends bearer token', () async {
    late http.BaseRequest request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
        '{"type":"مصروف","amount":20000,"desc":"بنزين"}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final backend = AccountingBackendClient(
      baseUrl: 'https://api.example.test/',
      accessTokenLoader: () async => ' token-123 ',
      httpClient: client,
    );

    final result = await backend.parseCommand('سجل مصروف بنزين');

    expect(result?['type'], 'مصروف');
    expect(
        request.url.toString(), 'https://api.example.test/v1/accounting/parse');
    expect(request.headers['authorization'], 'Bearer token-123');
  });

  test('returns null without requesting when token is missing', () async {
    var called = false;
    final backend = AccountingBackendClient(
      baseUrl: 'https://api.example.test',
      accessTokenLoader: () async => null,
      httpClient: MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    expect(await backend.parseCommand('أمر'), isNull);
    expect(called, isFalse);
  });

  test(
      'returns null for blank text, non-200, invalid JSON, and non-object JSON',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('server error', 503);
      if (calls == 2) return http.Response('[]', 200);
      return http.Response('{}', 200);
    });
    final backend = AccountingBackendClient(
      baseUrl: 'https://api.example.test',
      accessTokenLoader: () async => 'token',
      httpClient: client,
    );

    expect(await backend.parseCommand(''), isNull);
    expect(await backend.parseCommand('أمر'), isNull);
    expect(await backend.parseCommand('أمر'), isNull);
    expect(calls, 2);
  });

  test('returns null when the request times out', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response('{}', 200);
    });
    final backend = AccountingBackendClient(
      baseUrl: 'https://api.example.test',
      accessTokenLoader: () async => 'token',
      httpClient: client,
      timeout: const Duration(milliseconds: 1),
    );

    expect(await backend.parseCommand('أمر'), isNull);
  });

  test('refreshes the token and retries exactly once after 401', () async {
    final sentTokens = <String>[];
    var calls = 0;
    final backend = AccountingBackendClient(
      baseUrl: 'https://api.example.test',
      accessTokenLoader: () async => 'old-token',
      refreshAccessToken: () async => 'new-token',
      httpClient: MockClient((request) async {
        sentTokens.add(request.headers['authorization']!);
        calls++;
        return calls == 1
            ? http.Response('expired', 401)
            : http.Response(
                '{"type":"مصروف","amount":1000,"desc":"بنزين"}',
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
      }),
    );

    final result = await backend.parseCommand('مصروف بنزين');

    expect(result?['amount'], 1000);
    expect(sentTokens, ['Bearer old-token', 'Bearer new-token']);
    expect(calls, 2);
  });
}
