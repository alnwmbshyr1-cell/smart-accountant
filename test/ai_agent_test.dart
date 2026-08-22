import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/yemeni_dictionary.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('v3.1.0 Indexed SQLite & Yemeni Dialect Tests', () {
    final aiAgent = AiAgentService();

    test('Verify Yemeni Dictionary normalization for local slang terms', () {
      expect(YemeniDictionary.normalizeYemeniText('بعت بضاعة'), 'مبيعات بضاعة');
      expect(YemeniDictionary.normalizeYemeniText('اشتريت دبات'), 'مشتريات دبات');
      expect(YemeniDictionary.normalizeYemeniText('صرفت عشرين ألف'), 'مصروف عشرين ألف');
    });

    test('Parse Yemeni Dialect Voice Command to JSON structure', () {
      var json1 = aiAgent.parseCommandToJson('بعت بضاعة بمئة ألف');
      expect(json1['النوع'], 'مبيعات');
      expect(json1['المبلغ'], 100000.0);

      var json2 = aiAgent.parseCommandToJson('اشتريت عشرة آلاف');
      expect(json2['النوع'], 'مشتريات');
      expect(json2['المبلغ'], 10000.0);

      var json3 = aiAgent.parseCommandToJson('صرفت عشرين ألف بنزين');
      expect(json3['النوع'], 'مصروف');
      expect(json3['المبلغ'], 20000.0);
    });

    test('Process voice command using Yemeni dictionary with Indexed SQLite persistence', () async {
      String lastReply = '';
      var result = await aiAgent.processVoiceCommandText('بعت بضاعة بمئة ألف', (reply) {
        lastReply = reply;
      });

      expect(result['action'], 'add_sale');
      expect(result['amount'], 100000.0);
      expect(result['targetTab'], 0);
      expect(lastReply.contains('مبيعات'), true);
    });
  });
}
