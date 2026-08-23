@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/export_service.dart';
import 'package:smart_accountant/services/audio_ports.dart';
import 'package:smart_accountant/services/gemini_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class OfflineGeminiIntegration extends GeminiService {
  OfflineGeminiIntegration(this.response);

  final Map<String, dynamic>? response;

  @override
  Future<Map<String, dynamic>?> processCommand(String text) async => response;
}

class IntegrationTts implements TtsPort {
  final spoken = <String>[];

  @override
  Future<dynamic> setLanguage(String language) async => true;

  @override
  Future<dynamic> setSpeechRate(double rate) async => true;

  @override
  Future<dynamic> setPitch(double pitch) async => true;

  @override
  Future<dynamic> speak(String text) async {
    spoken.add(text);
    return true;
  }
}

class ImmediateIntegrationDelay implements DelayPort {
  @override
  Future<void> wait(Duration duration) async {}
}

class IntegrationSpeechCapture implements VoskSpeechCapturePort {
  final partials = StreamController<String>.broadcast();
  final results = StreamController<String>.broadcast();
  int startCount = 0;
  int stopCount = 0;

  @override
  Stream<String> onPartial() => partials.stream;

  @override
  Stream<String> onResult() => results.stream;

  @override
  Future<bool?> start() async {
    startCount++;
    return true;
  }

  @override
  Future<bool?> stop() async {
    stopCount++;
    return true;
  }

  @override
  Future<void> dispose() async {
    await partials.close();
    await results.close();
  }
}

class IntegrationVosk implements VoskServicePort {
  IntegrationVosk(this.capture, this.finalResult);

  final IntegrationSpeechCapture capture;
  final String finalResult;
  int initCount = 0;
  int stopCount = 0;

  @override
  Future<void> init() async {
    initCount++;
  }

  @override
  Future<VoskSpeechCapturePort> ensureSpeechService() async => capture;

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<String> getFinalResult() async => finalResult;

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const documentsDirectory = '/tmp/smart-accountant-full-integration';
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

  test('captures, processes, persists, reports, and exports a sale', () async {
    final capture = IntegrationSpeechCapture();
    final vosk = IntegrationVosk(capture, '{"text":"بعت بضاعة بمئة ألف"}');
    final tts = IntegrationTts();
    final agent = AiAgentService(
      gemini: OfflineGeminiIntegration(null),
      voskService: vosk,
      tts: tts,
      delay: ImmediateIntegrationDelay(),
    );
    final replies = <String>[];

    final transcript = await agent.startListening10Seconds();
    final result =
        await agent.processVoiceCommandText(transcript!, replies.add);

    expect(result['action'], 'add_sale');
    expect(result['amount'], 100000);
    expect(vosk.initCount, greaterThanOrEqualTo(2));
    expect(capture.startCount, 1);
    expect(capture.stopCount, 1);
    expect(tts.spoken, isNotEmpty);
    expect(replies.single, contains('إجمالي مبيعات اليوم 100000'));

    final db = DatabaseService();
    final rows = await db.getTransactionsPage(limit: 10);
    expect(rows, hasLength(1));
    expect(rows.single['type'], 'مبيعات');
    expect(await db.getTodayTotal('مبيعات'), 100000);

    final pdf = await const ExportService().buildInvoicePdf(rows);
    expect(pdf, isNotEmpty);
    final excel = await const ExportService().exportToExcel(rows);
    addTearDown(() async {
      if (await excel.exists()) await excel.delete();
      await capture.dispose();
    });
    expect(excel.path, endsWith('.xlsx'));
    expect(await excel.length(), greaterThan(0));
  });

  test('searches persisted transactions and returns a daily expense report',
      () async {
    final db = DatabaseService();
    await db.addTransaction(
      type: 'مصروف',
      amount: 25000,
      description: 'بنزين السيارة',
    );
    await db.addTransaction(
      type: 'مشتريات',
      amount: 50000,
      description: 'بضاعة المتجر',
    );
    final agent = AiAgentService(gemini: OfflineGeminiIntegration(null));

    final searchReply = <String>[];
    final search = await agent.processVoiceCommandText(
      'ابحث عن بنزين',
      searchReply.add,
    );
    final reportReply = <String>[];
    final report = await agent.processVoiceCommandText(
      'كم صرفت اليوم',
      reportReply.add,
    );

    expect(search['action'], 'search');
    expect(search['results'], hasLength(1));
    expect(searchReply.single, contains('عمليات مطابقة'));
    expect(report['action'], 'get_report');
    expect(report['result'], 25000);
    expect(reportReply.single, contains('25000'));
  });

  test('does not persist an incomplete command across the full workflow',
      () async {
    final capture = IntegrationSpeechCapture();
    final vosk = IntegrationVosk(capture, '{"text":"سجل مصروف بنزين"}');
    final agent = AiAgentService(
      gemini: OfflineGeminiIntegration(null),
      voskService: vosk,
      tts: IntegrationTts(),
      delay: ImmediateIntegrationDelay(),
    );
    String reply = '';

    final transcript = await agent.startListening10Seconds();
    final result = await agent.processVoiceCommandText(
      transcript!,
      (value) => reply = value,
    );

    expect(result['action'], 'needs_amount');
    expect(reply, contains('كم المبلغ'));
    expect(await DatabaseService().getTransactions(), isEmpty);
    await capture.dispose();
  });
}
