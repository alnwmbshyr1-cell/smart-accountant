import 'yemeni_dictionary.dart';

class AiAgentParser {
  static Map<String, dynamic> parseCommandToJson(String text) {
    final normalized = YemeniDictionary.normalizeYemeniText(text).toLowerCase();
    final type = _classify(normalized);
    final amount = parseArabicNumber(normalized);
    final name = extractName(normalized);
    final description = _extractDescription(normalized, type, name);
    return {
      'النوع': type,
      'الاسم': name,
      'المبلغ': amount,
      'الوصف': description,
      'النص_الاصلي': text,
      'targetTab': _targetTab(type),
    };
  }

  static String _classify(String text) {
    if (text.contains('دين_علي') ||
        text.contains('دين علي') ||
        text.contains('ديني') ||
        text.contains('للمورد') ||
        text.contains('لي عندي')) {
      return 'دين_علي';
    }
    if (text.contains('دين_لي') ||
        text.contains('دين لي') ||
        text.contains('دين لك') ||
        text.contains('على ') ||
        text.contains('في ذمته')) {
      return 'دين_لي';
    }
    if (text.contains('مشتريات') ||
        text.contains('اشتريت') ||
        text.contains('شريت')) {
      return 'مشتريات';
    }
    if (text.contains('مخزن') ||
        text.contains('مخزون') ||
        text.contains('اصناف') ||
        text.contains('صنف')) {
      return 'مخزون';
    }
    if (text.contains('مبيعات') ||
        text.contains('بيع') ||
        text.contains('ايراد') ||
        text.contains('دخل') ||
        text.contains('بعت')) {
      return 'مبيعات';
    }
    return 'مصروف';
  }

  static int _targetTab(String type) {
    switch (type) {
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

  static double parseArabicNumber(String text) {
    final clean = text.toLowerCase();
    for (final entry in YemeniDictionary.yemeniNumberWords.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }
    final match = RegExp(r'(\d[\d,\.]*)').firstMatch(clean);
    if (match != null) {
      return double.tryParse(match.group(0)!.replaceAll(',', '')) ?? 0;
    }
    return 0;
  }

  static String extractName(String text) {
    final match =
        RegExp(r'(?:على|لدى|ل|مع)\s+([\u0621-\u064A]+)').firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }
    return 'عام';
  }

  static String _extractDescription(String text, String type, String name) {
    var result = text;
    for (final token in [
      'سجل',
      'سجلت',
      'اضف',
      'أضف',
      'عملية',
      'اليوم',
      'امس',
      'بمبلغ',
      'ريال',
      'دين لي',
      'دين علي',
      'مبيعات',
      'مشتريات',
      'مخزن',
      'مخزون',
      'مصروف',
      'على $name',
      'لدى $name',
      'بـ$name',
      'ب$name',
    ]) {
      result = result.replaceAll(token, ' ');
    }
    return result.replaceAll(RegExp(r'\s+'), ' ').trim().isEmpty
        ? type
        : result.trim();
  }
}
