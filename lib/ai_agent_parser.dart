import 'yemeni_dictionary.dart';

/// Deterministic, offline Arabic command parser used before any online AI fallback.
///
/// The returned map is intentionally bilingual: legacy keys keep existing callers
/// compatible, while normalized English keys make persistence and UI integration
/// explicit and type-safe.
class AiAgentParser {
  static Map<String, dynamic> parseCommandToJson(String text) {
    final normalized = _normalize(text);
    final type = _classify(normalized);
    final itemized = _parseItemized(normalized);
    final amount = itemized?.total ?? _parseNumber(normalized);
    final quantity = itemized?.quantity ?? 1.0;
    final unitPrice = itemized?.unitPrice ?? amount;
    final person = _extractPerson(normalized, type);
    final description = _extractDescription(
      normalized,
      type,
      person,
      itemized?.item,
    );
    final table = _tableFor(type);
    final result = <String, dynamic>{
      'type': type,
      'table': table,
      'amount': amount,
      'description': description,
      'person': person,
      'item': itemized?.item ?? (type == 'مخزون' ? description : null),
      'quantity': quantity,
      'unit_price': unitPrice,
      'total': amount,
      'date': DateTime.now().toIso8601String(),
      'النوع': type,
      'الاسم': person ?? 'عام',
      'المبلغ': amount,
      'الوصف': description,
      'الكمية': quantity,
      'سعر_الوحدة': unitPrice,
      'النص_الاصلي': text,
      'targetTab': _targetTab(type),
    };
    return result;
  }

  static String _normalize(String input) {
    var value = YemeniDictionary.normalizeYemeniText(input)
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll('٫', '.')
        .replaceAll('،', ',')
        .toLowerCase();
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  static String _classify(String text) {
    // Debt phrases must win over the generic "على"/"شراء" checks.
    if (text.contains('دين لي') ||
        text.contains('دين_لي') ||
        text.contains('لي عند') ||
        text.contains('لي على') ||
        text.contains('في ذمته')) {
      return 'دين_لي';
    }
    if (text.contains('دين علي') ||
        text.contains('دين_علي') ||
        text.contains('علي دين') ||
        text.contains('للمورد') ||
        text.contains('لي عليه')) {
      return 'دين_علي';
    }
    if (text.contains('مخزن') ||
        text.contains('مخزون') ||
        text.contains('كراتين')) {
      return 'مخزون';
    }
    if (text.contains('مشتريات') ||
        text.contains('اشتريت') ||
        text.contains('شريت')) {
      return 'مشتريات';
    }
    if (text.contains('مبيعات') ||
        text.contains('بعت') ||
        text.contains('بيع') ||
        text.contains('ايراد')) {
      return 'مبيعات';
    }
    return 'مصروف';
  }

  static String _tableFor(String type) => switch (type) {
        'مبيعات' => 'sales',
        'مشتريات' => 'purchases',
        'دين_لي' => 'debt_for_me',
        'دين_علي' => 'debt_on_me',
        'مخزون' => 'inventory',
        _ => 'expenses',
      };

  static int _targetTab(String type) => switch (type) {
        'مبيعات' || 'مشتريات' => 1,
        'دين_لي' || 'دين_علي' => 2,
        'مخزون' => 3,
        _ => 0,
      };

  static double parseArabicNumber(String text) =>
      _parseNumber(_normalize(text));

  static double _parseNumber(String text) {
    final clean = text;
    final numeric = RegExp(r'(?<![\w])\d[\d,.]*').firstMatch(clean);
    if (numeric != null) {
      return double.tryParse(numeric.group(0)!.replaceAll(',', '')) ?? 0;
    }

    final phrases = <String, double>{
      'تسعه مليار': 9000000000,
      'تسعة مليار': 9000000000,
      'مليونين وخمسمية': 2000500,
      'مليونين وخمسمائه': 2000500,
      'مليون و مئتين الف': 1200000,
      'مليون و مئه الف': 1100000,
      'مليون': 1000000,
      'مليار': 1000000000,
      'مئة الف': 100000,
      'مئه الف': 100000,
      'مائه الف': 100000,
      'خمسين الف': 50000,
      'عشرين الف': 20000,
      'عشره الاف': 10000,
      'عشرة الاف': 10000,
      'عشرة الف': 10000,
      'خمسة عشر الف': 15000,
      'خمسه عشر الف': 15000,
      'خمسة الف': 5000,
      'خمسه الف': 5000,
      'الفين': 2000,
      'الف': 1000,
      'واحد': 1,
      'اثنين': 2,
      'ثلاثه': 3,
      'ثلاث': 3,
      'اربعه': 4,
      'خمسه': 5,
      'سته': 6,
      'سبعه': 7,
      'ثمانيه': 8,
      'تسعه': 9,
      'عشره': 10,
    };
    final sorted = phrases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final phrase in sorted) {
      if (clean.contains(phrase)) {
        return phrases[phrase]!;
      }
    }

    final words = clean.split(RegExp(r'\s+'));
    var total = 0.0;
    var current = 0.0;
    const ones = <String, double>{
      'واحد': 1,
      'واحده': 1,
      'اثنين': 2,
      'اثنتين': 2,
      'ثلاث': 3,
      'ثلاثه': 3,
      'اربعه': 4,
      'خمسه': 5,
      'سته': 6,
      'سبعه': 7,
      'ثمانيه': 8,
      'تسعه': 9,
      'عشره': 10,
      'عشر': 10,
      'عشرين': 20,
      'ثلاثين': 30,
      'اربعين': 40,
      'خمسين': 50,
      'ستين': 60,
      'سبعين': 70,
      'ثمانين': 80,
      'تسعين': 90,
    };
    for (final word in words) {
      if (ones.containsKey(word)) {
        current += ones[word]!;
      } else if (word == 'الف' || word == 'الفين' || word == 'الاف') {
        total += (current == 0 ? 1 : current) * 1000;
        current = 0;
      } else if (word == 'مليون' || word == 'مليونين') {
        total +=
            (current == 0 ? (word == 'مليونين' ? 2 : 1) : current) * 1000000;
        current = 0;
      } else if (word == 'مليار') {
        total += (current == 0 ? 1 : current) * 1000000000;
        current = 0;
      }
    }
    return total + current;
  }

