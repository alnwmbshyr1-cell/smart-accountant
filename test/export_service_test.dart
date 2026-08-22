import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:smart_accountant/export_service.dart';
import 'package:smart_accountant/providers.dart';

class RecordingInvoicePrinter implements InvoicePrinter {
  RecordingInvoicePrinter({this.failure});

  final Object? failure;
  int calls = 0;
  List<int>? bytes;

  @override
  Future<void> printPdf(List<int> pdfBytes) async {
    calls++;
    if (failure != null) throw failure!;
    bytes = pdfBytes;
  }
}

class RecordingFileWriter implements FileWriter {
  RecordingFileWriter({this.failure});

  final Object? failure;
  String? fileName;
  List<int>? bytes;

  @override
  Future<File> write(String name, List<int> data) async {
    if (failure != null) throw failure!;
    fileName = name;
    bytes = data;
    return File('/tmp/$name');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const documentsDirectory = '/tmp/smart-accountant-export-tests';
  Directory(documentsDirectory).createSync(recursive: true);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => call.method == 'getApplicationDocumentsDirectory'
        ? documentsDirectory
        : null,
  );

  test('exports Arabic transaction rows to a non-empty Excel file', () async {
    final file = await const ExportService().exportToExcel([
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
    final file = await const ExportService().exportToExcel(const []);
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    expect(file.parent.path, (await getApplicationDocumentsDirectory()).path);
    expect(await file.length(), greaterThan(0));
  });

  test('builds a non-empty PDF through the injected printer', () async {
    final printer = RecordingInvoicePrinter();
    final service = ExportService(printer: printer);
    await service.printInvoice([
      {
        'type': 'مصروف',
        'description': 'بنزين',
        'amount': 20000,
        'date': '2026-08-23',
      },
    ]);
    expect(printer.calls, 1);
    expect(printer.bytes, isNotNull);
    expect(printer.bytes, isNotEmpty);
  });

  test('passes printer exceptions through to the caller', () async {
    final service = ExportService(
      printer: RecordingInvoicePrinter(failure: StateError('printer offline')),
    );
    expect(
      () => service.printInvoice(const []),
      throwsA(isA<StateError>()),
    );
  });

  test('writes Excel bytes through the injected file writer', () async {
    final writer = RecordingFileWriter();
    final service = ExportService(fileWriter: writer);
    final file = await service.exportToExcel([
      {
        'type': 'مبيعات',
        'description': 'بضاعة',
        'amount': 100000,
        'date': '2026-08-23',
      },
    ]);
    expect(file.path, endsWith('.xlsx'));
    expect(writer.fileName, endsWith('.xlsx'));
    expect(writer.bytes, isNotEmpty);
  });

  test('overrides ExportService through Riverpod', () async {
    final printer = RecordingInvoicePrinter();
    final service = ExportService(printer: printer);
    final container = ProviderContainer(
      overrides: [exportServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final injected = container.read(exportServiceProvider);
    await injected.printInvoice(const []);
    expect(identical(injected, service), isTrue);
    expect(printer.calls, 1);
  });

  test('passes file writer exceptions through to the caller', () async {
    final service = ExportService(
      fileWriter: RecordingFileWriter(
        failure: const FileSystemException('disk full'),
      ),
    );
    expect(
      () => service.exportToExcel(const []),
      throwsA(isA<FileSystemException>()),
    );
  });
}
