import 'package:flutter/material.dart';
import 'ai_agent_service.dart';

class DictionaryTestScreen extends StatefulWidget {
  const DictionaryTestScreen({super.key});

  @override
  State<DictionaryTestScreen> createState() => _DictionaryTestScreenState();
}

class _DictionaryTestScreenState extends State<DictionaryTestScreen> {
  final AiAgentService _aiAgent = AiAgentService();
  final TextEditingController _customController = TextEditingController();

  String _testResult =
      "اختر عبارة من القاموس أدناه أو اكتب جملة يمنية لاختبارها فوراً";
  bool _isLoading = false;

  final List<String> samplePhrases = [
    "بعت بضاعة بمئة ألف",
    "اشتريت دبات بنزين بعشرين ألف",
    "صرفت حق العشاء خمسة ألف",
    "دين لي على أحمد بمئة الف",
    "دين علي للمورد بخمسين الف",
    "كم صرفت اليوم يا عاقل",
    "ابحث عن بنزين",
  ];

  Future<void> _runTest(String phrase) async {
    setState(() {
      _isLoading = true;
      _testResult = "جاري تحليل: \"$phrase\" بالذكاء المحلي والقاموس اليمني...";
    });

    try {
      var result = await _aiAgent.processVoiceCommandText(phrase, (reply) {});
      setState(() {
        _testResult = "✅ نتيجة التحليل:\n"
            "• الجملة: $phrase\n"
            "• الإجراء: ${result['action']}\n"
            "• المبلغ: ${result['amount'] ?? 0} ريال\n"
            "• الرد الصوتي: ${result['reply']}";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = "❌ خطأ في المعالجة: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("مركز اختبار القاموس اليمني والذكاء"),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "اختر عبارة يمنية معتمدة لاختبار المحلل الصوتي والمالي فوراً:",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 10),
            Expanded(
              flex: 2,
              child: ListView.builder(
                itemCount: samplePhrases.length,
                itemBuilder: (context, index) {
                  String phrase = samplePhrases[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(phrase,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.play_arrow,
                          color: Color(0xFF0D47A1)),
                      onTap: () => _runTest(phrase),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 20),
            TextField(
              controller: _customController,
              decoration: InputDecoration(
                labelText: "اكتب أي جملة أو أمر يمني تجريبي",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF0D47A1)),
                  onPressed: () {
                    if (_customController.text.isNotEmpty) {
                      _runTest(_customController.text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "نتيجة الاختبار الفوري:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Text(
                          _testResult,
                          style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontFamily: 'monospace'),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
