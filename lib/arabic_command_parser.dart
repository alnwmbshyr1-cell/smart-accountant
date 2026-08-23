import 'ai_agent_parser.dart';

/// Public facade for the deterministic offline Arabic accounting parser.
///
/// The legacy [AiAgentParser] remains the implementation so existing callers
/// keep working, while this class provides a discoverable instance API for new
/// UI, integration, and database code.
class ArabicCommandParser {
  const ArabicCommandParser();

  Map<String, dynamic> parse(String text) {
    final result = AiAgentParser.parseCommandToJson(text);
    return Map<String, dynamic>.unmodifiable(result);
  }

  double parseAmount(String text) => AiAgentParser.parseArabicNumber(text);

  ParsedAccountingCommand parseTyped(String text) {
    return ParsedAccountingCommand.fromMap(parse(text));
  }
}

class ParsedAccountingCommand {
  const ParsedAccountingCommand({
    required this.type,
    required this.table,
    required this.amount,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.rawText,
    this.person,
    this.item,
    required this.date,
    required this.targetTab,
  });

  factory ParsedAccountingCommand.fromMap(Map<String, dynamic> map) {
    return ParsedAccountingCommand(
      type: map['type']?.toString() ?? 'مصروف',
      table: map['table']?.toString() ?? 'expenses',
      amount: _number(map['amount'] ?? map['المبلغ']),
      description:
          map['description']?.toString() ?? map['الوصف']?.toString() ?? 'عام',
      quantity: _number(map['quantity'] ?? map['الكمية'], fallback: 1),
      unitPrice: _number(
        map['unit_price'] ?? map['سعر_الوحدة'],
      ),
      rawText: map['النص_الاصلي']?.toString() ?? '',
      person: _nullableString(map['person'] ?? map['الاسم']),
      item: _nullableString(map['item']),
      date: DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
      targetTab: (map['targetTab'] as num?)?.toInt() ?? 0,
    );
  }

  final String type;
  final String table;
  final double amount;
  final String description;
  final double quantity;
  final double unitPrice;
  final String rawText;
  final String? person;
  final String? item;
  final DateTime date;
  final int targetTab;

  double get total =>
      quantity > 1 && unitPrice > 0 ? quantity * unitPrice : amount;

  bool get isQuery => type == 'استعلام' || table == 'queries';

  bool get canPersist => total > 0 && !isQuery;

  static double _number(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'عام' ? null : text;
  }
}
