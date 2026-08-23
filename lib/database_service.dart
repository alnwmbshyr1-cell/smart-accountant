import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'transactions';
  static const String _keyTransactions = 'smart_accountant_transactions';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smart_accountant_v3.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT,
            date TEXT NOT NULL,
            is_seed INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // إنشاء فهارس (Indexes) لضمان بحث وفلترة لحظية مع ملايين السجلات
        await db.execute('CREATE INDEX idx_tx_date ON $_tableName (date)');
        await db.execute('CREATE INDEX idx_tx_type ON $_tableName (type)');
        await db.execute('CREATE INDEX idx_tx_seed ON $_tableName (is_seed)');
        await _createStructuredTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createStructuredTables(db);
      },
    );
  }

  Future<void> _createStructuredTables(Database db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS purchases (
      id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS sales (
      id TEXT PRIMARY KEY, description TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS debt_for_me (
      id TEXT PRIMARY KEY, person TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS debt_on_me (
      id TEXT PRIMARY KEY, person TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS inventory (
      id TEXT PRIMARY KEY, item TEXT NOT NULL, quantity REAL NOT NULL,
      unit_price REAL NOT NULL, total REAL NOT NULL, date TEXT NOT NULL
    )''');
    for (final table in [
      'expenses',
      'purchases',
      'sales',
      'debt_for_me',
      'debt_on_me',
      'inventory'
    ]) {
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_${table}_date ON $table (date)');
    }
  }

  /// Saves a normalized parser result to its dedicated table and keeps the
  /// legacy transactions ledger synchronized for reports and old screens.
  Future<void> saveParsedCommand(Map<String, dynamic> command) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    final type =
        command['type']?.toString() ?? command['النوع']?.toString() ?? 'مصروف';
    final amount = _asDouble(command['amount'] ?? command['المبلغ']);
    if (amount <= 0) throw ArgumentError('amount must be positive');
    final now = command['date']?.toString() ?? DateTime.now().toIso8601String();
    final id = '${DateTime.now().microsecondsSinceEpoch}_${type.hashCode}';
    final description =
        (command['description'] ?? command['الوصف'] ?? 'عام').toString().trim();
    final person =
        (command['person'] ?? command['الاسم'] ?? 'عام').toString().trim();
    final item = (command['item'] ?? description).toString().trim();
    final quantity =
        _asDouble(command['quantity'] ?? command['الكمية'], fallback: 1);
    final unitPrice = _asDouble(command['unit_price'] ?? command['سعر_الوحدة'],
        fallback: amount);
    final table = switch (type) {
      'مبيعات' => 'sales',
      'مشتريات' => 'purchases',
      'دين_لي' => 'debt_for_me',
      'دين_علي' => 'debt_on_me',
      'مخزون' => 'inventory',
      _ => 'expenses',
    };
    await db.transaction((txn) async {
      if (table == 'inventory') {
        await txn.insert(table, {
          'id': id,
          'item': item,
          'quantity': quantity,
          'unit_price': unitPrice,
          'total': amount,
          'date': now,
        });
      } else if (table == 'debt_for_me' || table == 'debt_on_me') {
        await txn.insert(
            table, {'id': id, 'person': person, 'amount': amount, 'date': now});
      } else {
        await txn.insert(table, {
          'id': id,
          'description': description,
          'amount': amount,
          'date': now
        });
      }
      await txn.insert(_tableName, {
        'id': id,
        'type': type,
        'amount': amount,
        'description': description,
        'date': now,
        'is_seed': 0,
      });
    });
  }

  Future<double> getStructuredTodayTotal(String type) async {
    final db = await database;
    final table = switch (type) {
      'مبيعات' => 'sales',
      'مشتريات' => 'purchases',
      'دين_لي' => 'debt_for_me',
      'دين_علي' => 'debt_on_me',
      'مخزون' => 'inventory',
      _ => 'expenses',
    };
    final column = table == 'inventory' ? 'total' : 'amount';
    final start = DateTime.now();
    final date = DateTime(start.year, start.month, start.day).toIso8601String();
    final rows = await db.rawQuery(
        'SELECT COALESCE(SUM($column), 0) AS total FROM $table WHERE date >= ?',
        [date]);
    return _asDouble(rows.first['total']);
  }

  Future<List<Map<String, dynamic>>> getStructuredRecords(String type) async {
    final db = await database;
    final table = switch (type) {
      'مبيعات' => 'sales',
      'مشتريات' => 'purchases',
      'دين_لي' => 'debt_for_me',
      'دين_علي' => 'debt_on_me',
      'مخزون' => 'inventory',
      _ => 'expenses',
    };
    return db.query(table, orderBy: 'date DESC', limit: 100);
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  /// ترحيل البيانات القديمة من SharedPreferences إلى SQLite إن وجدت لمرة واحدة
  Future<void> migrateFromSharedPreferencesIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyTransactions);
    if (list != null && list.isNotEmpty) {
      final db = await database;
      await db.transaction((txn) async {
        for (var itemStr in list) {
          try {
            final map = jsonDecode(itemStr) as Map<String, dynamic>;
            await txn.insert(
              _tableName,
              {
                'id': map['id'] ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                'type': map['type'] ?? 'مصروف',
                'amount': (map['amount'] as num?)?.toDouble() ?? 0.0,
                'description': map['description'] ?? '',
                'date': map['date'] ?? DateTime.now().toIso8601String(),
                'is_seed':
                    (map['is_seed'] == true || map['is_seed'] == 1) ? 1 : 0,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (_) {}
        }
      });
      // إزالة المفتاح القديم بعد الترحيل الناجح
      await prefs.remove(_keyTransactions);
    }
  }

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String description,
    int isSeed = 0,
  }) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';

    await db.insert(
      _tableName,
      {
        'id': id,
        'type': type,
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'is_seed': isSeed,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// إدخال جماعي على دفعات (Batch Insert) لتسريع حقن ملايين السجلات في الخلفية
  Future<void> insertBatchTransactions(List<Map<String, dynamic>> batch) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;

    await db.transaction((txn) async {
      for (int i = 0; i < batch.length; i++) {
        final map = batch[i];
        final id =
            '${DateTime.now().millisecondsSinceEpoch}_b_${i}_${map.hashCode}';
        await txn.insert(
          _tableName,
          {
            'id': id,
            'type': map['type'],
            'amount': map['amount'],
            'description': map['description'],
            'date': map['date'] ?? DateTime.now().toIso8601String(),
            'is_seed': map['is_seed'] ?? 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> deleteSeedTransactions() async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    return await db.delete(_tableName, where: 'is_seed = ?', whereArgs: [1]);
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    final result =
        await db.query(_tableName, orderBy: 'date DESC, id DESC', limit: 100);
    return result;
  }

  /// Keyset Pagination العالية الأداء لتصفح الملايين بدون تجاوز الحد أو بطء الـ Offset
  Future<List<Map<String, dynamic>>> getTransactionsPage({
    int limit = 100,
    String? lastDate,
    String? lastId,
  }) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;

    if (lastDate != null && lastId != null) {
      return await db.query(
        _tableName,
        where: 'date < ? OR (date = ? AND id < ?)',
        whereArgs: [lastDate, lastDate, lastId],
        orderBy: 'date DESC, id DESC',
        limit: limit,
      );
    } else {
      return await db.query(
        _tableName,
        orderBy: 'date DESC, id DESC',
        limit: limit,
      );
    }
  }

  Future<double> getTodayTotal(String type) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toIso8601String();

    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM $_tableName WHERE type = ? AND date >= ?',
      [type, startOfDay],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> searchTransactions(String query) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    query = '%$query%';

    final result = await db.query(
      _tableName,
      where: 'description LIKE ? OR type LIKE ?',
      whereArgs: [query, query],
      orderBy: 'date DESC',
      limit: 100,
    );
    return result;
  }

  Future<double> getBalance() async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;

    final result = await db.rawQuery('''
      SELECT 
        SUM(CASE WHEN type IN ('ايراد', 'مبيعات', 'دين لك') THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type IN ('مصروف', 'مشتريات', 'دين عليك') THEN amount ELSE 0 END) as expense
      FROM $_tableName
    ''');

    if (result.isNotEmpty) {
      final income = (result.first['income'] as num?)?.toDouble() ?? 0.0;
      final expense = (result.first['expense'] as num?)?.toDouble() ?? 0.0;
      return income - expense;
    }
    return 0.0;
  }

  Future<List<Map<String, dynamic>>> getMonthlyProfitSummary({
    int months = 6,
  }) async {
    await migrateFromSharedPreferencesIfNeeded();
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        substr(date, 1, 7) AS month,
        COALESCE(SUM(CASE WHEN type IN ('مبيعات', 'ايراد') THEN amount ELSE 0 END), 0) AS sales,
        COALESCE(SUM(CASE WHEN type IN ('مشتريات', 'مصروف') THEN amount ELSE 0 END), 0) AS expenses
      FROM $_tableName
      GROUP BY substr(date, 1, 7)
      ORDER BY month DESC
      LIMIT ?
    ''', [months]);

    return rows
        .map((row) {
          final sales = (row['sales'] as num?)?.toDouble() ?? 0.0;
          final expenses = (row['expenses'] as num?)?.toDouble() ?? 0.0;
          return {
            'month': row['month']?.toString() ?? '',
            'sales': sales,
            'expenses': expenses,
            'profit': sales - expenses,
          };
        })
        .toList()
        .reversed
        .toList();
  }

  /// إغلاق الاتصال المشترك للاختبارات فقط ومنع تسرب قفل SQLite.
  Future<void> closeForTesting() async {
    final current = _database;
    _database = null;
    if (current != null) {
      await current.close();
    }
  }
}
