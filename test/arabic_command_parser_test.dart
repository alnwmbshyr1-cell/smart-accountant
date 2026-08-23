import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/arabic_command_parser.dart';

void main() {
  const parser = ArabicCommandParser();

  test('parses a compound Arabic amount through the public facade', () {
    final result = parser.parseTyped('سجل مصروف مليونين وخمسمية');

    expect(result.type, 'مصروف');
    expect(result.table, 'expenses');
    expect(result.amount, 2000500);
    expect(result.total, 2000500);
    expect(result.canPersist, isTrue);
  });

  test('keeps item quantity and unit price structured', () {
    final result = parser.parseTyped(
      'سجل مشتريات 10 اكياس رز كل كيس 15000',
    );

    expect(result.type, 'مشتريات');
    expect(result.table, 'purchases');
    expect(result.quantity, 10);
    expect(result.unitPrice, 15000);
    expect(result.total, 150000);
    expect(result.description, 'اكياس رز');
  });

  test('exposes a normalized amount parser', () {
    expect(parser.parseAmount('مليون و مئتين الف'), 1200000);
    expect(parser.parseAmount('١٢,٥٠٠'), 12500);
  });
}
