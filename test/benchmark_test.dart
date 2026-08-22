import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/gemma_isolate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('v3.2.0 Memory & Performance Benchmark Tests', () {
    test('Verify Keyset Pagination fetches pages correctly without loading all records', () async {
      final dbService = DatabaseService();

      await dbService.insertBatchTransactions([
        {'type': 'مبيعات', 'amount': 1000.0, 'description': 'اختبار 1', 'date': '2026-08-22T12:00:00.000', 'is_seed': 1},
        {'type': 'مشتريات', 'amount': 2000.0, 'description': 'اختبار 2', 'date': '2026-08-22T11:00:00.000', 'is_seed': 1},
        {'type': 'مصروف', 'amount': 500.0, 'description': 'اختبار 3', 'date': '2026-08-22T10:00:00.000', 'is_seed': 1},
      ]);

      final page1 = await dbService.getTransactionsPage(limit: 2);
      expect(page1.length, 2);
      expect(page1[0]['description'], 'اختبار 1');

      final lastItem = page1.last;
      final page2 = await dbService.getTransactionsPage(
        limit: 2,
        lastDate: lastItem['date'],
        lastId: lastItem['id'].toString(),
      );

      expect(page2.length, 1);
      expect(page2[0]['description'], 'اختبار 3');
    });

    test('Verify Gemma Isolate processes command and returns JSON safely', () async {
      await GemmaIsolateService.initIsolate();
      
      final result = await GemmaIsolateService.processCommandInIsolate('مبيعات بمليون ريال');
      expect(result['النوع'], 'مبيعات');
      expect(result['المبلغ'], 1000000.0);

      GemmaIsolateService.dispose();
    });
  });
}
