import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/export_service.dart';
import 'package:smart_accountant/services/gemini_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class OfflineGeminiForIntegration extends GeminiService {
  OfflineGeminiForIntegration() : super();

  @override
  Future<Map<String, dynamic>?> processCommand(String text) async => null;
}

class FakeVoskTranscriptSource {
  FakeVoskTranscriptSource(this.transcript);

  final String transcript;

  Future<String> captureTenSeconds() async => transcript;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const documentsDirectory = '/tmp/smart-accountant-integration-tests';
  Directory(documentsDirectory).createSync(recursive: true);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => call.method == 'getApplicationDocumentsDirectory'
          ? documentsDirectory
          : null,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = await DatabaseService().database;
    await db.delete('transactions');
  });

  tearDown(() async {
    await DatabaseService().closeForTesting();
  });

  test(
      'runs Yemeni Vosk transcript through offline AI, SQLite, and Excel export',
      () async {
    final vosk = FakeVoskTranscriptSource('سجل مصروف بنزين بعشرين ألف');
    final agent = AiAgentService(gemini: OfflineGeminiForIntegration());
    String spokenReply = '';

    final transcript = await vosk.captureTenSeconds();
    final result = await agent.processVoiceCommandText(transcript, (reply) {
      spokenReply = reply;
    });

    expect(result['action'], 'add_expense');
    expect(result['amount'], 20000);
    expect(result['source'], 'local_fallback');
    expect(spokenReply, contains('20000'));

    final db = DatabaseService();
    final saved = await db.searchTransactions('بنزين');
    expect(saved, hasLength(1));
    expect(saved.single['type'], 'مصروف');
    expect(saved.single['amount'], 20000);

    final file = await ExportService.exportToExcel(saved);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    expect(file.path, endsWith('.xlsx'));
    expect(await file.length(), greaterThan(0));
  });

  test('preserves workflow for a sale and reports the persisted total',
      () async {
    final vosk = FakeVoskTranscriptSource('بعت بضاعة بمئة ألف');
    final agent = AiAgentService(gemini: OfflineGeminiForIntegration());
    final replies = <String>[];

    final result = await agent.processVoiceCommandText(
      await vosk.captureTenSeconds(),
      replies.add,
    );

    expect(result['action'], 'add_sale');
    expect(result['targetTab'], 1);
    expect(result['amount'], 100000);
    expect(replies.single, contains('إجمالي مبيعات اليوم 100000'));

    final rows = await DatabaseService().getTransactionsPage(limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single['type'], 'مبيعات');
  });

  test('does not persist an incomplete voice command', () async {
    final vosk = FakeVoskTranscriptSource('سجل مصروف بنزين');
    final agent = AiAgentService(gemini: OfflineGeminiForIntegration());
    String reply = '';

    final result = await agent.processVoiceCommandText(
      await vosk.captureTenSeconds(),
      (value) => reply = value,
    );

    expect(result['action'], 'needs_amount');
    expect(reply, contains('كم المبلغ'));
    expect(await DatabaseService().getTransactions(), isEmpty);
  });
}
