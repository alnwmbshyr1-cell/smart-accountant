import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseService service;

  Future<void> resetDatabase() async {
    service = DatabaseService();
    await service.closeForTesting();
    final databasePath = path.join(
      await getDatabasesPath(),
      'smart_accountant_v3.db',
    );
    await deleteDatabase(databasePath);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await resetDatabase();
    service = DatabaseService();
  });

  tearDown(() async {
    await service.closeForTesting();
    SharedPreferences.setMockInitialValues({});
  });

  test('creates the database and returns an empty transaction page', () async {
    expect(await service.getTransactions(), isEmpty);
    expect(await service.getTransactionsPage(limit: 10), isEmpty);
    expect(await service.getBalance(), 0);
    expect(await service.getTodayTotal('مصروف'), 0);
  });

  test('adds a transaction and returns it from list and search', () async {
    await service.addTransaction(
      type: 'مبيعات',
      amount: 125000,
      description: 'بيع بضاعة',
    );

    final rows = await service.getTransactions();
    expect(rows, hasLength(1));
    expect(rows.single['type'], 'مبيعات');
    expect(rows.single['amount'], 125000);
    expect(rows.single['description'], 'بيع بضاعة');
    expect(rows.single['is_seed'], 0);

    final byDescription = await service.searchTransactions('بضاعة');
    final byType = await service.searchTransactions('مبيعات');
    expect(byDescription, hasLength(1));
    expect(byType, hasLength(1));
  });

  test('inserts a batch with default and explicit seed flags', () async {
    await service.insertBatchTransactions([
      <String, dynamic>{
        'type': 'مشتريات',
        'amount': 50000,
        'description': 'مواد',
        'date': '2026-01-01T10:00:00.000',
      },
      <String, dynamic>{
        'type': 'مخزون',
        'amount': 7,
        'description': 'أصناف',
        'date': '2026-01-02T10:00:00.000',
        'is_seed': 0,
      },
    ]);

    final rows = await service.getTransactionsPage(limit: 10);
    expect(rows, hasLength(2));
    expect(rows.map((row) => row['type']), containsAll(['مشتريات', 'مخزون']));
    expect(rows.map((row) => row['is_seed']), containsAll([1, 0]));
  });

  test('supports keyset pagination without duplicates', () async {
    await service.insertBatchTransactions([
      <String, dynamic>{
        'type': 'مصروف',
        'amount': 100,
        'description': 'الأول',
        'date': '2026-03-03T10:00:00.000',
      },
      <String, dynamic>{
        'type': 'مصروف',
        'amount': 200,
        'description': 'الثاني',
        'date': '2026-03-02T10:00:00.000',
      },
      <String, dynamic>{
        'type': 'مصروف',
        'amount': 300,
        'description': 'الثالث',
        'date': '2026-03-01T10:00:00.000',
      },
    ]);

    final first = await service.getTransactionsPage(limit: 2);
    expect(first, hasLength(2));
    final second = await service.getTransactionsPage(
      limit: 2,
      lastDate: first.last['date'] as String,
      lastId: first.last['id'] as String,
    );
    expect(second, hasLength(1));
    expect(second.single['description'], 'الثالث');
    expect(first.map((row) => row['id']), isNot(contains(second.single['id'])));
  });

  test('deletes only seed transactions', () async {
    await service.addTransaction(
      type: 'مصروف',
      amount: 1000,
      description: 'غير تجريبي',
    );
    await service.insertBatchTransactions([
      <String, dynamic>{
        'type': 'مصروف',
        'amount': 2000,
        'description': 'تجريبي',
      },
    ]);

    expect(await service.deleteSeedTransactions(), 1);
    final rows = await service.getTransactions();
    expect(rows, hasLength(1));
    expect(rows.single['description'], 'غير تجريبي');
  });

  test('calculates today totals and balance for income and expenses', () async {
    await service.addTransaction(
      type: 'مبيعات',
      amount: 100000,
      description: 'مبيعات اليوم',
    );
    await service.addTransaction(
      type: 'مصروف',
      amount: 25000,
      description: 'مصروف اليوم',
    );
    await service.addTransaction(
      type: 'دين لك',
      amount: 10000,
      description: 'دين لي',
    );
    await service.addTransaction(
      type: 'دين عليك',
      amount: 5000,
      description: 'دين علي',
    );

    expect(await service.getTodayTotal('مبيعات'), 100000);
    expect(await service.getTodayTotal('مصروف'), 25000);
    expect(await service.getBalance(), 80000);
  });

  test('builds monthly profit summaries in chronological order', () async {
    await service.insertBatchTransactions([
      <String, dynamic>{
        'type': 'مبيعات',
        'amount': 300000,
        'description': 'يناير',
        'date': '2026-01-15T10:00:00.000',
        'is_seed': 0,
      },
      <String, dynamic>{
        'type': 'مصروف',
        'amount': 100000,
        'description': 'يناير',
        'date': '2026-01-20T10:00:00.000',
        'is_seed': 0,
      },
      <String, dynamic>{
        'type': 'مبيعات',
        'amount': 500000,
        'description': 'فبراير',
        'date': '2026-02-15T10:00:00.000',
        'is_seed': 0,
      },
    ]);

    final rows = await service.getMonthlyProfitSummary(months: 2);
    expect(rows, hasLength(2));
    expect(rows.first['month'], '2026-01');
    expect(rows.first['sales'], 300000);
    expect(rows.first['expenses'], 100000);
    expect(rows.first['profit'], 200000);
    expect(rows.last['month'], '2026-02');
  });

  test('migrates valid legacy rows and ignores malformed rows', () async {
    SharedPreferences.setMockInitialValues({
      'smart_accountant_transactions': [
        '{"id":"legacy-1","type":"مصروف","amount":750,"description":"قديم","date":"2026-04-01T00:00:00.000","is_seed":true}',
        '{not valid json}',
      ],
    });

    await service.migrateFromSharedPreferencesIfNeeded();
    final rows = await service.getTransactions();
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'legacy-1');
    expect(rows.single['is_seed'], 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('smart_accountant_transactions'), isNull);
  });

  test('limits transaction list and returns no matches for unknown search',
      () async {
    await service.insertBatchTransactions(List.generate(
      5,
      (index) => <String, dynamic>{
        'type': 'مصروف',
        'amount': index + 1,
        'description': 'بند $index',
        'date':
            '2026-05-${(index + 1).toString().padLeft(2, '0')}T00:00:00.000',
      },
    ));

    expect((await service.getTransactions()).length, 5);
    expect(await service.searchTransactions('غير موجود'), isEmpty);
    expect((await service.getTransactionsPage(limit: 2)).length, 2);
  });
}
