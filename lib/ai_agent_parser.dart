import 'yemeni_dictionary.dart';

class AiAgentParser {
  static Map<String, dynamic> parseCommandToJson(String text) {
    String normalized = YemeniDictionary.normalizeYemeniText(text);
    normalized = normalized.toLowerCase();

    String type = 'مصروف';
    if (normalized.contains('مبيعات') || normalized.contains('بيع') || normalized.contains('ايراد') || normalized.contains('دخل')) {
      type = 'مبيعات';
    } else if (normalized.contains('مشتريات') || normalized.contains('اشتريت') || normalized.contains('شريت')) {
      type = 'مشتريات';
    } else if (normalized.contains('دين لي') || normalized.contains('على') || normalized.contains('دين لك')) {
      type = 'دين_لي';
    } else if (normalized.contains('دين علي') || normalized.contains('للمورد') || normalized.contains('ديني')) {
      type = 'دين_علي';
    } else if (normalized.contains('مصروف') || normalized.contains('صرفت') || normalized.contains('دفعت') || normalized.contains('بنزين') || normalized.contains('ايجار')) {
      type = 'مصروف';
    }

    double amount = parseArabicNumber(normalized);
    String name = extractName(normalized);

    return {
      "النوع": type,
      "الاسم": name,
      "المبلغ": amount,
      "النص_الاصلي": text,
    };
  }

  static double parseArabicNumber(String text) {
    String clean = text.toLowerCase();
    for (var entry in YemeniDictionary.yemeniNumberWords.entries) {
      if (clean.contains(entry.key)) {
        return entry.value;
      }
    }
    final regExp = RegExp(r'(\d[\d,\.]*)');
    final match = regExp.firstMatch(clean);
    if (match != null) {
      String numStr = match.group(0)!.replaceAll(',', '');
      return double.tryParse(numStr) ?? 0.0;
    }
    return 0.0;
  }

  static String extractName(String text) {
    if (text.contains('على')) {
      List<String> parts = text.split('على');
      if (parts.length > 1) {
        String after = parts[1].trim();
        List<String> sub = after.split(' ');
        if (sub.isNotEmpty) return sub[0];
      }
    }
    if (text.contains('لـ') || text.contains('لاحمد') || text.contains('لأحمد')) {
      return 'أحمد';
    }
    return 'عام';
  }
}
