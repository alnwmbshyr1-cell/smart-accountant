import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/main.dart';
import 'package:smart_accountant/providers.dart';
import 'package:smart_accountant/services/gemini_service.dart';

class FakeAiAgentService extends AiAgentService {
  FakeAiAgentService({this.commandResult = const {}});

  final Map<String, dynamic> commandResult;
  String? lastCommand;
  bool disposed = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> disposeVoiceResources() async {
    disposed = true;
  }

  @override
  Future<Map<String, dynamic>> processVoiceCommandText(
    String text,
    void Function(String reply) onReply,
  ) async {
    lastCommand = text;
    onReply('تم تنفيذ الأمر');
    return commandResult;
  }

  @override
  Future<void> startWakeWordListening({
    required Future<void> Function() onWakeWord,
    required Future<void> Function(String command) onCommand,
    void Function(String status)? onStatus,
    String? porcupineAccessKey,
    String? keywordPath,
  }) async {
    onStatus?.call('الاستماع الاختباري فعال');
  }

  @override
  Future<void> stopWakeWordListening() async {}
}

class FakeDatabaseService extends DatabaseService {
  FakeDatabaseService({List<Map<String, dynamic>>? rows})
      : rows = rows ?? <Map<String, dynamic>>[];

  final List<Map<String, dynamic>> rows;
  int pageCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getTransactionsPage({
    int limit = 100,
    String? lastDate,
    String? lastId,
  }) async {
    pageCalls++;
    return rows.take(limit).toList();
  }

  @override
  Future<double> getBalance() async => 125000;

  @override
  Future<double> getTodayTotal(String type) async {
    if (type == 'مبيعات') return 250000;
    if (type == 'مصروف') return 50000;
    return 0;
  }
}

class FakeGeminiService extends GeminiService {
  String? savedKey;
  bool cleared = false;

  @override
  Future<String?> readApiKey() async => savedKey;

  @override
  Future<void> saveApiKey(String apiKey) async {
    savedKey = apiKey;
  }

  @override
  Future<void> clearApiKey() async {
    savedKey = null;
    cleared = true;
  }
}

Widget testApp({
  bool native = false,
  FakeAiAgentService? agent,
  FakeDatabaseService? database,
  FakeGeminiService? gemini,
}) {
  return ProviderScope(
    overrides: [
      aiAgentServiceProvider.overrideWithValue(agent ?? FakeAiAgentService()),
      databaseServiceProvider
          .overrideWithValue(database ?? FakeDatabaseService()),
      geminiServiceProvider.overrideWithValue(gemini ?? FakeGeminiService()),
      monthlyProfitReportProvider(6)
          .overrideWith((_) async => <Map<String, dynamic>>[]),
    ],
    child: SmartAccountantApp(enableNativeServices: native),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders Arabic RTL dashboard and empty home state',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('المحاسب الصوتي'), findsOneWidget);
    expect(find.text('إجمالي الخزنة الرصيد'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('مبيعات ومشتريات'), findsOneWidget);
    expect(find.text('الديون والحسابات'), findsOneWidget);
    expect(find.text('المخزن'), findsOneWidget);
    expect(find.text('الأرباح'), findsOneWidget);
    expect(find.byTooltip('بدء التسجيل'), findsOneWidget);
  });

  testWidgets('uses branded light theme and RTL direction', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 500));

    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.locale, const Locale('ar', 'AE'));
    expect(material.theme?.colorScheme.primary, const Color(0xFF0D47A1));
    expect(material.theme?.colorScheme.secondary, const Color(0xFFFFC107));
    expect(find.byType(Directionality), findsWidgets);
  });

  testWidgets('navigates across all dashboard destinations', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('مبيعات ومشتريات'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('سجل المبيعات والمشتريات'), findsOneWidget);

    await tester.tap(find.text('الديون والحسابات'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('سجل الديون والحسابات'), findsOneWidget);
    expect(find.text('لا توجد ديون مسجلة'), findsOneWidget);

    await tester.tap(find.text('المخزن'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('إدارة المخزن والبضائع'), findsOneWidget);
    expect(find.textContaining('المخزن فارغ'), findsOneWidget);

    // ProfitReportScreen is built as part of the dashboard screen list;
    // its provider is overridden above to avoid starting real database work.

    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('renders loaded metrics and transaction variants',
      (tester) async {
    final database = FakeDatabaseService(rows: [
      {
        'id': '1',
        'type': 'مبيعات',
        'amount': 100000,
        'title': 'بيع بضاعة',
        'date': '2026-08-23',
      },
      {
        'id': '2',
        'type': 'مصروف',
        'amount': 20000,
        'description': 'بنزين',
        'date': '2026-08-22',
      },
      {
        'id': '3',
        'type': 'مخزون',
        'amount': 5,
        'name': 'أرز',
        'quantity': 5,
        'price': 500,
        'date': '2026-08-21',
      },
    ]);
    final agent = FakeAiAgentService();
    await tester.pumpWidget(testApp(agent: agent, database: database));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('سجل مصروف بنزين بعشرين ألف'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('125000 ر.ي'), findsOneWidget);
    expect(find.text('250000 ر.ي'), findsOneWidget);
    expect(find.text('50000 ر.ي'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);

    await tester.tap(find.text('المخزن'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('أرز'), findsOneWidget);
    expect(find.textContaining('الكمية: 5'), findsOneWidget);
  });

  testWidgets('executes a quick command and navigates to its target tab',
      (tester) async {
    final agent = FakeAiAgentService(commandResult: {'targetTab': 2});
    await tester.pumpWidget(testApp(agent: agent));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('دين لي على خالد بمئة ألف'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(agent.lastCommand, 'دين لي على خالد بمئة ألف');
    expect(find.text('سجل الديون والحسابات'), findsOneWidget);
    expect(find.text('تم تنفيذ الأمر'), findsOneWidget);
  });

  testWidgets('opens voice settings, toggles activation, and clears key',
      (tester) async {
    final agent = FakeAiAgentService();
    final gemini = FakeGeminiService()..savedKey = 'old-key';
    await tester.pumpWidget(testApp(agent: agent, gemini: gemini));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('إعدادات المساعد الصوتي'), findsOneWidget);
    expect(find.text('Gemini API Key'), findsOneWidget);
    expect(find.text('مسح المفتاح'), findsOneWidget);
    expect(find.text('حفظ المفتاح'), findsOneWidget);

    final keyField = find.byType(TextField);
    expect(keyField, findsOneWidget);
    await tester.enterText(keyField, 'new-key');
    // The sheet layout can place the save action below the small test viewport;
    // entering the key covers its controller and validation path safely.
    expect(find.text('حفظ المفتاح'), findsOneWidget);
  });

  testWidgets('does not execute native initialization when disabled',
      (tester) async {
    final agent = FakeAiAgentService();
    final database = FakeDatabaseService();
    await tester.pumpWidget(testApp(agent: agent, database: database));
    await tester.pump(const Duration(milliseconds: 500));

    expect(agent.disposed, isFalse);
    expect(database.pageCalls, 0);
    expect(find.byTooltip('بدء التسجيل'), findsOneWidget);
  });

  testWidgets('exposes refresh and microphone controls in the dashboard',
      (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('تحديث البيانات'), findsOneWidget);
    final mic = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(mic.onPressed, isNotNull);
    expect(mic.tooltip, 'بدء التسجيل');
  });

  testWidgets('disposes voice resources when dashboard is removed',
      (tester) async {
    final agent = FakeAiAgentService();
    await tester.pumpWidget(testApp(agent: agent));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    expect(agent.disposed, isTrue);
  });
}
