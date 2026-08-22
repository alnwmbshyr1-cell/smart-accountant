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
      version: 1,
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
      },
    );
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
                'id': map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                'type': map['type'] ?? 'مصروف',
                'amount': (map['amount'] as num?)?.toDouble() ?? 0.0,
                'description': map['description'] ?? '',
                'date': map['date'] ?? DateTime.now().toIso8601String(),
                'is_seed': (map['is_seed'] == true || map['is_seed'] == 1) ? 1 : 0,
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
    final id = DateTime.now().millisecondsSinceEpoch.toString() + '_' + DateTime.now().microsecond.toString();
    
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
        final id = DateTime.now().millisecondsSinceEpoch.toString() + '_b_${i}_${map.hashCode}';
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
    final result = await db.query(_tableName, orderBy: 'date DESC', limit: 500); // عرض أحدث 500 للواجهة لضمان السرعة المطلقة
    return result;
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
}
