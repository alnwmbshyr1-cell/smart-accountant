import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static const String _keyTransactions = 'smart_accountant_transactions';

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String description,
    int isSeed = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyTransactions) ?? [];
    
    final tx = {
      'id': DateTime.now().millisecondsSinceEpoch.toString() + '_' + list.length.toString(),
      'type': type,
      'amount': amount,
      'description': description,
      'date': DateTime.now().toIso8601String(),
      'is_seed': isSeed,
    };
    
    list.add(jsonEncode(tx));
    await prefs.setStringList(_keyTransactions, list);
  }

  Future<void> insertBatchTransactions(List<Map<String, dynamic>> batch) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyTransactions) ?? [];
    
    for (int i = 0; i < batch.length; i++) {
      final map = batch[i];
      final tx = {
        'id': DateTime.now().millisecondsSinceEpoch.toString() + '_b_${i}_${list.length}',
        'type': map['type'],
        'amount': map['amount'],
        'description': map['description'],
        'date': map['date'] ?? DateTime.now().toIso8601String(),
        'is_seed': map['is_seed'] ?? 1,
      };
      list.add(jsonEncode(tx));
    }
    
    await prefs.setStringList(_keyTransactions, list);
  }

  Future<int> deleteSeedTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyTransactions) ?? [];
    List<String> filtered = [];
    int deletedCount = 0;
    
    for (var str in list) {
      try {
        var map = jsonDecode(str);
        if (map['is_seed'] == 1 || map['is_seed'] == true) {
          deletedCount++;
        } else {
          filtered.add(str);
        }
      } catch (_) {
        filtered.add(str);
      }
    }
    
    await prefs.setStringList(_keyTransactions, filtered);
    return deletedCount;
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyTransactions) ?? [];
    return list.map((item) => jsonDecode(item) as Map<String, dynamic>).toList();
  }

  Future<double> getTodayTotal(String type) async {
    final txs = await getTransactions();
    final now = DateTime.now();
    double total = 0.0;
    for (var tx in txs) {
      if (tx['type'] == type) {
        try {
          final date = DateTime.parse(tx['date']);
          if (date.year == now.year && date.month == now.month && date.day == now.day) {
            total += (tx['amount'] as num).toDouble();
          }
        } catch (_) {}
      }
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> searchTransactions(String query) async {
    final txs = await getTransactions();
    query = query.toLowerCase();
    return txs.where((tx) {
      final desc = (tx['description'] ?? '').toString().toLowerCase();
      final type = (tx['type'] ?? '').toString().toLowerCase();
      return desc.contains(query) || type.contains(query);
    }).toList();
  }

  Future<double> getBalance() async {
    final txs = await getTransactions();
    double balance = 0.0;
    for (var tx in txs) {
      final amount = (tx['amount'] as num).toDouble();
      if (tx['type'] == 'ايراد' || tx['type'] == 'مبيعات' || tx['type'] == 'دين لك') {
        balance += amount;
      } else if (tx['type'] == 'مصروف' || tx['type'] == 'مشتريات' || tx['type'] == 'دين عليك') {
        balance -= amount;
      }
    }
    return balance;
  }
}
