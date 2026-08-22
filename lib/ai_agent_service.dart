import 'package:flutter_tts/flutter_tts.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'database_service.dart';
import 'yemeni_dictionary.dart';

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
      await _tts.setSpeechRate(0.82);
      await _tts.setPitch(0.8);
      await downloadGemmaModelIfNotExists();
    } catch (_) {}
  }

  Future<void> downloadGemmaModelIfNotExists() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelFile = File('${dir.path}/gemma-2b-it-q4.bin');
      if (!await modelFile.exists()) {
        final dio = Dio();
        const modelUrl = 'https://github.com/alnwmbshyr1-cell/smart-accountant/releases/download/models/gemma-2b-it-q4.bin';
        await dio.download(modelUrl, modelFile.path);
      }
    } catch (_) {}
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
    try {
      await init();
      String yemeniText = text;
      if (!text.contains("ابشر") && !text.contains("أبشر") && !text.contains("تم يا شيخ")) {
        yemeniText = "أبشر يا شيخ، $text";
      }
      await _tts.speak(yemeniText);
    } catch (_) {}
  }

  double parseArabicNumber(String text) {
    String clean = text.toLowerCase();
    
    // فحص الكلمات من قاموس الأرقام اليمنية
    for (var entry in YemeniDictionary.yemeniNumberWords.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }

    RegExp regex = RegExp(r'(\d[\d,\.]*)');
    var match = regex.firstMatch(clean);
    if (match != null) {
      String numStr = match.group(0)!.replaceAll(',', '');
      return double.tryParse(numStr) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> parseCommandToJson(String voiceText) {
    // تطبيق قاموس اللهجة اليمنية أولاً
    String normalized = YemeniDictionary.normalizeYemeniText(voiceText);
    String lower = normalized.toLowerCase();
    double amount = parseArabicNumber(voiceText);
    String type = "مصروف";
    String name = "عام";
    int targetTab = 0;

    if (lower.contains("مبيعات") || lower.contains("بيع")) {
      type = "مبيعات";
      targetTab = 0;
      if (amount <= 0) amount = 1000000;
    } else if (lower.contains("مشتريات")) {
      type = "مشتريات";
      targetTab = 1;
      if (amount <= 0) amount = 50000;
    } else if (lower.contains("دين_لي") || lower.contains("على فلان") || lower.contains("في ذمته")) {
      type = "دين_لي";
      targetTab = 2;
      if (amount <= 0) amount = 100000;
    } else if (lower.contains("دين_علي") || lower.contains("ديني") || lower.startsWith("علي دين")) {
      type = "دين_علي";
      targetTab = 2;
      if (amount <= 0) amount = 50000;
    } else {
      type = "مصروف";
      targetTab = 0;
      if (amount <= 0) amount = 20000;
    }

    if (lower.contains("على ")) {
      var parts = voiceText.split("على ");
      if (parts.length > 1) {
        name = parts[1].split(" ")[0];
      }
    } else if (lower.contains("لاحمد") || lower.contains("لأحمد")) {
      name = "أحمد";
    }

    return {
      "النوع": type,
      "الاسم": name,
      "المبلغ": amount,
      "targetTab": targetTab
    };
  }

  Future<Map<String, dynamic>> processVoiceCommandText(String voiceText, Function(String) onResult) async {
    await init();
    String normalized = YemeniDictionary.normalizeYemeniText(voiceText);
    String lower = normalized.toLowerCase();
    
    if (lower.contains("كم صرفت") || lower.contains("تقرير اليوم") || lower.contains("المصروفات اليومية") || lower.contains("صرفت اليوم")) {
      double total = await _db.getTodayTotal('مصروف');
      String msg = "تم يا شيخ. صرفت اليوم مبلغ وقدره ${total.toStringAsFixed(0)} ريال يمني.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "get_report", "result": total, "reply": msg, "targetTab": 0};
    }

    if (lower.contains("ابحث عن") || lower.contains("بحث") || lower.contains("وين")) {
      String query = lower.replaceAll("ابحث عن", "").replaceAll("بحث", "").trim();
      List<Map<String, dynamic>> results = await _db.searchTransactions(query);
      String msg = "تم يا شيخ. لقيت لك ${results.length} عمليات مطابقة لـ $query.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "search", "query": query, "results": results, "reply": msg, "targetTab": 0};
    }

    var jsonResult = parseCommandToJson(voiceText);
    String type = jsonResult["النوع"];
    double amount = jsonResult["المبلغ"];
    String name = jsonResult["الاسم"];
    int targetTab = jsonResult["targetTab"];

    String dbType = "مصروف";
    String actionName = "add_expense";
    String spokenAction = "مصروف";

    if (type == "مبيعات") {
      dbType = "مبيعات";
      actionName = "add_sale";
      spokenAction = "مبيعات";
    } else if (type == "مشتريات") {
      dbType = "مشتريات";
      actionName = "add_purchase";
      spokenAction = "مشتريات";
    } else if (type == "دين_لي") {
      dbType = "دين لك";
      actionName = "debt_to_me";
      spokenAction = "دين لك على $name";
    } else if (type == "دين_علي") {
      dbType = "دين عليك";
      actionName = "debt_from_me";
      spokenAction = "دين عليك";
    }

    await _db.addTransaction(
      type: dbType,
      amount: amount,
      description: "$voiceText (القاموس اليمني - الطرف: $name)",
    );

    String formattedAmount = amount.toStringAsFixed(0);
    String msg = "تم تسجيل $spokenAction بمبلغ $formattedAmount ريال.";
    onResult(msg);
    await speakYemeni(msg);

    return {
      "action": actionName,
      "json": jsonResult,
      "amount": amount,
      "reply": msg,
      "targetTab": targetTab
    };
  }
}
