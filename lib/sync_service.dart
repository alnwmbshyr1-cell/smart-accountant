import 'dart:convert';
import 'package:http/http.dart' as http;

/// مزامنة SQLite مع Supabase Data API أو أي خادم REST متوافق مع upsert.
/// لا تستخدم service_role_key داخل تطبيق Android؛ استخدم publishable/anon key مع RLS.
class MaqaniSyncService {
  MaqaniSyncService({required this.baseUrl, required this.publishableKey, required this.userId, http.Client? client}) : _client = client ?? http.Client();

  final String baseUrl;
  final String publishableKey;
  final String userId;
  final http.Client _client;

  Map<String, String> get _headers => {
        'apikey': publishableKey,
        'Authorization': 'Bearer $publishableKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
      };

  Future<void> pushTable(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final payload = rows.map((row) => {...row, 'owner_id': userId}).toList();
    final response = await _client.post(Uri.parse('$baseUrl/rest/v1/$table?on_conflict=owner_id,local_id'), headers: _headers, body: jsonEncode(payload));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل رفع جدول $table: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> pullTable(String table, {DateTime? changedAfter}) async {
    final params = <String, String>{'owner_id': 'eq.$userId', 'select': '*', 'order': 'updated_at.asc'};
    if (changedAfter != null) params['updated_at'] = 'gt.${changedAfter.toUtc().toIso8601String()}';
    final uri = Uri.parse('$baseUrl/rest/v1/$table').replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('فشل تنزيل جدول $table: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> sync({required Map<String, List<Map<String, dynamic>>> localTables}) async {
    for (final entry in localTables.entries) {
      await pushTable(entry.key, entry.value);
    }
  }
}
