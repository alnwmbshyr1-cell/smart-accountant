import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Advanced Yemeni Dialect & Complex Voice AI Agent Tests', () {
    final aiAgent = AiAgentService();

    test('Parse complex Arabic and Yemeni number representations correctly', () {
      expect(aiAgent.parseArabicNumber('سجل مصروف بنزين بعشرين ألف'), 20000.0);
      expect(aiAgent.parseArabicNumber('دين لي على خالد بمئة ألف'), 100000.0);
      expect(aiAgent.parseArabicNumber('مبيعات بمليون ريال'), 1000000.0);
      expect(aiAgent.parseArabicNumber('اشتريت بضاعة بخمسين ألف'), 50000.0);
      expect(aiAgent.parseArabicNumber('صرفت الفين ريال لقيمة غداء'), 2000.0);
    });

    test('Process complex voice command: Sales with long sentence and Yemeni phrasing', () async {
      String lastReply = '';
      var result = await aiAgent.processVoiceCommandText('امس بعت لاحمد بضاعة بمليون ريال اجل', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'add_sale');
      expect(result['amount'], 1000000.0);
      expect(result['targetTab'], 0);
      expect(lastReply.contains('مبيعات'), true);
    });

    test('Process complex voice command: Purchases in Yemeni dialect', () async {
      String lastReply = '';
      var result = await aiAgent.processVoiceCommandText('اشتريت بضاعة جديدة بخمسين ألف', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'add_purchase');
      expect(result['amount'], 50000.0);
      expect(result['targetTab'], 1);
      expect(lastReply.contains('مشتريات'), true);
    });

    test('Process complex voice command: Debt from me (دين علي)', () async {
      String lastReply = '';
      var result = await aiAgent.processVoiceCommandText('علي دين للمورد بخمسين ألف ريال', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'debt_from_me');
      expect(result['amount'], 50000.0);
      expect(result['targetTab'], 2);
      expect(lastReply.contains('دين عليك'), true);
    });

    test('Process complex voice command: Report and search queries', () async {
      String lastReply = '';
      var resultReport = await aiAgent.processVoiceCommandText('كم صرفت اليوم يا عاقل', (reply) {
        lastReply = reply;
      });
      expect(resultReport['action'], 'get_report');

      var resultSearch = await aiAgent.processVoiceCommandText('ابحث عن بنزين', (reply) {
        lastReply = reply;
      });
      expect(resultSearch['action'], 'search');
    });
  });
}
