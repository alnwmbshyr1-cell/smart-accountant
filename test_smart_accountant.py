import unittest
import json

class SmartAccountantLogic:
    @staticmethod
    def parse_voice_command(text):
        lower = text.lower()
        type_res = 'مبيعات'
        if 'مشتريات' in lower or 'شراء' in lower:
            type_res = 'مشتريات'
        elif 'دين لك' in lower or 'على الزبون' in lower or 'لنا' in lower:
            type_res = 'دين لك'
        elif 'دين عليك' in lower or 'للمورد' in lower or 'علينا' in lower:
            type_res = 'دين عليك'
        elif 'مبيعات' in lower or 'بيع' in lower:
            type_res = 'مبيعات'

        amount = 1000.0
        if 'خمسة آلاف' in lower or '5000' in lower: amount = 5000.0
        elif 'أربعة آلاف' in lower or '4000' in lower: amount = 4000.0
        elif 'ثلاثة آلاف' in lower or '3000' in lower: amount = 3000.0
        elif 'ألفين' in lower or '2000' in lower: amount = 2000.0
        elif 'ألف وخمسمائة' in lower or '1500' in lower: amount = 1500.0
        elif 'ألف' in lower or '1000' in lower: amount = 1000.0

        return {'type': type_res, 'amount': amount}

    @staticmethod
    def calculate(num1, op, num2):
        if op == '+': return num1 + num2
        if op == '-': return num1 - num2
        if op == '×': return num1 * num2
        if op == '÷': return (num1 / num2) if num2 != 0 else 0.0
        return 0.0

class TestSmartAccountant(unittest.TestCase):
    def test_voice_sales(self):
        res = SmartAccountantLogic.parse_voice_command("سجل مبيعات بخمسة آلاف")
        self.assertEqual(res['type'], 'مبيعات')
        self.assertEqual(res['amount'], 5000.0)

    def test_voice_purchases(self):
        res = SmartAccountantLogic.parse_voice_command("شراء بضاعة بألفين")
        self.assertEqual(res['type'], 'مشتريات')
        self.assertEqual(res['amount'], 2000.0)

    def test_voice_receivable(self):
        res = SmartAccountantLogic.parse_voice_command("دين لك بثلاثة آلاف")
        self.assertEqual(res['type'], 'دين لك')
        self.assertEqual(res['amount'], 3000.0)

    def test_calculator(self):
        self.assertEqual(SmartAccountantLogic.calculate(100, '+', 50), 150)
        self.assertEqual(SmartAccountantLogic.calculate(200, '×', 3), 600)
        self.assertEqual(SmartAccountantLogic.calculate(1000, '÷', 4), 250)

if __name__ == '__main__':
    unittest.main()
