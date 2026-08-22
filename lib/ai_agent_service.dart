import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'dart:convert';

import 'services/vosk_service.dart';
import 'database_service.dart';
import 'services/gemini_service.dart';
import 'yemeni_dictionary.dart';
import 'ai_agent_parser.dart';

class AiAgentService {
  AiAgentService({GeminiService? gemini}) : _gemini = gemini ?? GeminiService();

  final FlutterTts _tts = FlutterTts();
  final DatabaseService _db = DatabaseService();
  final GeminiService _gemini;

  bool _isListening = false;
  bool _isAssistantMode = false;
  bool _wakeWordEnabled = false;
  bool _commandMode = false;
  bool _porcupineActive = false;
  Timer? _commandTimer;
  String _commandText = '';
  final VoskService _voskService = VoskService();
  StreamSubscription<String>? _partialSubscription;
  StreamSubscription<String>? _resultSubscription;
  PorcupineManager? _porcupineManager;
  Future<void> Function()? _onWakeWord;
  Future<void> Function(String command)? _onCommand;
  void Function(String status)? _onWakeStatus;

  bool get isListening => _isListening;
  bool get isAssistantMode => _isAssistantMode;

  Future<void> init() async {
    try {
      await _tts.setLanguage("ar-SA");
      await _tts.setSpeechRate(0.82);
      await _tts.setPitch(0.8);
      await _initVosk();
    } catch (_) {}
  }

  Future<void> _initVosk() => _voskService.init();

  void startAssistant() {
    _isAssistantMode = true;
    _isListening = true;
  }

  void stopAssistant() {
    _isAssistantMode = false;
    _isListening = false;
  }

  bool get isWakeWordEnabled => _wakeWordEnabled;
  bool get isCommandMode => _commandMode;

  /// يبدأ الاستماع الخفيف. يستخدم Porcupine إذا توفر AccessKey وملف ppn،
  /// وإلا يستخدم Vosk المحلي دون أي اتصال شبكي.
  Future<void> startWakeWordListening({
    required Future<void> Function() onWakeWord,
    required Future<void> Function(String command) onCommand,
    void Function(String status)? onStatus,
    String? porcupineAccessKey,
    String? keywordPath,
  }) async {
    await stopWakeWordListening();
    _wakeWordEnabled = true;
    _onWakeWord = onWakeWord;
    _onCommand = onCommand;
    _onWakeStatus = onStatus;

    final accessKey = porcupineAccessKey ??
        const String.fromEnvironment('PICOVOICE_ACCESS_KEY');
    final customKeywordPath =
        keywordPath ?? const String.fromEnvironment('PICOVOICE_KEYWORD_PATH');

    if (accessKey.isNotEmpty && customKeywordPath.isNotEmpty) {
      try {
        _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey,
          [customKeywordPath],
          (_) => _handleWakeWord(),
          errorCallback: (error) => _onWakeStatus?.call(
            'تعذر تشغيل Porcupine: ${error.message}',
          ),
        );
        await _porcupineManager!.start();
        _porcupineActive = true;
        _onWakeStatus?.call('الاستماع الخفيف فعال عبر Porcupine');
        return;
      } catch (error) {
        _onWakeStatus?.call('تم التحويل للاستماع العربي البديل: $error');
      }
    }

