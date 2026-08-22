import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/yemeni_dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/services/gemini_service.dart';

class OfflineGeminiService extends GeminiService {
  OfflineGeminiService() : super();

  @override
  Future<Map<String, dynamic>?> processCommand(String text) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final aiAgent = AiAgentService(gemini: OfflineGeminiService());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      final db = await DatabaseService().database;
      await db.delete('transactions');
    } catch (_) {}
  });

  tearDown(() async {
    await DatabaseService().closeForTesting();
  });

  group('v3.1.0 Indexed SQLite & Yemeni Dialect Tests', () {
    test('Verify Yemeni Dictionary normalization for local slang terms', () {
      expect(YemeniDictionary.normalizeYemeniText('بعت بضاعة'), 'مبيعات بضاعة');
      expect(
          YemeniDictionary.normalizeYemeniText('اشتريت دبات'), 'مشتريات دبات');
      expect(YemeniDictionary.normalizeYemeniText('صرفت عشرين ألف'),
          'مصروف عشرين ألف');
    });

    test('Parse Yemeni Dialect Voice Command to JSON structure', () {
      var json1 = aiAgent.parseCommandToJson('بعت بضاعة بمئة ألف');
      expect(json1['النوع'], 'مبيعات');
      expect(json1['المبلغ'], 100000.0);

      var json2 = aiAgent.parseCommandToJson('اشتريت عشرة آلاف');
      expect(json2['النوع'], 'مشتريات');
      expect(json2['المبلغ'], 10000.0);

      var json3 = aiAgent.parseCommandToJson('صرفت عشرين ألف بنزين');
      expect(json3['النوع'], 'مصروف');
      expect(json3['المبلغ'], 20000.0);
    });

    test(
        'Process voice command using Yemeni dictionary with Indexed SQLite persistence',
        () async {
      String lastReply = '';
      var result =
          await aiAgent.processVoiceCommandText('بعت بضاعة بمئة ألف', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'add_sale');
      expect(result['amount'], 100000.0);
      expect(result['targetTab'], 1);
      expect(lastReply.contains('مبيعات'), true);
    });
  });

  test('Parse debt receivable, debt payable, purchase, and inventory commands',
      () {
    final debtReceivable =
        aiAgent.parseCommandToJson('دين لي على خالد بمئة ألف');
    expect(debtReceivable['النوع'], 'دين_لي');
    expect(debtReceivable['المبلغ'], 100000.0);

    final debtPayable = aiAgent.parseCommandToJson('علي دين للمورد بعشرة آلاف');
    expect(debtPayable['النوع'], 'دين_علي');
    expect(debtPayable['المبلغ'], 10000.0);

    final purchase = aiAgent.parseCommandToJson('اشتريت بضاعة بخمسين ألف');
    expect(purchase['النوع'], 'مشتريات');
    expect(purchase['المبلغ'], 50000.0);

    final inventory = aiAgent.parseCommandToJson('أضف عشرة أصناف للمخزن');
    expect(inventory['النوع'], 'مخزون');
  });

  test('Reject command without a positive amount', () {
    final result = aiAgent.parseCommandToJson('سجل مصروف بنزين');
    expect(result['المبلغ'], 0.0);
  });

  test('Process daily expense report and return the calculated result',
      () async {
    final db = DatabaseService();
    await db.addTransaction(
      type: 'مصروف',
      amount: 25000,
      description: 'بنزين',
    );
    String reply = '';

    final result = await aiAgent.processVoiceCommandText(
      'كم صرفت اليوم',
      (value) => reply = value,
    );

    expect(result['action'], 'get_report');
    expect((result['result'] as num), greaterThanOrEqualTo(25000));
    expect(reply, contains('صرف'));
  });

  test('Search command returns matching local transactions', () async {
    final db = DatabaseService();
    await db.addTransaction(
      type: 'مصروف',
      amount: 18000,
      description: 'بنزين السيارة',
    );
    String reply = '';

    final result = await aiAgent.processVoiceCommandText(
      'ابحث عن بنزين',
      (value) => reply = value,
    );

    expect(result['action'], 'search');
    expect((result['results'] as List), isNotEmpty);
    expect(reply, contains('عمليات مطابقة'));
  });

  test('Process all supported local operation types and select their tabs',
      () async {
    final commands = <String, Map<String, dynamic>>{
      'بعت بضاعة بمئة ألف': {'action': 'add_sale', 'tab': 1},
      'اشتريت بضاعة بخمسين ألف': {'action': 'add_purchase', 'tab': 1},
      'دين لي على خالد بعشرة آلاف': {
        'action': 'add_debt_receivable',
        'tab': 2,
      },
      'علي دين للمورد بعشرين ألف': {
        'action': 'add_debt_payable',
        'tab': 2,
      },
      'أضف خمسة أصناف للمخزن': {'action': 'add_inventory', 'tab': 3},
      'سجل مصروف بنزين بثلاثة آلاف': {'action': 'add_expense', 'tab': 0},
    };

    for (final entry in commands.entries) {
      final result = await aiAgent.processVoiceCommandText(
        entry.key,
        (_) {},
      );
      expect(result['action'], entry.value['action'], reason: entry.key);
      expect(result['targetTab'], entry.value['tab'], reason: entry.key);
      expect((result['amount'] as num), greaterThan(0), reason: entry.key);
    }
  });

  test('Ask for amount when a command has no positive amount', () async {
    String reply = '';
    final result = await aiAgent.processVoiceCommandText(
      'سجل مصروف بنزين',
      (value) => reply = value,
    );

    expect(result['action'], 'needs_amount');
    expect(reply, contains('المبلغ'));
  });
}
