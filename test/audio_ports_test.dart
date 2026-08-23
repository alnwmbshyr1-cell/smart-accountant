import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:smart_accountant/services/audio_ports.dart';
import 'package:smart_accountant/services/vosk_service.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

class FakeFlutterTts extends FlutterTts {
  final calls = <String>[];

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('language:$language');
    return true;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    calls.add('rate:$rate');
    return true;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    calls.add('pitch:$pitch');
    return true;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    calls.add('speak:$text');
    return true;
  }
}

class FakeVoskService extends VoskService {
  FakeVoskService({required this.speech, this.fakeRecognizer});

  final SpeechService speech;
  final Recognizer? fakeRecognizer;
  int initCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> init() async => initCalls++;

  @override
  Future<SpeechService> ensureSpeechService() async => speech;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  Recognizer? get recognizer => fakeRecognizer;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('audio_ports_test_channel');
  final model = Model('/tmp/fake-model', channel);
  final recognizer = Recognizer(
    id: 7,
    model: model,
    sampleRate: 16000,
    channel: channel,
  );
  final speech = SpeechService(channel);

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'recognizer.getFinalResult':
          return '{"text":"نتيجة نهائية"}';
        case 'speechService.start':
        case 'speechService.stop':
        case 'speechService.destroy':
          return true;
        case 'destroy':
          return true;
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ProductionVoskSpeechCapturePort', () {
    test('forwards streams and lifecycle methods', () async {
      final port = ProductionVoskSpeechCapturePort(speech);

      expect(port.onPartial(), isA<Stream<String>>());
      expect(port.onResult(), isA<Stream<String>>());
      expect(await port.start(), isTrue);
      expect(await port.stop(), isTrue);
      await port.dispose();
    });
  });

  group('ProductionVoskServicePort', () {
    test('forwards lifecycle and wraps speech service', () async {
      final fake = FakeVoskService(speech: speech);
      final port = ProductionVoskServicePort(service: fake);

      await port.init();
      final capture = await port.ensureSpeechService();
      expect(capture, isA<ProductionVoskSpeechCapturePort>());
      await port.stop();
      await port.dispose();
      expect(fake.initCalls, 1);
      expect(fake.stopCalls, 1);
      expect(fake.disposeCalls, 1);
    });

    test('returns the final recognizer result', () async {
      final fake = FakeVoskService(
        speech: speech,
        fakeRecognizer: recognizer,
      );
      final port = ProductionVoskServicePort(service: fake);

      expect(await port.getFinalResult(), '{"text":"نتيجة نهائية"}');
    });

    test('throws when no recognizer is available', () async {
      final port = ProductionVoskServicePort(
        service: FakeVoskService(speech: speech),
      );

      expect(port.getFinalResult, throwsStateError);
    });
  });

  test('ProductionDelayPort waits for the requested duration', () async {
    final stopwatch = Stopwatch()..start();
    await const ProductionDelayPort().wait(const Duration(milliseconds: 1));
    stopwatch.stop();
    expect(stopwatch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 1)));
  });

  test('ProductionTtsPort forwards all supported calls', () async {
    final fake = FakeFlutterTts();
    final port = ProductionTtsPort(tts: fake);

    await port.setLanguage('ar-SA');
    await port.setSpeechRate(0.8);
    await port.setPitch(0.9);
    await port.speak('أبشر');

    expect(fake.calls, [
      'language:ar-SA',
      'rate:0.8',
      'pitch:0.9',
      'speak:أبشر',
    ]);
  });
}
