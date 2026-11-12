import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AccountingDatabase {
  AccountingDatabase._(this.db);
  final Database db;

  static Future<AccountingDatabase> open() async {
    final file = p.join(await getDatabasesPath(), 'daftar_accounting.db');
    final database = await openDatabase(
      file,
      version: 2,
      onCreate: _create,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSettingsTables(db);
      },
    );
    return AccountingDatabase._(database);
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.execute('''CREATE TABLE accounts (
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('asset','liability','equity','income','expense')),
      parent_id INTEGER REFERENCES accounts(id), is_active INTEGER NOT NULL DEFAULT 1)''');
    await db.execute('''CREATE TABLE parties (
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      kind TEXT NOT NULL CHECK(kind IN ('customer','supplier','both')),
      phone TEXT, email TEXT, tax_number TEXT, is_active INTEGER NOT NULL DEFAULT 1)''');
    await db.execute('''CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT, sku TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL, unit TEXT NOT NULL DEFAULT 'قطعة',
      purchase_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(purchase_price_minor >= 0),
      sale_price_minor INTEGER NOT NULL DEFAULT 0 CHECK(sale_price_minor >= 0),
      stock_milli INTEGER NOT NULL DEFAULT 0, reorder_milli INTEGER NOT NULL DEFAULT 0)''');
    await db.execute('''CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT, number TEXT NOT NULL UNIQUE,
      kind TEXT NOT NULL CHECK(kind IN ('sale','purchase')),
      party_id INTEGER NOT NULL REFERENCES parties(id), invoice_date TEXT NOT NULL,
      subtotal_minor INTEGER NOT NULL CHECK(subtotal_minor >= 0),
      tax_minor INTEGER NOT NULL DEFAULT 0 CHECK(tax_minor >= 0),
      total_minor INTEGER NOT NULL CHECK(total_minor >= 0),
      status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted','void')),
      created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE invoice_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_id INTEGER NOT NULL REFERENCES invoices(id),
      product_id INTEGER NOT NULL REFERENCES products(id), description TEXT NOT NULL,
      quantity_milli INTEGER NOT NULL CHECK(quantity_milli > 0),
      unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor >= 0),
      line_total_minor INTEGER NOT NULL CHECK(line_total_minor >= 0))''');
    await db.execute('''CREATE TABLE journal_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, entry_date TEXT NOT NULL,
      description TEXT NOT NULL, reference TEXT, source_type TEXT, source_id INTEGER,
      status TEXT NOT NULL CHECK(status IN ('posted','void')), created_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE journal_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      journal_entry_id INTEGER NOT NULL REFERENCES journal_entries(id),
      account_id INTEGER NOT NULL REFERENCES accounts(id), party_id INTEGER REFERENCES parties(id),
      description TEXT NOT NULL DEFAULT '', debit_minor INTEGER NOT NULL DEFAULT 0 CHECK(debit_minor >= 0),
      credit_minor INTEGER NOT NULL DEFAULT 0 CHECK(credit_minor >= 0),
      CHECK((debit_minor > 0 AND credit_minor = 0) OR (credit_minor > 0 AND debit_minor = 0)))''');
    await db.execute('CREATE INDEX journal_date_idx ON journal_entries(entry_date)');
    await db.execute('CREATE INDEX journal_account_idx ON journal_lines(account_id)');
    await db.execute('CREATE INDEX invoice_date_idx ON invoices(invoice_date)');
    await _createSettingsTables(db);

    final accounts = <Map<String, Object?>>[
      {'code':'1010','name':'الصندوق','type':'asset'},
      {'code':'1020','name':'البنك','type':'asset'},
      {'code':'1030','name':'الذمم المدينة','type':'asset'},
      {'code':'1040','name':'المخزون','type':'asset'},
      {'code':'2010','name':'الذمم الدائنة','type':'liability'},
      {'code':'3010','name':'رأس المال','type':'equity'},
      {'code':'4010','name':'إيرادات المبيعات','type':'income'},
      {'code':'5010','name':'مصروفات التشغيل','type':'expense'},
    ];
    final batch = db.batch();
    for (final account in accounts) {
      batch.insert('accounts', account);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _createSettingsTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS company_settings (
      id INTEGER PRIMARY KEY CHECK(id=1), name TEXT NOT NULL DEFAULT '',
      tax_number TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '',
      base_currency TEXT NOT NULL DEFAULT 'SAR', decimal_places INTEGER NOT NULL DEFAULT 2)''');
    await db.insert('company_settings', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.execute('''CREATE TABLE IF NOT EXISTS currency_rates (
      code TEXT PRIMARY KEY, name TEXT NOT NULL, symbol TEXT NOT NULL,
      decimal_places INTEGER NOT NULL CHECK(decimal_places BETWEEN 0 AND 4),
      units_per_base REAL NOT NULL DEFAULT 1, updated_at TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS tool_preferences (
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sync_metadata (
      id INTEGER PRIMARY KEY CHECK(id=1), last_synced_at TEXT, cloud_revision INTEGER NOT NULL DEFAULT 0)''');
    await db.insert('sync_metadata', {'id': 1}, conflictAlgorithm: ConflictAlgorithm.ignore);
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM currency_rates')) ?? 0;
    if (count == 0) {
      final now = DateTime.now().toUtc().toIso8601String();
      final batch = db.batch();
      for (final currency in _currencies) {
        batch.insert('currency_rates', {
          'code': currency.$1, 'name': currency.$2, 'symbol': currency.$3,
          'decimal_places': currency.$4, 'units_per_base': 1.0, 'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  static const _currencies = <(String, String, String, int)>[
    ('SAR','ريال سعودي','ر.س',2), ('AED','درهم إماراتي','د.إ',2),
    ('USD','دولار أمريكي','4',2), ('EUR','يورو','€',2),
    ('GBP','جنيه إسترليني','£',2), ('YER','ريال يمني','ر.ي',2),
    ('KWD','دينار كويتي','د.ك',3), ('JPY','ين ياباني','¥',0),
  ];

  Future<List<Map<String, Object?>>> accounts() => db.query('accounts', orderBy: 'code');
  Future<List<Map<String, Object?>>> parties() => db.query('parties', where: 'is_active=1', orderBy: 'name');
  Future<List<Map<String, Object?>>> products() => db.query('products', orderBy: 'name');
  Future<List<Map<String, Object?>>> invoices() => db.rawQuery('''
    SELECT i.*, p.name AS party_name FROM invoices i JOIN parties p ON p.id=i.party_id
    ORDER BY i.invoice_date DESC, i.id DESC''');
  Future<List<Map<String, Object?>>> journal() => db.rawQuery('''
    SELECT j.*, COALESCE(SUM(l.debit_minor),0) AS total_minor
    FROM journal_entries j LEFT JOIN journal_lines l ON l.journal_entry_id=j.id
    GROUP BY j.id ORDER BY j.entry_date DESC, j.id DESC''');
  Future<List<Map<String, Object?>>> latestEntries({int limit = 10}) => db.rawQuery('''
    SELECT j.*, COALESCE(SUM(l.debit_minor),0) AS total_minor
    FROM journal_entries j LEFT JOIN journal_lines l ON l.journal_entry_id=j.id
    WHERE j.status='posted' GROUP BY j.id ORDER BY j.entry_date DESC,j.id DESC LIMIT ?''', [limit]);

  Future<int> addAccount({required String code, required String name, required String type, int? parentId}) => db.insert('accounts', {'code': code.trim(), 'name': name.trim(), 'type': type, 'parent_id': parentId});
  Future<int> addParty({required String name, required String kind, String? phone, String? email, String? taxNumber}) => db.insert('parties', {'name': name.trim(), 'kind': kind, 'phone': phone?.trim(), 'email': email?.trim(), 'tax_number': taxNumber?.trim()});
  Future<int> addProduct({required String sku, required String name, required int purchasePriceMinor, required int salePriceMinor, required int openingStockMilli, required int reorderMilli}) => db.insert('products', {'sku': sku.trim(), 'name': name.trim(), 'purchase_price_minor': purchasePriceMinor, 'sale_price_minor': salePriceMinor, 'stock_milli': openingStockMilli, 'reorder_milli': reorderMilli});

  Future<int> postJournal({required String date, required String description, String? reference, required List<JournalLineData> lines}) async {
    _validateLines(lines);
    return db.transaction((txn) async {
      for (final line in lines) {
        final exists = await txn.query('accounts', columns: ['id'], where: 'id=? AND is_active=1', whereArgs: [line.accountId], limit: 1);
        if (exists.isEmpty) throw StateError('الحساب المحدد غير موجود أو غير فعال.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final id = await txn.insert('journal_entries', {'entry_date': date, 'description': description.trim(), 'reference': reference, 'status': 'posted', 'created_at': now});
      for (final line in lines) {
        await txn.insert('journal_lines', {'journal_entry_id': id, 'account_id': line.accountId, 'party_id': line.partyId, 'description': line.description, 'debit_minor': line.debitMinor, 'credit_minor': line.creditMinor});
      }
      return id;
    });
  }

  Future<int> createInvoice({required String number, required String kind, required int partyId, required DateTime date, required List<InvoiceLineData> lines, int taxMinor = 0}) async {
    if (number.trim().isEmpty || (kind != 'sale' && kind != 'purchase') || lines.isEmpty || taxMinor < 0) throw ArgumentError('تحقق من رقم ��لفاتورة ونوعها وبنودها والضريبة.');
    final subtotal = lines.fold<int>(0, (sum, line) => sum + line.totalMinor);
    final total = subtotal + taxMinor;
    if (total <= 0) throw ArgumentError('إجمالي الفاتورة يجب أن يكون أكبر من صفر.');
    return db.transaction((txn) async {
      final party = await txn.query('parties', where: 'id=? AND is_active=1', whereArgs: [partyId], limit: 1);
      if (party.isEmpty) throw StateError('العميل أو المورد غير موجود.');
      for (final line in lines) {
        final rows = await txn.query('products', where: 'id=?', whereArgs: [line.productId], limit: 1);
        if (rows.isEmpty) throw StateError('الصنف غير موجود.');
        if (kind == 'sale' && (rows.first['stock_milli'] as int) < line.quantityMilli) throw StateError('المخزون غير كافٍ للصنف ${rows.first['name']}.');
      }
      final now = DateTime.now().toUtc().toIso8601String();
      final invoiceId = await txn.insert('invoices', {'number': number.trim(), 'kind': kind, 'party_id': partyId, 'invoice_date': _dateOnly(date), 'subtotal_minor': subtotal, 'tax_minor': taxMinor, 'total_minor': total, 'status': 'posted', 'created_at': now});
      for (final line in lines) {
        await txn.insert('invoice_lines', {'invoice_id': invoiceId, 'product_id': line.productId, 'description': line.description, 'quantity_milli': line.quantityMilli, 'unit_price_minor': line.unitPriceMinor, 'line_total_minor': line.totalMinor});
        await txn.rawUpdate('UPDATE products SET stock_milli=stock_milli+? WHERE id=?', [kind == 'purchase' ? line.quantityMilli : -line.quantityMilli, line.productId]);
      }
      final entryId = await txn.insert('journal_entries', {'entry_date': _dateOnly(date), 'description': '${kind == 'sale' ? 'فاتورة بيع' : 'فاتورة شراء'} ${number.trim()}', 'reference': number.trim(), 'source_type': 'invoice', 'source_id': invoiceId, 'status': 'posted', 'created_at': now});
      final debitAccount = kind == 'sale' ? 3 : 4;
      final creditAccount = kind == 'sale' ? 7 : 5;
      await txn.insert('journal_lines', {'journal_entry_id': entryId, 'account_id': debitAccount, 'party_id': partyId, 'description': 'إجمالي الفاتورة', 'debit_minor': total, 'credit_minor': 0});
      await txn.insert('journal_lines', {'journal_entry_id': entryId, 'account_id': creditAccount, 'party_id': partyId, 'description': 'إجمالي الفاتورة', 'debit_minor': 0, 'credit_minor': total});
      return invoiceId;
    });
  }

  Future<List<Map<String, Object?>>> trialBalance({DateTime? from, DateTime? to}) async {
    final where = <String>[]; final args = <Object?>[];
    if (from != null) { where.add('j.entry_date >= ?'); args.add(_dateOnly(from)); }
    if (to != null) { where.add('j.entry_date <= ?'); args.add(_dateOnly(to)); }
    final filter = where.isEmpty ? '' : 'AND ${where.join(' AND ')}';
    return db.rawQuery('''SELECT a.id,a.code,a.name,a.type,
      COALESCE(SUM(CASE WHEN j.status='posted' $filter THEN l.debit_minor ELSE 0 END),0) AS debit_minor,
      COALESCE(SUM(CASE WHEN j.status='posted' $filter THEN l.credit_minor ELSE 0 END),0) AS credit_minor
      FROM accounts a LEFT JOIN journal_lines l ON l.account_id=a.id
      LEFT JOIN journal_entries j ON j.id=l.journal_entry_id GROUP BY a.id ORDER BY a.code''', [...args, ...args]);
  }

  Future<List<Map<String, Object?>>> incomeStatement({DateTime? from, DateTime? to}) async {
    final where = <String>["j.status='posted'", "a.type IN ('income','expense')"];
    final args = <Object?>[];
    if (from != null) { where.add('j.entry_date >= ?'); args.add(_dateOnly(from)); }
    if (to != null) { where.add('j.entry_date <= ?'); args.add(_dateOnly(to)); }
    return db.rawQuery('''SELECT a.type, a.name AS label,
      SUM(CASE WHEN a.type='income' THEN l.credit_minor-l.debit_minor ELSE l.debit_minor-l.credit_minor END) AS total_minor
      FROM journal_lines l JOIN accounts a ON a.id=l.account_id JOIN journal_entries j ON j.id=l.journal_entry_id
      WHERE ${where.join(' AND ')} GROUP BY a.id ORDER BY a.type,a.code''', args);
  }

  Future<List<Map<String, Object?>>> cashFlow({DateTime? from, DateTime? to}) async {
    final where = <String>["j.status='posted'", "a.type='asset'", "a.code LIKE '10%'"];
    final args = <Object?>[];
    if (from != null) { where.add('j.entry_date >= ?'); args.add(_dateOnly(from)); }
    if (to != null) { where.add('j.entry_date <= ?'); args.add(_dateOnly(to)); }
    return db.rawQuery('''SELECT j.entry_date AS label,
      SUM(l.debit_minor-l.credit_minor) AS total_minor
      FROM journal_lines l JOIN accounts a ON a.id=l.account_id JOIN journal_entries j ON j.id=l.journal_entry_id
      WHERE ${where.join(' AND ')} GROUP BY j.entry_date ORDER BY j.entry_date''', args);
  }

  Future<Map<String, int>> totals() async {
    final rows = await db.rawQuery('''SELECT a.type,SUM(l.debit_minor) AS debit,SUM(l.credit_minor) AS credit FROM journal_lines l JOIN accounts a ON a.id=l.account_id JOIN journal_entries j ON j.id=l.journal_entry_id WHERE j.status='posted' GROUP BY a.type''');
    return {for (final row in rows) row['type'] as String: ((row['debit'] as int?) ?? 0) - ((row['credit'] as int?) ?? 0)};
  }

  Future<Map<String, Object?>> companySettings() async => (await db.query('company_settings', where: 'id=1', limit: 1)).first;
  Future<void> saveCompanySettings({required String name, required String taxNumber, required String address, required String phone, required String email, required String baseCurrency, required int decimalPlaces}) async {
    await db.update('company_settings', {'name': name.trim(), 'tax_number': taxNumber.trim(), 'address': address.trim(), 'phone': phone.trim(), 'email': email.trim(), 'base_currency': baseCurrency, 'decimal_places': decimalPlaces}, where: 'id=1');
  }
  Future<List<Map<String, Object?>>> currencyRates() => db.query('currency_rates', orderBy: 'code');
  Future<void> saveCurrencyRate({required String code, required double unitsPerBase}) async {
    if (!unitsPerBase.isFinite || unitsPerBase <= 0) throw ArgumentError('سعر الصرف يجب أن يكون موجبًا.');
    await db.update('currency_rates', {'units_per_base': unitsPerBase, 'updated_at': DateTime.now().toUtc().toIso8601String()}, where: 'code=?', whereArgs: [code]);
  }
  Future<void> setLastSynced(String time) => db.update('sync_metadata', {'last_synced_at': time}, where: 'id=1');
  Future<void> close() => db.close();

  void _validateLines(List<JournalLineData> lines) {
    if (lines.length < 2) throw ArgumentError('القيد يحتاج سطرين على الأقل.');
    var debit = 0; var credit = 0;
    for (final line in lines) {
      if (line.debitMinor < 0 || line.creditMinor < 0 || (line.debitMinor == 0) == (line.creditMinor == 0)) throw ArgumentError('كل سطر يجب أن يحتوي مبلغًا موجبًا في المدين أو الدائن فقط.');
      debit += line.debitMinor; credit += line.creditMinor;
    }
    if (debit != credit) throw ArgumentError('القيد غير متوازن: المدين لا يساوي الدائن.');
  }
  String _dateOnly(DateTime date) => '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
}

class JournalLineData {
  const JournalLineData({required this.accountId, this.partyId, this.description='', this.debitMinor=0, this.creditMinor=0});
  final int accountId; final int? partyId; final String description; final int debitMinor; final int creditMinor;
}
class InvoiceLineData {
  const InvoiceLineData({required this.productId, required this.description, required this.quantityMilli, required this.unitPriceMinor});
  final int productId; final String description; final int quantityMilli; final int unitPriceMinor;
  int get totalMinor => (quantityMilli * unitPriceMinor + 500) ~/ 1000;
}
int minorFromAmount(double amount, {int decimals = 2}) { var scale=1; for(var i=0;i<decimals;i++){scale*=10;} return (amount*scale).round(); }
double amountFromMinor(int value, {int decimals = 2}) { var scale=1; for(var i=0;i<decimals;i++){scale*=10;} return value/scale; }
String toReadableDate(DateTime date) => '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}';