    await _startVoskWakeWordFallback();
  }

  Future<void> _startVoskWakeWordFallback() async {
    if (!_wakeWordEnabled || _commandMode) return;
    try {
      await _initVosk();
      final service = await _voskService.ensureSpeechService();
      await _partialSubscription?.cancel();
      _partialSubscription = service.onPartial().listen((raw) {
        final text = _extractVoskText(raw);
        final normalized = _normalizeWakeText(text);
        if (normalized.contains('يا محاسب') ||
            normalized.contains('يا حسابات')) {
          unawaited(_handleWakeWord());
        }
      });
      _onWakeStatus?.call('المحاسب يستمع محلياً دون إنترنت... قل يا محاسب');
      await service.start();
    } catch (error) {
      _onWakeStatus?.call('تعذر تشغيل Vosk المحلي: $error');
    }
  }

  Future<void> _handleWakeWord() async {
    if (!_wakeWordEnabled || _commandMode) return;
    _commandMode = true;
    await _voskService.stop();
    _onWakeStatus?.call('تم التعرف على كلمة التنشيط');
    await speakYemeni('نعم يا شيخ');
    await _onWakeWord?.call();
    await _startFiveSecondCommandCapture();
  }

  Future<void> _startFiveSecondCommandCapture() async {
    if (!_wakeWordEnabled) return;
    _commandText = '';
    try {
      await _voskService.stop();
      await _resultSubscription?.cancel();
      final service = await _voskService.ensureSpeechService();
      _resultSubscription = service.onResult().listen((raw) {
        final text = _extractVoskText(raw);
        if (text.isNotEmpty) _commandText = text;
      });
      _onWakeStatus?.call('تفضل يا شيخ، أتكلم الآن لمدة 5 ثوانٍ');
      await service.start();
    } catch (error) {
      _onWakeStatus?.call('تعذر بدء تسجيل Vosk: $error');
    }
    _commandTimer?.cancel();
    _commandTimer = Timer(const Duration(seconds: 5), () {
      unawaited(_finishFiveSecondCommandCapture());
    });
  }

  Future<void> _finishFiveSecondCommandCapture() async {
    _commandTimer?.cancel();
    await _voskService.stop();
    final command = _commandText.trim();
    if (command.isNotEmpty) {
      await _onCommand?.call(command);
    } else {
      _onWakeStatus?.call('لم أسمع الأمر يا شيخ');
    }
    _commandMode = false;
    if (_wakeWordEnabled && !_porcupineActive) {
      await _startVoskWakeWordFallback();
    }
  }

  Future<void> stopWakeWordListening() async {
    _wakeWordEnabled = false;
    _commandMode = false;
    _commandTimer?.cancel();
    _commandTimer = null;
    try {
      await _voskService.stop();
      await _partialSubscription?.cancel();
      await _resultSubscription?.cancel();
    } catch (_) {}
    if (_porcupineManager != null) {
      try {
        await _porcupineManager!.stop();
        await _porcupineManager!.delete();
      } catch (_) {}
      _porcupineManager = null;
    }
    _porcupineActive = false;
  }

  Future<void> disposeVoiceResources() async {
    await stopWakeWordListening();
    await _voskService.dispose();
  }

  static String _extractVoskText(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return (decoded['text'] ?? decoded['partial'] ?? '').toString();
      }
    } catch (_) {}
    return raw;
  }

  static String _normalizeWakeText(String input) {
    return input
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ًٌٍَُِّْ]'), '')
        .replaceAll(RegExp(r'\\s+'), ' ')
        .trim();
  }

  /// يسجل من ميكروفون Vosk لمدة ثابتة دون speech_to_text أو شبكة.
  Future<String?> startListening10Seconds() async {
    try {
      await _initVosk();
      _commandText = '';
      await _voskService.stop();
      await _resultSubscription?.cancel();
      final service = await _voskService.ensureSpeechService();
      _resultSubscription = service.onResult().listen((raw) {
        final text = _extractVoskText(raw).trim();
        if (text.isNotEmpty) _commandText = text;
      });
      await service.start();
      await Future<void>.delayed(const Duration(seconds: 10));
      await service.stop();
      final finalRaw = await _voskService.recognizer!.getFinalResult();
      final finalText = _extractVoskText(finalRaw).trim();
      if (finalText.isNotEmpty) _commandText = finalText;
      await _resultSubscription?.cancel();
      return _commandText.isEmpty ? null : _commandText;
    } catch (error) {
      _onWakeStatus?.call('تعذر التسجيل المحلي عبر Vosk: $error');
      return null;
    }
  }

  Future<void> speakYemeni(String text) async {
    try {
      await init();
      String yemeniText = text;
      if (!text.contains("ابشر") &&
          !text.contains("أبشر") &&
          !text.contains("تم يا شيخ")) {
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

  /// يرسل النص إلى Gemini عند توفر مفتاح وشبكة، ويرجع null كي يعمل fallback المحلي.
  Future<Map<String, dynamic>?> processWithGemini(String voiceText) {
    return _gemini.processCommand(voiceText);
  }

  Map<String, dynamic> parseCommandToJson(String voiceText) {
    return AiAgentParser.parseCommandToJson(voiceText);
  }

  Future<Map<String, dynamic>> processVoiceCommandText(
      String voiceText, Function(String) onResult) async {
    await init();
    String normalized = YemeniDictionary.normalizeYemeniText(voiceText);
    String lower = normalized.toLowerCase();

    if (lower.contains("كم صرفت") ||
        lower.contains("تقرير اليوم") ||
        lower.contains("المصروفات اليومية") ||
        lower.contains("صرفت اليوم")) {
      double total = await _db.getTodayTotal('مصروف');
      String msg =
          "تم يا شيخ. صرفت اليوم مبلغ وقدره ${total.toStringAsFixed(0)} ريال يمني.";
      onResult(msg);
      await speakYemeni(msg);
      return {
        "action": "get_report",
        "result": total,
        "reply": msg,
        "targetTab": 0
      };
    }

    if (lower.contains("ابحث عن") ||
        lower.contains("بحث") ||
        lower.contains("وين")) {
      String query =
          lower.replaceAll("ابحث عن", "").replaceAll("بحث", "").trim();
      List<Map<String, dynamic>> results = await _db.searchTransactions(query);
      String msg =
          "تم يا شيخ. لقيت لك ${results.length} عمليات مطابقة لـ $query.";
      onResult(msg);
      await speakYemeni(msg);
      return {
        "action": "search",
        "query": query,
        "results": results,
        "reply": msg,
        "targetTab": 0
      };
    }

    // Gemini هو المسار الأساسي عند وجود مفتاح واتصال. عند أي فشل يعود المحلل المحلي.
    final geminiResult = await processWithGemini(voiceText);
    final Map<String, dynamic> jsonResult =
        geminiResult ?? parseCommandToJson(voiceText);

    final geminiType = jsonResult['type']?.toString();
    final legacyType = jsonResult['النوع']?.toString();
    final semanticType = geminiType ?? legacyType ?? 'مصروف';
    final amountValue = jsonResult['amount'] ?? jsonResult['المبلغ'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse(amountValue?.toString() ?? '') ?? 0;
    final description = (jsonResult['desc'] ??
            jsonResult['description'] ??
            jsonResult['الوصف'] ??
            jsonResult['الاسم'] ??
            'عام')
        .toString()
        .trim();
    final targetTab = jsonResult['targetTab'] is int
        ? jsonResult['targetTab'] as int
        : _targetTabForType(semanticType);

    if (amount <= 0) {
      const message = 'كم المبلغ بالضبط يا شيخ؟';
      onResult(message);
      await speakYemeni(message);
      return {
        'action': 'needs_amount',
        'json': jsonResult,
        'reply': message,
        'targetTab': targetTab,
      };
    }

    final canonicalType = _canonicalType(semanticType);
    final actionName = switch (canonicalType) {
      'مبيعات' => 'add_sale',
      'مشتريات' => 'add_purchase',
      'دين_لي' => 'add_debt_receivable',
      'دين_علي' => 'add_debt_payable',
      'مخزون' => 'add_inventory',
      _ => 'add_expense',
    };
    final spokenAction = switch (canonicalType) {
      'دين_لي' => 'دين لي على $description',
      'دين_علي' => 'دين علي لـ $description',
      'مخزون' => 'إضافة للمخزون $description',
      _ => '$canonicalType $description',
    };

    await _db.addTransaction(
      type: canonicalType,
      amount: amount,
      description: '$description (النص الصوتي: $voiceText)',
    );

    final todayTotal = await _db.getTodayTotal(canonicalType);
    final formattedAmount = amount.toStringAsFixed(0);
    final formattedTotal = todayTotal.toStringAsFixed(0);
    final message =
        'تم تسجيل $spokenAction بمبلغ $formattedAmount ريال. إجمالي $canonicalType اليوم $formattedTotal ريال.';
    onResult(message);
    await speakYemeni(message);

    return {
      'action': actionName,
      'json': jsonResult,
      'amount': amount,
      'reply': message,
      'targetTab': targetTab,
      'source': geminiResult == null ? 'local_fallback' : 'gemini',
    };
  }

  static String _canonicalType(String type) {
    final value = type.trim();
    if (value == 'ايراد' || value == 'إيراد') return 'مبيعات';
    if (value == 'دين لك') return 'دين_لي';
    if (value == 'دين عليك') return 'دين_علي';
    if (value == 'مخزون' || value == 'مخزن') return 'مخزون';
    if (value == 'مشتريات') return 'مشتريات';
    if (value == 'مبيعات') return 'مبيعات';
    return 'مصروف';
  }

  static int _targetTabForType(String type) {
    switch (_canonicalType(type)) {
      case 'مبيعات':
      case 'مشتريات':
        return 1;
      case 'دين_لي':
      case 'دين_علي':
        return 2;
      case 'مخزون':
        return 3;
      default:
        return 0;
    }
  }
}