  static _Itemized? _parseItemized(String text) {
    final patterns = <RegExp>[
      RegExp(r'(\d+(?:\.\d+)?)\s+(.+?)\s+كل\s+[^\s]+\s+(.+)'),
      RegExp(r'(\d+(?:\.\d+)?)\s+(.+?)\s+الكرتون\s+(?:ب|بع)\s*(.+)'),
      RegExp(r'(\d+(?:\.\d+)?)\s+(.+?)\s+الكيس\s+(?:ب|بع)\s*(.+)'),
    ];
    RegExpMatch? match;
    for (final candidate in patterns) {
      match = candidate.firstMatch(text);
      if (match != null) break;
    }
    if (match == null) return null;
    final quantity = double.tryParse(match.group(1)!) ?? 0;
    final unitPrice = _parseNumber(match.group(3)!);
    if (quantity <= 0 || unitPrice <= 0) return null;
    var item = match.group(2)!.trim();
    item = item.replaceFirst(
        RegExp(r'^(اكياس|كراتين|جوالات|اجهزه|الكراتين)\s+'), '');
    return _Itemized(
        item: item.trim(), quantity: quantity, unitPrice: unitPrice);
  }

  static String? _extractPerson(String text, String type) {
    if (type != 'دين_لي' && type != 'دين_علي') return null;
    final patterns = type == 'دين_لي'
        ? [
            r'(?:دين لي|دين_لي) (?:على|علي)\s+([\u0621-\u064A]+)',
            r'لي عند\s+([\u0621-\u064A]+)'
          ]
        : [
            r'(?:دين علي|دين_علي) ل(?:ـ|ل)?\s*([\u0621-\u064A]+)',
            r'علي دين ل(?:ـ|ل)?\s*([\u0621-\u064A]+)',
            r'للمورد\s+([\u0621-\u064A]+)'
          ];
    for (final pattern in patterns) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) return match.group(1);
    }
    return null;
  }

  static String _extractDescription(
      String text, String type, String? person, String? item) {
    if (item != null && item.isNotEmpty) return item;
    if ((type == 'دين_لي' || type == 'دين_علي') &&
        person != null &&
        person.isNotEmpty) {
      return person;
    }
    var value = text;
    const tokens = [
      'سجل مصروف',
      'سجل مشتريات',
      'سجل مبيعات',
      'سجل',
      'مصروف',
      'مشتريات',
      'مبيعات',
      'دين لي',
      'دين علي',
      'على',
      'للمورد',
      'مخزن',
      'مخزون',
      'في',
      'شراء',
      'بيع',
      'كل',
      'واحد',
      'الكرتون',
      'الكيس',
      'بمبلغ',
      'بعشرين',
      'بخمسين',
      'بعشرة',
      'ريال',
      'اليوم',
      'امس',
    ];
    for (final token in tokens) {
      value = value.replaceAll(token, ' ');
    }
    if (person != null) {
      value = value.replaceAll(person, ' ');
    }
    value = value.replaceAll(RegExp(r'\d+(?:\.\d+)?'), ' ');
    for (final key in [
      'مليار',
      'مليون',
      'مليونين',
      'الف',
      'الفين',
      'عشرين',
      'خمسين',
      'عشرة',
      'خمسة',
      'بعشرين',
      'بخمسين',
    ]) {
      value = value.replaceAll(key, ' ');
    }
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value.isEmpty ? type : value;
  }
}

class _Itemized {
  const _Itemized(
      {required this.item, required this.quantity, required this.unitPrice});
  final String item;
  final double quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}
