import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountingToolsService {
  AccountingToolsService(this.database);
  final Database database;
  SupabaseClient? _cloud;

  void configureCloud(SupabaseClient client) => _cloud = client;

  Future<void> initialize() async {
    await database.execute('''CREATE TABLE IF NOT EXISTS company_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL DEFAULT '', tax_number TEXT NOT NULL DEFAULT '',
      address TEXT NOT NULL DEFAULT '', phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '',
      base_currency TEXT NOT NULL DEFAULT 'SAR', decimal_places INTEGER NOT NULL DEFAULT 2)''');
    await database.insert('company_settings', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await database.execute('''CREATE TABLE IF NOT EXISTS currency_rates (
      code TEXT PRIMARY KEY, name TEXT NOT NULL, symbol TEXT NOT NULL, decimal_places INTEGER NOT NULL,
      units_per_base REAL NOT NULL DEFAULT 1, updated_at TEXT NOT NULL)''');
    await database.execute('''CREATE TABLE IF NOT EXISTS cloud_sync_state (
      id INTEGER PRIMARY KEY CHECK(id=1), last_synced_at TEXT, last_error TEXT)''');
    await database.insert('cloud_sync_state', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM currency_rates')) ?? 0;
    if (count == 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = database.batch();
      for (final item in const [
        ('SAR', 'ريال سعودي', 'ر.س', 2), ('AED', 'درهم إماراتي', 'د.إ', 2),
        ('USD', 'دولار أمريكي', r'$', 2), ('EUR', 'يورو', '€', 2),
        ('GBP', 'جنيه إسترليني', '£', 2), ('YER', 'ريال يمني', 'ر.ي', 2),
        ('KWD', 'دينار كويتي', 'د.ك', 3), ('JPY', 'ين ياباني', '¥', 0),
      ]) {
        // Rates initialize to 1 only as an unconfigured placeholder. The user must enter
        // actual rates; never treat these placeholders as a market quote.
        batch.insert('currency_rates', {'code': item.$1, 'name': item.$2, 'symbol': item.$3, 'decimal_places': item.$4, 'units_per_base': 1.0, 'updated_at': now});
      }
      await batch.commit(noResult: true);
    }
  }

  Future<Map<String, Object?>> company() async => (await database.query('company_settings', where: 'id=1', limit: 1)).first;
  Future<List<Map<String, Object?>>> currencies() => database.query('currency_rates', orderBy: 'code');

  Future<void> saveExchangeRate(String code, double unitsPerBase) async {
    if (!unitsPerBase.isFinite || unitsPerBase <= 0) throw ArgumentError('سعر الصرف يجب أن يكون رقمًا موجبًا.');
    await database.update('currency_rates', {'units_per_base': unitsPerBase, 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'code=?', whereArgs: [code]);
  }

  Future<String> createBackup() async {
    final payload = await _snapshot();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'daftar-backup-${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file.path;
  }

  Future<String?> pickBackupToRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    return result?.files.single.path;
  }

  Future<void> restoreBackup(String sourcePath) async {
    final decoded = jsonDecode(await File(sourcePath).readAsString());
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'daftar-accounting-backup' || decoded['version'] != 1 || decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('ملف النسخة غير صالح أو غير مدعوم.');
    }
    final tables = decoded['tables'] as Map<String, dynamic>;
    const ordered = ['accounts','parties','products','invoices','invoice_lines','journal_entries','journal_lines','company_settings','currency_rates'];
    for (final table in ordered) {
      if (tables[table] is! List) throw FormatException('النسخة لا تحتوي جدول $table.');
    }
    await database.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys=ON');
      for (final table in ordered.reversed) { await txn.delete(table); }
      for (final table in ordered) {
        for (final raw in tables[table] as List) {
          if (raw is! Map) throw FormatException('صف غير صالح في $table.');
          await txn.insert(table, Map<String, Object?>.from(raw), conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
      final violations = await txn.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) throw StateError('توجد مراجع غير صحيحة في ملف النسخة.');
    });
  }

  /// Explicit, authenticated snapshot sync. This is not a real-time merge engine.
  /// It never silently overwrites local data from cloud; the backend RLS migration is required.
  Future<String> generateCloudSyncBundle() async {
    final client = _cloud;
    if (client == null) throw StateError('المزامنة غير مهيأة. أضف SUPABASE_URL وSUPABASE_PUBLISHABLE_KEY ثم أعد تشغيل التطبيق.');
    final user = client.auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول إلى Supabase قبل مزامنة بيانات الشركة.');
    final payload = await _snapshot();
    final now = DateTime.now().toUtc().toIso8601String();
    await client.from('accounting_snapshots').upsert({
      'user_id': user.id,
      'payload': payload,
      'updated_at': now,
      'schema_version': 1,
    }, onConflict: 'user_id');
    await database.update('cloud_sync_state', {'last_synced_at': now, 'last_error': null}, where: 'id=1');
    return 'تمت المزامنة السحابية للحساب ${user.email ?? user.id} في $now';
  }

  Future<void> restoreCloudSnapshot() async {
    final client = _cloud;
    if (client == null) throw StateError('المزامنة غير مهيأة.');
    final user = client.auth.currentUser;
    if (user == null) throw StateError('سجّل الدخول أولاً.');
    final row = await client.from('accounting_snapshots').select('payload,schema_version').eq('user_id', user.id).maybeSingle();
    if (row == null) throw StateError('لا توجد نسخة سحابية لهذا الحساب.');
    if (row['schema_version'] != 1) throw StateError('إصدار النسخة السحابية غير مدعوم.');
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'cloud-restore-${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(jsonEncode(row['payload']), flush: true);
    await restoreBackup(file.path);
    await file.delete();
  }

  Future<String> exportPdfReport() async {
    final rows = await _reportRows();
    final profile = await company();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Text('${profile['name'] ?? 'الشركة'}', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.Text('Trial balance / Journal summary • ${DateTime.now().toIso8601String().substring(0, 10)}'),
      pw.SizedBox(height: 16),
      pw.TableHelper.fromTextArray(headers: ['Date', 'Description', 'Amount (minor units)'], data: rows.map((r) => [r['entry_date'], r['description'], r['total_minor']]).toList()),
    ]));
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'accounting-report-${DateTime.now().millisecondsSinceEpoch}.pdf'));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }

  Future<String> exportExcelReport() async {
    final excel = Excel.createExcel();
    final sheet = excel['Journal'];
    sheet.appendRow([TextCellValue('Date'), TextCellValue('Description'), TextCellValue('Debit minor')]);
    for (final row in await _reportRows()) {
      sheet.appendRow([TextCellValue('${row['entry_date']}'), TextCellValue('${row['description']}'), IntCellValue((row['total_minor'] as int?) ?? 0)]);
    }
    final bytes = excel.encode();
    if (bytes == null) throw StateError('تعذر إنشاء ملف Excel.');
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'accounting-report-${DateTime.now().millisecondsSinceEpoch}.xlsx'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Map<String, Object?>> _snapshot() async {
    const tables = ['accounts','parties','products','invoices','invoice_lines','journal_entries','journal_lines','company_settings','currency_rates'];
    final data = <String, Object?>{};
    for (final table in tables) { data[table] = await database.query(table); }
    return {'format': 'daftar-accounting-backup', 'version': 1, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'tables': data};
  }

  Future<List<Map<String, Object?>>> _reportRows() => database.rawQuery('''
    SELECT j.entry_date,j.description,COALESCE(SUM(l.debit_minor),0) AS total_minor
    FROM journal_entries j LEFT JOIN journal_lines l ON l.journal_entry_id=j.id
    WHERE j.status='posted' GROUP BY j.id ORDER BY j.entry_date DESC LIMIT 1000''');
}
