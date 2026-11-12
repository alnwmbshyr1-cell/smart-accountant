import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

class AccountingToolsService {
  AccountingToolsService(this.database);
  final Database database;

  Future<void> initialize() async {
    await database.execute('''CREATE TABLE IF NOT EXISTS company_settings (
      id INTEGER PRIMARY KEY CHECK(id=1),
      name TEXT NOT NULL DEFAULT '',
      tax_number TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      email TEXT NOT NULL DEFAULT '',
      base_currency TEXT NOT NULL DEFAULT 'SAR',
      decimal_places INTEGER NOT NULL DEFAULT 2)''');
    await database.insert('company_settings', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await database.execute('''CREATE TABLE IF NOT EXISTS currency_rates (
      code TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      symbol TEXT NOT NULL,
      decimal_places INTEGER NOT NULL DEFAULT 2,
      units_per_base REAL NOT NULL DEFAULT 1,
      updated_at TEXT NOT NULL)''');
    await database.execute('''CREATE TABLE IF NOT EXISTS sync_bundle (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at TEXT NOT NULL,
      file_path TEXT NOT NULL,
      payload TEXT NOT NULL)''');
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM currency_rates')) ?? 0;
    if (count == 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = database.batch();
      for (final currency in _supportedCurrencies) {
        batch.insert('currency_rates', {
          'code': currency.code,
          'name': currency.name,
          'symbol': currency.symbol,
          'decimal_places': currency.decimalPlaces,
          'units_per_base': currency.unitsPerBase,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  Future<String> exportPdfReport() async {
    final doc = pw.Document();
    final company = await _companySettings();
    final data = await _reportRows();
    doc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(company['name'] ?? 'الشركة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('رقم ضريبي: ${company['tax_number'] ?? '-'}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['التاريخ', 'البيان', 'المبلغ'],
              data: data.map((row) => [row['entry_date'], row['description'], row['total_minor']]).toList(),
            ),
          ],
        ),
      ),
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'accounting_report_${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await doc.save());
    return file.path;
  }

  Future<String> exportExcelReport() async {
    final excel = Excel.createExcel();
    final name = 'AccountReport';
    final sheet = excel[name];
    sheet.appendRow(['التاريخ', 'البيان', 'المبلغ']);
    final rows = await _reportRows();
    for (final row in rows) {
      sheet.appendRow([row['entry_date'], row['description'], row['total_minor']]);
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'accounting_report_${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    final bytes = excel.encode();
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel.');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> generateCloudSyncBundle() async {
    final payload = {
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'company': await _companySettings(),
      'accounts': await database.query('accounts'),
      'parties': await database.query('parties'),
      'products': await database.query('products'),
      'invoices': await database.query('invoices'),
      'journalEntries': await database.query('journal_entries'),
      'journalLines': await database.query('journal_lines'),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'cloud_sync_bundle_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file.path;
  }

  Future<void> restoreBackup(String sourcePath) async {
    final raw = await File(sourcePath).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) throw const FormatException('ملف النسخ الاحتياطي ليست له بنية صحيحة.');
    await database.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      await txn.delete('journal_lines');
      await txn.delete('journal_entries');
      await txn.delete('invoice_lines');
      await txn.delete('invoices');
      await txn.delete('products');
      await txn.delete('parties');
      await txn.delete('accounts');
      final rows = decoded['accounts'] as List<dynamic>? ?? const [];
      for (final item in rows) {
        await txn.insert('accounts', Map<String, Object?>.from(item as Map));
      }
      final parties = decoded['parties'] as List<dynamic>? ?? const [];
      for (final item in parties) {
        await txn.insert('parties', Map<String, Object?>.from(item as Map));
      }
      final products = decoded['products'] as List<dynamic>? ?? const [];
      for (final item in products) {
        await txn.insert('products', Map<String, Object?>.from(item as Map));
      }
      final invoices = decoded['invoices'] as List<dynamic>? ?? const [];
      for (final item in invoices) {
        await txn.insert('invoices', Map<String, Object?>.from(item as Map));
      }
      final invoiceLines = decoded['invoice_lines'] as List<dynamic>? ?? const [];
      for (final item in invoiceLines) {
        await txn.insert('invoice_lines', Map<String, Object?>.from(item as Map));
      }
      final journalEntries = decoded['journalEntries'] as List<dynamic>? ?? const [];
      for (final item in journalEntries) {
        await txn.insert('journal_entries', Map<String, Object?>.from(item as Map));
      }
      final journalLines = decoded['journalLines'] as List<dynamic>? ?? const [];
      for (final item in journalLines) {
        await txn.insert('journal_lines', Map<String, Object?>.from(item as Map));
      }
    });
  }

  Future<String> createBackup() async {
    final payload = {
      'format': 'daftar-accounting-backup',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'company': await _companySettings(),
      'accounts': await database.query('accounts'),
      'parties': await database.query('parties'),
      'products': await database.query('products'),
      'invoices': await database.query('invoices'),
      'invoice_lines': await database.query('invoice_lines'),
      'journalEntries': await database.query('journal_entries'),
      'journalLines': await database.query('journal_lines'),
    };
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'daftar_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file.path;
  }

  Future<String?> pickBackupToRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], withData: false);
    return result?.files.single.path;
  }

  static const List<_CurrencySeed> _supportedCurrencies = [
    _CurrencySeed('SAR', 'ريال سعودي', 'ر.س', 2, 1),
    _CurrencySeed('AED', 'درهم إماراتي', 'د.إ', 2, 0.96),
    _CurrencySeed('USD', 'دولار أمريكي', '\$', 2, 0.27),
    _CurrencySeed('EUR', 'يورو', '€', 2, 0.24),
    _CurrencySeed('GBP', 'جنيه إسترليني', '£', 2, 0.21),
    _CurrencySeed('YER', 'ريال يمني', 'ر.ي', 2, 6.69),
  ];

  Future<Map<String, Object?>> _companySettings() async {
    final rows = await database.query('company_settings', where: 'id = ?', whereArgs: [1], limit: 1);
    return rows.isNotEmpty ? rows.first : {'name': '', 'tax_number': '', 'address': '', 'phone': '', 'email': '', 'base_currency': 'SAR'};
  }

  Future<List<Map<String, Object?>>> _reportRows() async => database.rawQuery('''
    SELECT j.entry_date, j.description, COALESCE(SUM(l.debit_minor),0) AS total_minor
    FROM journal_entries j
    LEFT JOIN journal_lines l ON l.journal_entry_id = j.id
    WHERE j.status = 'posted'
    GROUP BY j.id
    ORDER BY j.entry_date DESC
    LIMIT 10
  ''');
}

class _CurrencySeed {
  const _CurrencySeed(this.code, this.name, this.symbol, this.decimalPlaces, this.unitsPerBase);
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final double unitsPerBase;
}
