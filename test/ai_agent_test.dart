import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v2.5.0 Local AI JSON Parsing & Yemeni Dialect Tests', () {
    final aiAgent = AiAgentService();

    test('Parse Voice Command to Strict JSON structure', () {
      var json1 = aiAgent.parseCommandToJson('سجلت امس دين على احمد بمئة الف');
      expect(json1['النوع'], 'دين_لي');
      expect(json1['الاسم'], 'احمد');
      expect(json1['المبلغ'], 100000.0);

      var json2 = aiAgent.parseCommandToJson('مبيعات بمليون ريال');
      expect(json2['النوع'], 'مبيعات');
      expect(json2['المبلغ'], 1000000.0);

      var json3 = aiAgent.parseCommandToJson('سجل مصروف بنزين بعشرين ألف');
      expect(json3['النوع'], 'مصروف');
      expect(json3['المبلغ'], 20000.0);
    });

    test('Process voice command with SQLite persistence and spoken confirmation', () async {
      String lastReply = '';
      var result = await aiAgent.processVoiceCommandText('سجلت امس دين على احمد بمئة الف', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'debt_to_me');
      expect(result['amount'], 100000.0);
      expect(result['targetTab'], 2);
      expect(lastReply.contains('100,000') || lastReply.contains('100000'), true);
    });
  });
}
