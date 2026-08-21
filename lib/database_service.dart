import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseService {
  static const String _keyTransactions = 'smart_accountant_transactions';

  Future<void> addTransaction({
    required String type,
    required double amount,
    required String description,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> list = prefs.getStringList(_keyTransactions) ?? [];
    
    final tx = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': type,
      'amount': amount,
      'description': description,
      'date': DateTime.now().toIso8601String(),
    };
    
    list.add(jsonEncode(tx));
    await prefs.setStringList(_keyTransactions, list);
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
        final date = DateTime.parse(tx['date']);
        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          total += (tx['amount'] as num).toDouble();
        }
      }
    }
    return total;
  }

  Future<double> getBalance() async {
    final txs = await getTransactions();
    double balance = 0.0;
    for (var tx in txs) {
      final amount = (tx['amount'] as num).toDouble();
      if (tx['type'] == 'ايراد' || tx['type'] == 'مبيعات') {
        balance += amount;
      } else if (tx['type'] == 'مصروف' || tx['type'] == 'مشتريات') {
        balance -= amount;
      }
    }
    return balance;
  }
}
