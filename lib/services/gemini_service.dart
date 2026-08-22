import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// خدمة Gemini لتحليل الأوامر المحاسبية عند توفر الإنترنت ومفتاح صالح.
///
/// لا تضع مفتاح API داخل الكود أو Git. يُحفظ المفتاح في
/// flutter_secure_storage ويُقرأ عند الحاجة فقط.
class GeminiService {
  GeminiService({
    FlutterSecureStorage? storage,
    this.modelName = 'gemini-1.5-flash',
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String apiKeyStorageKey = 'gemini_api_key';
  static const Duration requestTimeout = Duration(seconds: 20);

  final FlutterSecureStorage _storage;
  final String modelName;
  String? _cachedApiKey;

  Future<String?> readApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }
    try {
      final value = await _storage.read(key: apiKeyStorageKey);
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
{"type":"ايراد" أو "مصروف","amount": رقم موجب,"desc":"وصف قصير"}
القواعد:
- النوع يجب أن يكون "ايراد" أو "مصروف" فقط.
- amount رقم عشري موجب بلا فواصل أو عملة.
- حوّل الألف والمليون والصيغ العربية إلى رقم.
- إذا لم يتضح المبلغ، أرجع amount بقيمة 0.
- إذا لم يتضح النوع، استخدم "مصروف".
الجملة: $input
''';

      final response = await model
          .generateContent([Content.text(prompt)]).timeout(requestTimeout);
      final raw = response.text?.trim();
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
    final type = rawType.contains('ايراد') ||
            rawType.contains('إيراد') ||
            rawType.contains('مبيعات')
        ? 'ايراد'
        : rawType.contains('مصروف') || rawType.contains('مشتريات')
            ? 'مصروف'
            : null;
    if (type == null) return null;

    final amountValue = payload['amount'] ?? payload['المبلغ'];
    final amount = amountValue is num
        ? amountValue.toDouble()
        : double.tryParse(amountValue?.toString().replaceAll(',', '') ?? '');
    if (amount == null || !amount.isFinite || amount < 0) return null;

    final description =
        (payload['desc'] ?? payload['description'] ?? payload['الوصف'] ?? '')
            .toString()
            .trim();
    if (description.isEmpty) return null;

    return <String, dynamic>{
      'type': type,
      'amount': amount,
      'desc': description,
    };
  }
}
