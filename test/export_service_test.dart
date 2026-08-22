import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_accountant/export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const documentsDirectory = '/tmp/smart-accountant-export-tests';
  Directory(documentsDirectory).createSync(recursive: true);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return documentsDirectory;
      }
      return null;
    },
  );

  test('exports Arabic transaction rows to a non-empty Excel file', () async {
    final file = await ExportService.exportToExcel([
      <String, dynamic>{
        'type': 'مصروف',
        'description': 'بنزين',
        'amount': 25000,
        'date': '2026-08-22',
      },
    ]);

    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    expect(file.path, endsWith('.xlsx'));
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
  });

  test('exports an empty Excel workbook with headers', () async {
    final file = await ExportService.exportToExcel(const []);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });

    final directory = await getApplicationDocumentsDirectory();
    expect(file.parent.path, directory.path);
    expect(await file.length(), greaterThan(0));
  });
}
