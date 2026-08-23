import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:smart_accountant/sync_service.dart';

class FakeClient extends http.BaseClient {
  FakeClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest request) handler;
  http.BaseRequest? lastRequest;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    lastBody = await request.finalize().bytesToString();
    final response = await handler(request);
    return http.StreamedResponse(Stream.value(response.bodyBytes), response.statusCode, headers: response.headers, request: request);
  }
}

void main() {
  test('pushTable sends owner_id and upsert conflict query', () async {
    final client = FakeClient((_) async => http.Response('', 201));
    final service = MaqaniSyncService(baseUrl: 'https://example.supabase.co', publishableKey: 'fake-key', userId: 'user-a', client: client);

    await service.pushTable('animals', [{'local_id': 7, 'number': '102', 'updated_at': '2026-08-23T09:00:00Z'}]);

    expect(client.lastRequest?.url.queryParameters['on_conflict'], 'owner_id,local_id');
    expect(client.lastRequest?.headers['apikey'], 'fake-key');
    final payload = jsonDecode(client.lastBody!) as List;
    expect(payload.single['owner_id'], 'user-a');
    expect(payload.single['local_id'], 7);
  });

  test('pullTable filters rows by owner and decodes response', () async {
    final client = FakeClient((request) async {
      expect(request.url.queryParameters['owner_id'], 'eq.user-a');
      expect(request.url.queryParameters['updated_at'], 'gt.2026-08-22T00:00:00.000Z');
      return http.Response(jsonEncode([{'local_id': 9, 'owner_id': 'user-a'}]), 200);
    });
    final service = MaqaniSyncService(baseUrl: 'https://example.supabase.co', publishableKey: 'fake-key', userId: 'user-a', client: client);

    final rows = await service.pullTable('health_records', changedAfter: DateTime.utc(2026, 8, 22));

    expect(rows, hasLength(1));
    expect(rows.single['local_id'], 9);
  });

  test('pushTable reports server failures instead of marking data synced', () async {
    final client = FakeClient((_) async => http.Response('{"message":"denied"}', 403));
    final service = MaqaniSyncService(baseUrl: 'https://example.supabase.co', publishableKey: 'fake-key', userId: 'user-a', client: client);

    expect(() => service.pushTable('financial_entries', [{'local_id': 1}]), throwsException);
  });
}
