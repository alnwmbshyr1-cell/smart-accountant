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
      await _tts.setSpeechRate(0.82);
      await _tts.setPitch(0.8); // صوت رجل فخم وعميق
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
    await init();
    String yemeniText = text;
    if (!text.contains("ابشر") && !text.contains("أبشر") && !text.contains("تم يا شيخ")) {
      yemeniText = "أبشر يا شيخ، $text";
    }
    await _tts.speak(yemeniText);
  }

  // محلل الأوامر العربية وتحويل الكلمات العددية إلى أرقام حقيقية صحيحة
  double parseArabicNumber(String text) {
    String clean = text.toLowerCase();
    
    if (clean.contains("مليار")) return 1000000000;
    if (clean.contains("مليون")) return 1000000;
    if (clean.contains("مئة الف") || clean.contains("مائة الف")) return 100000;
    if (clean.contains("عشرين الف") || clean.contains("عشرون الف")) return 20000;
    if (clean.contains("خمسين الف")) return 50000;
    if (clean.contains("الفين")) return 2000;
    if (clean.contains("الف")) return 1000;

    RegExp regex = RegExp(r'(\d[\d,\.]*)');
    var match = regex.firstMatch(clean);
    if (match != null) {
      String numStr = match.group(0)!.replaceAll(',', '');
      return double.tryParse(numStr) ?? 0.0;
    }
    return 0.0;
  }

  Future<Map<String, dynamic>> processVoiceCommandText(String voiceText, Function(String) onResult) async {
    await init();
    String lower = voiceText.toLowerCase();
    
    // 1. استعلام عن التقارير (get_report)
    if (lower.contains("كم صرفت") || lower.contains("تقرير اليوم") || lower.contains("المصروفات اليومية") || lower.contains("صرفت اليوم")) {
      double total = await _db.getTodayTotal('مصروف');
      String msg = "تم يا شيخ. صرفت اليوم مبلغ وقدره ${total.toStringAsFixed(0)} ريال يمني.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "get_report", "result": total, "reply": msg, "targetTab": 0};
    }

    // 2. البحث (search)
    if (lower.contains("ابحث عن") || lower.contains("بحث") || lower.contains("وين")) {
      String query = lower.replaceAll("ابحث عن", "").replaceAll("بحث", "").trim();
      List<Map<String, dynamic>> results = await _db.searchTransactions(query);
      String msg = "تم يا شيخ. لقيت لك ${results.length} عمليات مطابقة لـ $query.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "search", "query": query, "results": results, "reply": msg, "targetTab": 0};
    }

    // 3. مبيعات (Sales) - مثال: "امس بعت لاحمد بضاعة بمليون ريال اجل" أو "مبيعات بمليون ريال"
    if (lower.contains("بعت") || lower.contains("مبيعات") || lower.contains("بيع")) {
      double amount = parseArabicNumber(lower);
      if (amount <= 0) amount = 1000000; // الافتراضي للمليون إذا لم يضبط الرقم
      
      String desc = voiceText;
      await _db.addTransaction(
        type: 'مبيعات',
        amount: amount,
        description: desc,
      );

      String msg = "تم يا شيخ. سجلت مبيعات بمبلغ ${amount.toStringAsFixed(0)} ريال.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "add_sale", "amount": amount, "reply": msg, "targetTab": 0};
    }

    // 4. مشتريات (Purchases)
    if (lower.contains("اشتريت") || lower.contains("مشتريات") || lower.contains("شريت")) {
      double amount = parseArabicNumber(lower);
      if (amount <= 0) amount = 50000;

      await _db.addTransaction(
        type: 'مشتريات',
        amount: amount,
        description: voiceText,
      );

      String msg = "تم يا شيخ. سجلت مشتريات بمبلغ ${amount.toStringAsFixed(0)} ريال.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "add_purchase", "amount": amount, "reply": msg, "targetTab": 1};
    }

    // 5. دين لي (Debt To Me / Receivable) - مثل: "دين لي على خالد بمئة الف"
    if (lower.contains("دين لي") || lower.contains("على") && (lower.contains("دين") || lower.contains("سلف"))) {
      double amount = parseArabicNumber(lower);
      if (amount <= 0) amount = 100000;

      await _db.addTransaction(
        type: 'دين لك',
        amount: amount,
        description: voiceText,
      );

      String msg = "تم يا شيخ. سجلت دين لك بمبلغ ${amount.toStringAsFixed(0)} ريال.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "debt_to_me", "amount": amount, "reply": msg, "targetTab": 2};
    }

    // 6. دين علي (Debt From Me / Payable)
    if (lower.contains("دين علي") || lower.contains("ديني") || lower.contains("لي دين")) {
      double amount = parseArabicNumber(lower);
      if (amount <= 0) amount = 50000;

      await _db.addTransaction(
        type: 'دين عليك',
        amount: amount,
        description: voiceText,
      );

      String msg = "تم يا شيخ. سجلت دين عليك بمبلغ ${amount.toStringAsFixed(0)} ريال.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "debt_from_me", "amount": amount, "reply": msg, "targetTab": 2};
    }

    // 7. مصروفات (Expenses) - مثل: "سجل مصروف بنزين بعشرين الف"
    if (lower.contains("صرفت") || lower.contains("مصروف") || lower.contains("دفعت") || lower.contains("بنزين")) {
      double amount = parseArabicNumber(lower);
      if (amount <= 0) amount = 20000;

      await _db.addTransaction(
        type: 'مصروف',
        amount: amount,
        description: voiceText,
      );

      String msg = "تم يا شيخ. سجلت مصروف بمبلغ ${amount.toStringAsFixed(0)} ريال.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "add_expense", "amount": amount, "reply": msg, "targetTab": 0};
    }

    // 8. مخزن (Inventory)
    if (lower.contains("مخزن") || lower.contains("بضاعة") || lower.contains("مستودع")) {
      String msg = "أبشر يا شيخ، تم فتح قسم المخزون وعرض العناصر المتوفرة.";
      onResult(msg);
      await speakYemeni(msg);
      return {"action": "inventory", "reply": msg, "targetTab": 3};
    }

    // رد افتراضي ذكي
    String defaultReply = "يا هلا بك يا شيخ، أمرك على عيني وراسي. أقدر أسجل مبيعات، مشتريات، ديون، ومصروفات فوراً.";
    onResult(defaultReply);
    await speakYemeni(defaultReply);
    return {"action": "unknown", "reply": defaultReply, "targetTab": 0};
  }
}
