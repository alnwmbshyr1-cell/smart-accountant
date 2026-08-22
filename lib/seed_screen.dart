import 'package:flutter/material.dart';
import 'seed_database.dart';

class SeedScreen extends StatefulWidget {
  const SeedScreen({Key? key}) : super(key: key);

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  bool _isGenerating = false;
  String _statusMessage = "جاهز لتوليد 10,000,000 عملية تجريبية في الخلفية على دفعات 50,000";
  double _progress = 0.0;

  Future<void> _startSeed() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
      _statusMessage = "جاري البدء في حقن 10 مليون عملية...";
    });

    try {
      await SeedDatabase.generateMassiveData(
        onProgress: (current, total, status) {
          setState(() {
            _progress = current / total;
            _statusMessage = status;
          });
        },
      );
      setState(() {
        _isGenerating = false;
        _statusMessage = "تم إنشاء 10,000,000 عملية بنجاح!";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("تم إنشاء 10,000,000 عملية بنجاح!")),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _statusMessage = "حدث خطأ أثناء التوليد: $e";
      });
    }
  }

  Future<void> _clearSeed() async {
    setState(() {
      _isGenerating = true;
      _statusMessage = "جاري مسح البيانات التجريبية بأمان...";
    });

    try {
      int count = await SeedDatabase.clearSeedData();
      setState(() {
        _isGenerating = false;
        _statusMessage = "تم مسح $count سجل تجريبي بنجاح والحفاظ على بياناتك الحقيقية.";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("تم مسح $count سجل تجريبي بنجاح!")),
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _statusMessage = "حدث خطأ أثناء المسح: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("بيانات التدريب والذكاء (10 مليون سجل)"),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storage, size: 80, color: Color(0xFF0D47A1)),
            const SizedBox(height: 20),
            const Text(
              "توليد قاعدة بيانات تجريبية ضخمة",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
            ),
            const SizedBox(height: 10),
            const Text(
              "تتضمن 10 مليون عملية موزعة على (مبيعات، مشتريات، مصروفات، ديون) بصيغ يمنية متنوعة للتدريب والتدقيق.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            LinearProgressIndicator(value: _progress, minHeight: 10, backgroundColor: Colors.grey.shade300, color: const Color(0xFFFFC107)),
            const SizedBox(height: 15),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGenerating ? null : _startSeed,
              icon: const Icon(Icons.play_arrow),
              label: const Text("توليد 10 مليون عملية في الخلفية", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 15),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade700),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isGenerating ? null : _clearSeed,
              icon: const Icon(Icons.delete_sweep),
              label: const Text("مسح البيانات التجريبية", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
