import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'database_service.dart';

class AiAgentService {
  final FlutterTts _tts = FlutterTts();
  final DatabaseService _db = DatabaseService();
  
  bool _isListening = false;
  bool _isAssistantMode = false;

  bool get isListening => _isListening;
  bool get isAssistantMode => _isAssistantMode;

  Future<void> init() async {
    await _tts.setLanguage("ar-SA");
    await _tts.setSpeechRate(0.5);
  }

  void startAssistant() {
    _isAssistantMode = true;
    _isListening = true;
  }

  void stopAssistant() {
    _isAssistantMode = false;
    _isListening = false;
  }

  Future<void> processVoiceCommandText(String voiceText, Function(String) onResult) async {
    await _speak("لحظة بشوف");
    final command = _parseWithRules(voiceText);
    
    if (command['action'] == 'add_expense') {
      await _db.addTransaction(
        type: 'مصروف',
        amount: command['amount'],
        description: command['desc'],
      );
      double total = await _db.getTodayTotal('مصروف');
      String msg = "تم اضافة ${command['amount']} ريال. اجمالي مصروفات اليوم $total ريال";
      onResult(msg);
      await _speak(msg);
      
    } else if (command['action'] == 'add_income') {
      await _db.addTransaction(
        type: 'ايراد',
        amount: command['amount'],
        description: command['desc'],
      );
      String msg = "تم تسجيل ايراد ${command['amount']} ريال";
      onResult(msg);
      await _speak(msg);
      
    } else if (command['action'] == 'get_balance') {
      double balance = await _db.getBalance();
      String msg = "رصيدك الحالي $balance ريال";
      onResult(msg);
      await _speak(msg);
      
    } else {
      String msg = "ما فهمت. ممكن تقول اضف مصروف أو كم الرصيد";
      onResult(msg);
      await _speak(msg);
    }
  }

  Map<String, dynamic> _parseWithRules(String text) {
    text = text.toLowerCase();
    RegExp amountRegex = RegExp(r'(\d+)');
    var amountMatch = amountRegex.firstMatch(text);
    int amount = amountMatch != null ? int.parse(amountMatch.group(0)!) : 0;
    
    if (text.contains('مصروف') || text.contains('صرفت')) {
      return {'action': 'add_expense', 'amount': amount.toDouble(), 'desc': text};
    }
    if (text.contains('ايراد') || text.contains('دخل') || text.contains('مبيعات')) {
      return {'action': 'add_income', 'amount': amount.toDouble(), 'desc': text};
    }
    if (text.contains('كم') && text.contains('رصيد')) {
      return {'action': 'get_balance'};
    }
    return {'action': 'unknown'};
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (_) {}
  }
}
