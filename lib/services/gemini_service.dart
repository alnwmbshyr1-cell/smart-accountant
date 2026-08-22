import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// خدمة Gemini لتحليل الأوامر المحاسبية عند توفر الإنترنت ومفتاح صالح.
///
/// لا تضع مفتاح API داخل الكود أو Git. يُحفظ المفتاح في
/// flutter_secure_storage ويُقرأ عند الحاجة فقط.
typedef GeminiTextProvider = Future<String?> Function(String prompt);
typedef GeminiApiKeyLoader = Future<String?> Function();

class GeminiService {
  GeminiService({
    FlutterSecureStorage? storage,
    this.modelName = 'gemini-1.5-flash',
    this.textProvider,
    this.apiKeyLoader,
    this.timeout = requestTimeout,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String apiKeyStorageKey = 'gemini_api_key';
  static const Duration requestTimeout = Duration(seconds: 20);

  final FlutterSecureStorage _storage;
  final String modelName;
  final GeminiTextProvider? textProvider;
  final GeminiApiKeyLoader? apiKeyLoader;
  final Duration timeout;
  String? _cachedApiKey;

  Future<String?> readApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    try {
      final value = apiKeyLoader != null
          ? await apiKeyLoader!()
          : await _storage.read(key: apiKeyStorageKey);
      final key = value?.trim();
      if (key == null || key.isEmpty) return null;
      _cachedApiKey = key;
      return key;
    } catch (_) {
      // بيئات الاختبار أو المنصات التي لا تسجل plugin تعود للمحلل المحلي.
      return null;
    }
  }

  Future<bool> hasApiKey() async => (await readApiKey()) != null;

  Future<void> saveApiKey(String value) async {
    final key = value.trim();
    if (key.isEmpty) {
      throw ArgumentError('مفتاح Gemini لا يمكن أن يكون فارغاً');
    }
    await _storage.write(key: apiKeyStorageKey, value: key);
    _cachedApiKey = key;
  }

  Future<void> clearApiKey() async {
    await _storage.delete(key: apiKeyStorageKey);
    _cachedApiKey = null;
  }

  /// يرجع JSON محاسبياً منظماً أو null كي يستخدم المستدعي الـ fallback المحلي.
  Future<Map<String, dynamic>?> processCommand(String text) async {
    final input = text.trim();
    if (input.isEmpty) return null;

    final apiKey = await readApiKey();
    if (apiKey == null) return null;

    try {
      final model = GenerativeModel(
        model: modelName,
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 256,
        ),
      );

      final prompt = '''
أنت محاسب يمني دقيق. استخرج من الجملة التالية عملية محاسبية واحدة.
أرجع JSON صالحاً فقط، دون Markdown أو شرح أو نص إضافي.
المخطط الإلزامي:
{"type":"مبيعات" أو "مشتريات" أو "مصروف" أو "دين_لي" أو "دين_علي" أو "مخزون","amount": رقم موجب,"desc":"وصف قصير","name":"اسم الشخص أو الصنف","quantity": رقم اختياري}
القواعد:
- النوع يطابق المعنى: البيع/الدخل مبيعات، الشراء مشتريات، المصروف مصروف، ما لي عند الآخرين دين_لي، ما علي للآخرين دين_علي، إضافة أو نقص البضاعة مخزون.
- amount رقم عشري موجب بلا فواصل أو عملة.
- quantity رقم موجب عند وجود عدد/كمية، وإلا 1.
- حوّل الألف والمليون والصيغ العربية إلى رقم.
- إذا لم يتضح المبلغ، أرجع amount بقيمة 0.
- إذا لم يتضح النوع، استخدم "مصروف".
الجملة: $input
''';

      final raw = textProvider != null
          ? (await textProvider!(prompt).timeout(timeout))?.trim()
          : (await model
                  .generateContent([Content.text(prompt)]).timeout(timeout))
              .text
              ?.trim();
      if (raw == null || raw.isEmpty) return null;

      final decoded = _decodeJsonObject(raw);
      if (decoded == null) return null;
      return _validatePayload(decoded);
    } catch (_) {
      // انقطاع الشبكة أو خطأ API لا يمنع التسجيل المحلي؛ يعاد null للـ fallback.
      return null;
    }
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    var cleaned = raw
        .replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*```$'), '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    try {
      final value = jsonDecode(cleaned);
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Map<String, dynamic>? _validatePayload(Map<String, dynamic> payload) {
    final rawType = (payload['type'] ?? payload['النوع'] ?? '').toString();
    final type = _canonicalType(rawType);
    if (type == null) return null;

    final amountValue = payload['amount'] ?? payload['المبلغ'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse(amountValue?.toString().replaceAll(',', '') ?? '');
    if (amount == null || !amount.isFinite || amount < 0) return null;

    final description = (payload['desc'] ??
            payload['description'] ??
            payload['الوصف'] ??
            payload['name'] ??
            payload['الاسم'] ??
            '')
        .toString()
        .trim();
    if (description.isEmpty) return null;

    final quantityValue = payload['quantity'] ?? payload['الكمية'] ?? 1;
    final quantity = quantityValue is num
        ? quantityValue.toDouble()
        : double.tryParse(quantityValue.toString()) ?? 1;

    return <String, dynamic>{
      'type': type,
      'amount': amount,
      'desc': description,
      'name': (payload['name'] ?? payload['الاسم'] ?? description).toString(),
      'quantity': quantity > 0 ? quantity : 1,
    };
  }

  String? _canonicalType(String rawType) {
    final value = rawType.trim();
    if (value.contains('مبيعات') ||
        value.contains('ايراد') ||
        value.contains('إيراد')) {
      return 'مبيعات';
    }
    if (value.contains('مشتريات') || value.contains('شراء')) {
      return 'مشتريات';
    }
    if (value.contains('دين_لي') ||
        value.contains('دين لي') ||
        value.contains('لي عند')) {
      return 'دين_لي';
    }
    if (value.contains('دين_علي') ||
        value.contains('دين علي') ||
        value.contains('علي دين')) {
      return 'دين_علي';
    }
    if (value.contains('مخزون') ||
        value.contains('مخزن') ||
        value.contains('بضاعة')) {
      return 'مخزون';
    }
    if (value.contains('مصروف') || value.contains('نفقة')) {
      return 'مصروف';
    }
    return null;
  }
}
