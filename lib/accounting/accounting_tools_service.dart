import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AccountingToolsService {
  AccountingToolsService(this.database);
  final Database database;

  Future<void> initialize() async {
    await database.execute('''CREATE TABLE IF NOT EXISTS company_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL DEFAULT '',
      tax_number TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '',
      base_currency TEXT NOT NULL DEFAULT 'SAR', decimal_places INTEGER NOT NULL DEFAULT 2)''');
    await database.insert('company_settings', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await database.execute('''CREATE TABLE IF NOT EXISTS currency_rates (
      code TEXT PRIMARY KEY, name TEXT NOT NULL, symbol TEXT NOT NULL,
      decimal_places INTEGER NOT NULL CHECK(decimal_places BETWEEN 0 AND 4),
      units_per_base REAL NOT NULL CHECK(units_per_base > 0), updated_at TEXT NOT NULL)''');
    await database.execute('''CREATE TABLE IF NOT EXISTS tool_preferences (
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    final count = Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM currency_rates')) ?? 0;
    if (count == 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = database.batch();
      for (final currency in supportedCurrencies) {
        batch.insert('currency_rates', {
          'code': currency.code, 'name': currency.name, 'symbol': currency.symbol,
          'decimal_places': currency.decimalPlaces,
          'units_per_base': currency.code == 'SAR' ? 1.0 : 1.0,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  static const supportedCurrencies = <CurrencyInfo>[
    CurrencyInfo('SAR', 'ريال سعودي', 'ر.س', 2),
    CurrencyInfo('AED', 'درهم إماراتي', 'د.إ', 2),
    CurrencyInfo('USD', 'دولار أمريكي', r'$', 2),
    CurrencyInfo('EUR', 'يورو', '€', 2),
    CurrencyInfo('GBP', 'جنيه إسترليني', '£', 2),
    CurrencyInfo('YER', 'ريال يمني', 'ر.ي', 2),
    CurrencyInfo('JPY', 'ين ياباني', '¥', 0),
    CurrencyInfo('KWD', 'دينار كويتي', 'د.ك', 3),
  ];

  Future<Map<String, Object?>> company() async {
    final rows = await database.query('company_settings', where: 'id=1', limit: 1);
    return rows.single;
  }

  Future<void> saveCompany({required String name, required String taxNumber, required String address, required String phone, required String email, required String baseCurrency, required int decimalPlaces}) async {
    if (name.trim().isEmpty) throw ArgumentError('اسم المنشأة مطلوب.');
    if (decimalPlaces < 0 || decimalPlaces > 4) throw ArgumentError('عدد المنازل العشرية غير صالح.');
    await database.update('company_settings', {
      'name': name.trim(), 'tax_number': taxNumber.trim(), 'address': address.trim(),
      'phone': phone.trim(), 'email': email.trim(), 'base_currency': baseCurrency,
      'decimal_places': decimalPlaces,
    }, where: 'id=1');
  }

  Future<List<CurrencyInfo>> currencies() async {
    final rows = await database.query('currency_rates', orderBy: 'code');
    return rows.map(CurrencyInfo.fromMap).toList();
  }

  /// `unitsPerBase` is the number of currency units equal to one base-currency unit.
  Future<void> saveExchangeRate(String code, double unitsPerBase) async {
    if (!unitsPerBase.isFinite || unitsPerBase <= 0) throw ArgumentError('سعر الصرف يجب أن يكون رقمًا موجبًا.');
    await database.update('currency_rates', {
      'units_per_base': unitsPerBase,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'code=?', whereArgs: [code]);
  }

  Future<int> convertMinor({required int amountMinor, required String from, required String to}) async {
    final rows = await database.query('currency_rates', where: 'code IN (?,?)', whereArgs: [from, to]);
    if (rows.length != (from == to ? 1 : 2)) throw StateError('عملة غير معرفة.');
    final rates = {for (final row in rows) row['code'] as String: (row['units_per_base'] as num).toDouble()};
    final fromInfo = supportedCurrencies.firstWhere((currency) => currency.code == from);
    final toInfo = supportedCurrencies.firstWhere((currency) => currency.code == to);
    final major = amountMinor / _pow10(fromInfo.decimalPlaces);
    final baseAmount = major / rates[from]!;
    final convertedMajor = baseAmount * rates[to]!;
    return (convertedMajor * _pow10(toInfo.decimalPlaces)).round();
  }

  Future<String> createBackup() async {
    final tables = ['accounts', 'parties', 'products', 'invoices', 'invoice_lines', 'journal_entries', 'journal_lines', 'company_settings', 'currency_rates', 'tool_preferences'];
    final data = <String, Object?>{
      'format': 'daftar-accounting-backup',
      'version': 1,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'tables': <String, Object?>{},
    };
    final tableData = data['tables']! as Map<String, Object?>;
    for (final table in tables) {
      tableData[table] = await database.query(table);
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'daftar-backup-${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data), flush: true);
    return file.path;
  }

  Future<void> restoreBackup(String sourcePath) async {
    final decoded = jsonDecode(await File(sourcePath).readAsString());
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'daftar-accounting-backup' || decoded['version'] != 1 || decoded['tables'] is! Map<String, dynamic>) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح أو غير مدعوم.');
    }
    final payload = decoded['tables'] as Map<String, dynamic>;
    const orderedTables = ['accounts', 'parties', 'products', 'invoices', 'invoice_lines', 'journal_entries', 'journal_lines', 'company_settings', 'currency_rates', 'tool_preferences'];
    for (final table in orderedTables) {
      if (payload[table] is! List) throw FormatException('النسخة لا تحتوي جدول $table.');
      for (final row in payload[table] as List) {
        if (row is! Map<String, dynamic>) throw FormatException('صف غير صالح في $table.');
      }
    }
    await database.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in orderedTables.reversed) {
        await txn.delete(table);
      }
      for (final table in orderedTables) {
        final rows = payload[table] as List;
        for (final row in rows.cast<Map<String, dynamic>>()) {
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }
      final integrity = await txn.rawQuery('PRAGMA foreign_key_check');
      if (integrity.isNotEmpty) throw StateError('النسخة تحتوي مراجع بيانات غير متسقة.');
    });
  }

  Future<String?> pickBackupToRestore() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], withData: false);
    if (result == null || result.files.single.path == null) return null;
    return result.files.single.path;
  }

  static int _pow10(int places) {
    var result = 1;
    for (var index = 0; index < places; index++) {
      result *= 10;
    }
    return result;
  }
}

class CurrencyInfo {
  const CurrencyInfo(this.code, this.name, this.symbol, this.decimalPlaces, {this.unitsPerBase = 1});
  final String code;
  final String name;
  final String symbol;
  final int decimalPlaces;
  final double unitsPerBase;

  factory CurrencyInfo.fromMap(Map<String, Object?> row) => CurrencyInfo(
    row['code'] as String, row['name'] as String, row['symbol'] as String,
    row['decimal_places'] as int, unitsPerBase: (row['units_per_base'] as num).toDouble(),
  );
}

double _pow10(int places) => List<int>.generate(places, (index) => index).fold<double>(1, (value, _) => value * 10);
