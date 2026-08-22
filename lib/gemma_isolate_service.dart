import 'dart:isolate';
import 'dart:async';
import 'ai_agent_parser.dart';

class GemmaIsolateRequest {
  final String commandText;
  final SendPort replyPort;

  GemmaIsolateRequest({required this.commandText, required this.replyPort});
}

class GemmaIsolateService {
  static Isolate? _isolate;
  static SendPort? _sendPort;
  static bool _isRunning = false;

  /// تهيئة الـ Isolate في الخلفية لإدارة النموذج والاستدلال
  static Future<void> initIsolate() async {
    if (_isRunning) return;

    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, receivePort.sendPort);

    _sendPort = await receivePort.first as SendPort;
    _isRunning = true;
  }

  static void _isolateEntryPoint(SendPort initialReplyPort) async {
    final port = ReceivePort();
    initialReplyPort.send(port.sendPort);

    await for (final message in port) {
      if (message is GemmaIsolateRequest) {
        try {
          // استدلال محلي بالكامل وإرجاع JSON خفيف الوزن للواجهة بدون أخطاء Platform Channel
          final jsonResult =
              AiAgentParser.parseCommandToJson(message.commandText);
          message.replyPort.send(jsonResult);
        } catch (e) {
          message.replyPort.send({
            "النوع": "مصروف",
            "الاسم": "خطأ تحليل",
            "المبلغ": 0.0,
            "error": e.toString(),
          });
        }
      }
    }
  }

  /// إرسال أمر نصي إلى Isolate الخلفية والحصول على هيكل JSON فوري دون تجميد الـ UI
  static Future<Map<String, dynamic>> processCommandInIsolate(
      String text) async {
    if (!_isRunning || _sendPort == null) {
      await initIsolate();
    }

    final responsePort = ReceivePort();
    _sendPort!.send(GemmaIsolateRequest(
        commandText: text, replyPort: responsePort.sendPort));

    final result = await responsePort.first as Map<String, dynamic>;
    responsePort.close();
    return result;
  }

  /// إغلاق وتصفيح الـ Isolate وتحرير الموارد عند الخروج
  static void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _isRunning = false;
  }
}
