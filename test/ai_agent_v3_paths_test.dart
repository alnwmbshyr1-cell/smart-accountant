import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/services/gemini_service.dart';

class NullGemini extends GeminiService {
  @override
  Future<Map<String, dynamic>?> processCommand(String text) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final db = DatabaseService();
    final raw = await db.database;
    for (final table in [
      'transactions',
      'expenses',
      'purchases',
      'sales',
      'debt_for_me',
      'debt_on_me',
      'inventory',
    ]) {
      await raw.delete(table);
    }
  });

  tearDown(() => DatabaseService().closeForTesting());

  test('assistant state controls and Arabic numeric parsing are deterministic',
      () {
    final service = AiAgentService(gemini: NullGemini());
    expect(service.isListening, isFalse);
    expect(service.isAssistantMode, isFalse);

    service.startAssistant();
    expect(service.isListening, isTrue);
    expect(service.isAssistantMode, isTrue);
    service.stopAssistant();
    expect(service.isListening, isFalse);
    expect(service.isAssistantMode, isFalse);

    expect(service.parseArabicNumber('خمسة عشر الف'), 15000);
    expect(service.parseArabicNumber('12,500 ريال'), 12500);
    expect(service.parseArabicNumber('لا يوجد مبلغ'), 0);
  });

  test('report aliases return the same daily expense result', () async {
    final db = DatabaseService();
    await db.addTransaction(type: 'مصروف', amount: 7500, description: 'بنزين');
    final service = AiAgentService(gemini: NullGemini());

    for (final command in ['تقرير اليوم', 'المصروفات اليومية', 'صرفت اليوم']) {
      final result = await service.processVoiceCommandText(command, (_) {});
      expect(result['action'], 'get_report', reason: command);
      expect((result['result'] as num), greaterThanOrEqualTo(7500));
    }
  });

  test('search aliases and empty search remain offline', () async {
    final db = DatabaseService();
    await db.addTransaction(type: 'مصروف', amount: 100, description: 'ماء');
    final service = AiAgentService(gemini: NullGemini());

    final result = await service.processVoiceCommandText('وين ماء', (_) {});
    expect(result['action'], 'search');
    expect(result['results'], isA<List>());

    final empty = await service.processVoiceCommandText('بحث', (_) {});
    expect(empty['action'], 'search');
  });

  test('completes a compound inventory command through the service', () async {
    final service = AiAgentService(gemini: NullGemini());
    final result = await service.processVoiceCommandText(
      'سجل في المخزون 4 كراتين ماء الكرتون بعشرين الف',
      (_) {},
    );

    expect(result['action'], 'add_inventory');
    expect(result['amount'], 80000.0);
    final rows = await DatabaseService().getStructuredRecords('مخزون');
    expect(rows.single['item'], 'ماء');
    expect(rows.single['total'], 80000.0);
  });
}
