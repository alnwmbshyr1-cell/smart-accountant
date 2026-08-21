import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'database_service.dart';

class AiAgentService {
  final FlutterTts _tts = FlutterTts();
  final DatabaseService _db = DatabaseService();
  
  bool _isListening = false;
  bool _isAssistantMode = false;

  bool get isListening => _isListening;
  bool get isAssistantMode => _isAssistantMode;

  Future<void> init() async {
    try {
      await _tts.setLanguage("ar-SA");
      await _tts.setSpeechRate(0.85);
      await _tts.setPitch(1.0); // صوت رجولي دافئ
      await downloadGemmaModelIfNotExists();
    } catch (_) {}
  }

  Future<void> downloadGemmaModelIfNotExists() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/gemma-2b-it-q4.bin');
      if (!await modelFile.exists()) {
        final dio = Dio();
        // رابط التحميل من GitHub Release الإصدار v2.0.1 (أو رابط بديل مباشر)
        const modelUrl = 'https://github.com/alnwmbshyr1-cell/smart-accountant/releases/download/models/gemma-2b-it-q4.bin';
        await dio.download(modelUrl, modelFile.path, onReceiveProgress: (received, total) {
          // progress tracking if needed
        });
      }
    } catch (e) {
      // Offline fallback / graceful handling
    }
  }

  void startAssistant() {
    _isAssistantMode = true;
    _isListening = true;
  }

  void stopAssistant() {
    _isAssistantMode = false;
    _isListening = false;
  }

  Future<void> speakYemeni(String text) async {
    await init();
    String yemeniText = text;
    if (!text.contains("ابشر") && !text.contains("أبشر")) {
      yemeniText = "أبشر يا شيخ، $text";
    }
    await _tts.speak(yemeniText);
  }

  Future<Map<String, dynamic>> processVoiceCommandText(String voiceText, Function(String) onResult) async {
    await init();
    String lower = voiceText.toLowerCase();
    
    // 1. استعلام عن المصروفات اليومية أو التقارير (get_report)
    if (lower.contains("كم صرفت") || lower.contains("المصروفات اليومية") || lower.contains("صرفت اليوم") || lower.contains("تقرير")) {
      double total = await _db.getTodayTotal('مصروف');
      String msg = "صرفت اليوم يا غالي مبلغ وقدره $total ريال يمني. عسى الأمور طيبة؟";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "get_report", "result": total, "reply": msg};
    }

    // 2. البحث عن العمليات (search)
    if (lower.contains("ابحث عن") || lower.contains("بحث") || lower.contains("وين")) {
      String query = lower.replaceAll("ابحث عن", "").replaceAll("بحث", "").trim();
      List<Map<String, dynamic>> results = await _db.searchTransactions(query);
      String msg = "أبشر، لقيت لك ${results.length} عمليات مطابقة للبحث يا ذيبان.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "search", "query": query, "results": results, "reply": msg};
    }

    // 3. إضافة مصروف أو عملية (add_expense)
    if (lower.contains("صرفت") || lower.contains("اشتريت") || lower.contains("دفعت") || lower.contains("سجل مصروف")) {
      RegExp amountRegex = RegExp(r'(\d+)');
      var amountMatch = amountRegex.firstMatch(lower);
      double amount = amountMatch != null ? double.parse(amountMatch.group(0)!) : 5000;

      await _db.addTransaction(
        type: 'مصروف',
        amount: amount,
        description: voiceText,
      );

      double total = await _db.getTodayTotal('مصروف');
      String msg = "تم تسجيل المصروف بمبلغ $amount ريال. إجمالي مصروفات اليوم $total ريال يا شيخ.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "add_expense", "amount": amount, "reply": msg};
    }

    // 4. الرصيد أو الإيرادات
    if (lower.contains("كم") && lower.contains("رصيد")) {
      double balance = await _db.getBalance();
      String msg = "رصيدك الحالي يا طويل العمر $balance ريال يمني.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "get_balance", "balance": balance, "reply": msg};
    }

    // رد افتراضي بالشخصية اليمنية الودودة
    String defaultReply = "يا هلا بك يا شيخ، آمرني وش بغيت؟ أقدر أسجل مصروفك، أطلع لك تقرير اليوم، أو أبحث لك عن أي عملية.";
    onResult(defaultReply);
    await speakYemeni(defaultReply);
    return {"action": "unknown", "reply": defaultReply};
  }
}
