import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_accountant/ai_agent_parser.dart';
import 'package:smart_accountant/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final commands = <String, Map<String, dynamic>>{
    'سجل مصروف الف ريال': {
      'type': 'مصروف',
      'amount': 1000.0,
      'description': 'مصروف',
    },
    'سجل مصروف شراء بنزين 500': {
      'type': 'مصروف',
      'amount': 500.0,
      'description': 'بنزين',
    },
    'سجل مشتريات عشرين الف': {
      'type': 'مشتريات',
      'amount': 20000.0,
    },
    'سجل مشتريات 10 اكياس رز كل كيس 15000': {
      'type': 'مشتريات',
      'amount': 150000.0,
      'quantity': 10.0,
      'unit_price': 15000.0,
      'item': 'اكياس رز',
    },
    'سجل مبيعات خمسين الف': {
      'type': 'مبيعات',
      'amount': 50000.0,
    },
    'سجل مبيعات بيع 3 جوالات كل واحد 200000': {
      'type': 'مبيعات',
      'amount': 600000.0,
      'quantity': 3.0,
      'unit_price': 200000.0,
      'item': 'جوالات',
    },
    'سجل دين لي على احمد خمسين الف': {
      'type': 'دين_لي',
      'amount': 50000.0,
      'person': 'احمد',
    },
    'سجل دين علي لمحمد عشرين الف': {
      'type': 'دين_علي',
      'amount': 20000.0,
      'person': 'محمد',
    },
    'سجل في المخزون 4 كراتين ماء الكرتون بعشرين الف': {
      'type': 'مخزون',
      'amount': 80000.0,
      'quantity': 4.0,
      'unit_price': 20000.0,
      'item': 'كراتين ماء',
    },
  };

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

  tearDown(() async => DatabaseService().closeForTesting());

  test('parses all Arabic v3 command examples with exact totals', () {
    for (final entry in commands.entries) {
      final result = AiAgentParser.parseCommandToJson(entry.key);
      expect(result['type'], entry.value['type'], reason: entry.key);
      expect(result['amount'], entry.value['amount'], reason: entry.key);
      for (final key in ['quantity', 'unit_price', 'item', 'person']) {
        if (entry.value.containsKey(key)) {
          expect(result[key], entry.value[key], reason: '$key: ${entry.key}');
        }
      }
    }
  });

  test('persists every supported category to its dedicated table', () async {
    final db = DatabaseService();
    for (final command in commands.entries) {
      await db.saveParsedCommand(AiAgentParser.parseCommandToJson(command.key));
    }

    expect((await db.getStructuredRecords('مصروف')).length, 2);
    expect((await db.getStructuredRecords('مشتريات')).length, 2);
    expect((await db.getStructuredRecords('مبيعات')).length, 2);
    expect((await db.getStructuredRecords('دين_لي')).single['person'], 'احمد');
    expect((await db.getStructuredRecords('دين_علي')).single['person'], 'محمد');
    final inventory = (await db.getStructuredRecords('مخزون')).single;
    expect(inventory['quantity'], 4.0);
    expect(inventory['unit_price'], 20000.0);
    expect(inventory['total'], 80000.0);
  });

  test('structured daily totals use amount and inventory total correctly',
      () async {
    final db = DatabaseService();
    await db.saveParsedCommand(
        AiAgentParser.parseCommandToJson('سجل مصروف الف ريال'));
    await db.saveParsedCommand(
        AiAgentParser.parseCommandToJson('سجل مبيعات خمسين الف'));
    await db.saveParsedCommand(AiAgentParser.parseCommandToJson(
      'سجل في المخزون 4 كراتين ماء الكرتون بعشرين الف',
    ));

    expect(await db.getStructuredTodayTotal('مصروف'), 1000.0);
    expect(await db.getStructuredTodayTotal('مبيعات'), 50000.0);
    expect(await db.getStructuredTodayTotal('مخزون'), 80000.0);
  });

  test('rejects zero or negative structured commands before insertion',
      () async {
    final db = DatabaseService();
    await expectLater(
      db.saveParsedCommand({'type': 'مصروف', 'amount': 0, 'description': 'x'}),
      throwsA(isA<ArgumentError>()),
    );
    expect(await (await db.database).query('expenses'), isEmpty);
  });
}
