import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'dart:convert';

import 'package:vosk_flutter/vosk_flutter.dart';
import 'database_service.dart';
import 'services/gemini_service.dart';
import 'yemeni_dictionary.dart';

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
  late final VoskFlutterPlugin _vosk;
  late final ModelLoader _modelLoader;
  Model? _voskModel;
  Recognizer? _voskRecognizer;
  SpeechService? _voskSpeechService;
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

  Future<void> _initVosk() async {
    if (_voskRecognizer != null) return;
    _vosk = VoskFlutterPlugin.instance();
    _modelLoader = ModelLoader();
    // النموذج الرسمي يُحمّل مرة واحدة عند أول تشغيل لتقليل حجم APK.
    // بعد فك الضغط يبقى في مجلد التطبيق ويعمل Vosk دون إنترنت.
    const modelUrl =
        'https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip';
    final modelName = p.basenameWithoutExtension(modelUrl);
    final alreadyLoaded = await _modelLoader.isModelAlreadyLoaded(modelName);
    final modelPath = alreadyLoaded
        ? await _modelLoader.modelPath(modelName)
        : await _modelLoader.loadFromNetwork(modelUrl);
    _voskModel = await _vosk.createModel(modelPath);
    _voskRecognizer = await _vosk.createRecognizer(
      model: _voskModel!,
      sampleRate: 16000,
    );
  }

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
      final service = _voskSpeechService ??=
          await _vosk.initSpeechService(_voskRecognizer!);
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
    await _voskSpeechService?.stop();
    _onWakeStatus?.call('تم التعرف على كلمة التنشيط');
    await speakYemeni('نعم يا شيخ');
    await _onWakeWord?.call();
    await _startFiveSecondCommandCapture();
  }

  Future<void> _startFiveSecondCommandCapture() async {
    if (!_wakeWordEnabled) return;
    _commandText = '';
    try {
      await _voskSpeechService?.stop();
      await _resultSubscription?.cancel();
      final service = _voskSpeechService ??=
          await _vosk.initSpeechService(_voskRecognizer!);
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
    await _voskSpeechService?.stop();
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
      await _voskSpeechService?.stop();
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
    await _voskSpeechService?.dispose();
    await _voskRecognizer?.dispose();
    _voskModel?.dispose();
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
      await _voskSpeechService?.stop();
      await _resultSubscription?.cancel();
      final service = _voskSpeechService ??=
          await _vosk.initSpeechService(_voskRecognizer!);
      _resultSubscription = service.onResult().listen((raw) {
        final text = _extractVoskText(raw).trim();
        if (text.isNotEmpty) _commandText = text;
      });
      await service.start();
      await Future<void>.delayed(const Duration(seconds: 10));
      await service.stop();
      final finalRaw = await _voskRecognizer!.getFinalResult();
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
    } else if (lower.contains("دين_لي") ||
        lower.contains("على فلان") ||
        lower.contains("في ذمته")) {
      type = "دين_لي";
      targetTab = 2;
      if (amount <= 0) amount = 100000;
    } else if (lower.contains("دين_علي") ||
        lower.contains("ديني") ||
        lower.startsWith("علي دين")) {
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
        : semanticType == 'ايراد' || semanticType == 'مبيعات'
            ? 0
            : 0;

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

    final isRevenue = semanticType == 'ايراد' || semanticType == 'مبيعات';
    final dbType = isRevenue ? 'مبيعات' : 'مصروف';
    final actionName = isRevenue ? 'add_sale' : 'add_expense';
    final spokenAction = isRevenue ? 'مبيعات' : 'مصروف $description';

    await _db.addTransaction(
      type: dbType,
      amount: amount,
      description: '$description (النص الصوتي: $voiceText)',
    );

    final todayTotal = await _db.getTodayTotal(dbType);
    final formattedAmount = amount.toStringAsFixed(0);
    final formattedTotal = todayTotal.toStringAsFixed(0);
    final message =
        'تم تسجيل $spokenAction بمبلغ $formattedAmount ريال. الإجمالي اليوم $formattedTotal ريال.';
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
}
