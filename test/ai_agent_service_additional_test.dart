import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_accountant/ai_agent_service.dart';
import 'package:smart_accountant/database_service.dart';
import 'package:smart_accountant/services/audio_ports.dart';
import 'package:smart_accountant/services/gemini_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FixedGeminiService extends GeminiService {
  FixedGeminiService(this.response);

  final Map<String, dynamic>? response;

  @override
  Future<Map<String, dynamic>?> processCommand(String text) async => response;
}

class AssistantStateProbe extends StatefulWidget {
  const AssistantStateProbe({required this.service, super.key});

  final AiAgentService service;

  @override
  State<AssistantStateProbe> createState() => _AssistantStateProbeState();
}

class _AssistantStateProbeState extends State<AssistantStateProbe> {
  void _refresh(void Function() action) {
    action();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    return Column(
      children: [
        Text('listening:${service.isListening}'),
        Text('assistant:${service.isAssistantMode}'),
        ElevatedButton(
          onPressed: () => _refresh(service.startAssistant),
          child: const Text('start'),
        ),
        ElevatedButton(
          onPressed: () => _refresh(service.stopAssistant),
          child: const Text('stop'),
        ),
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      final db = await DatabaseService().database;
      await db.delete('transactions');
    } catch (_) {}
  });

  tearDown(() async {
    await DatabaseService().closeForTesting();
  });

  group('AiAgentService unit coverage', () {
    test('parses Yemeni words, Arabic digits, decimals, and invalid input', () {
      final service = AiAgentService(gemini: FixedGeminiService(null));

      expect(service.parseArabicNumber('عشرين ألف'), 20000);
      expect(service.parseArabicNumber('المبلغ 12,500.75 ريال'), 12500.75);
      expect(service.parseArabicNumber('لا يوجد مبلغ'), 0);
    });

    test('exposes assistant state transitions', () {
      final service = AiAgentService(gemini: FixedGeminiService(null));

      expect(service.isListening, isFalse);
      expect(service.isAssistantMode, isFalse);
      service.startAssistant();
      expect(service.isListening, isTrue);
      expect(service.isAssistantMode, isTrue);
      service.stopAssistant();
      expect(service.isListening, isFalse);
      expect(service.isAssistantMode, isFalse);
    });

    test('uses Gemini response, string amount, and explicit target tab',
        () async {
      final service = AiAgentService(
        gemini: FixedGeminiService({
          'type': 'مبيعات',
          'amount': '12500',
          'description': 'بضاعة',
          'targetTab': 4,
        }),
      );
      String reply = '';

      final result = await service.processVoiceCommandText(
        'سجل بيع بضاعة',
        (value) => reply = value,
      );

      expect(result['action'], 'add_sale');
      expect(result['source'], 'gemini');
      expect(result['amount'], 12500);
      expect(result['targetTab'], 4);
      expect(reply, contains('بضاعة'));
    });

    test('asks for the amount when Gemini returns a non-positive value',
        () async {
      final service = AiAgentService(
        gemini: FixedGeminiService({'type': 'مخزون', 'amount': 0}),
      );
      String reply = '';

      final result = await service.processVoiceCommandText(
        'أضف صنفًا للمخزن',
        (value) => reply = value,
      );

      expect(result['action'], 'needs_amount');
      expect(result['targetTab'], 3);
      expect(reply, contains('المبلغ'));
    });
  });

  testWidgets('updates a widget when assistant mode changes', (tester) async {
    final service = AiAgentService(gemini: FixedGeminiService(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AssistantStateProbe(service: service)),
      ),
    );

    expect(find.text('listening:false'), findsOneWidget);
    expect(find.text('assistant:false'), findsOneWidget);

    await tester.tap(find.text('start'));
    await tester.pump();
    expect(find.text('listening:true'), findsOneWidget);
    expect(find.text('assistant:true'), findsOneWidget);

    await tester.tap(find.text('stop'));
    await tester.pump();
    expect(find.text('listening:false'), findsOneWidget);
    expect(find.text('assistant:false'), findsOneWidget);
  });

  mainAudioInjectionTests();
}

class FakeDelayPort implements DelayPort {
  final waits = <Duration>[];

  @override
  Future<void> wait(Duration duration) async {
    waits.add(duration);
  }
}

class FakeTtsPort implements TtsPort {
  final calls = <String>[];
  Object? failure;

  @override
  Future<dynamic> setLanguage(String language) async {
    calls.add('language:$language');
    if (failure != null) throw failure!;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    calls.add('pitch:$pitch');
    if (failure != null) throw failure!;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    calls.add('rate:$rate');
    if (failure != null) throw failure!;
  }

  @override
  Future<dynamic> speak(String text) async {
    calls.add('speak:$text');
    if (failure != null) throw failure!;
  }
}

class FakeSpeechCapturePort implements VoskSpeechCapturePort {
  final partials = StreamController<String>.broadcast();
  final results = StreamController<String>.broadcast();
  int starts = 0;
  int stops = 0;

  @override
  Stream<String> onPartial() => partials.stream;

  @override
  Stream<String> onResult() => results.stream;

  @override
  Future<bool?> start() async {
    starts++;
    return true;
  }

  @override
  Future<bool?> stop() async {
    stops++;
    return true;
  }

  @override
  Future<void> dispose() async {
    await partials.close();
    await results.close();
  }
}

class FakeVoskServicePort implements VoskServicePort {
  FakeVoskServicePort(this.capture);

  final FakeSpeechCapturePort capture;
  int initCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  String finalResult = '{"text":"بعت بضاعة"}';
  Object? failure;

  @override
  Future<void> init() async {
    initCalls++;
    if (failure != null) throw failure!;
  }

  @override
  Future<VoskSpeechCapturePort> ensureSpeechService() async {
    if (failure != null) throw failure!;
    return capture;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<String> getFinalResult() async => finalResult;

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

void mainAudioInjectionTests() {
  test('initializes injected TTS and Vosk ports without native channels',
      () async {
    final tts = FakeTtsPort();
    final vosk = FakeVoskServicePort(FakeSpeechCapturePort());
    final service = AiAgentService(tts: tts, voskService: vosk);

    await service.init();

    expect(tts.calls, ['language:ar-SA', 'rate:0.82', 'pitch:0.8']);
    expect(vosk.initCalls, 1);
  });

  test('speaks Yemeni text through the injected TTS port', () async {
    final tts = FakeTtsPort();
    final vosk = FakeVoskServicePort(FakeSpeechCapturePort());
    final service = AiAgentService(tts: tts, voskService: vosk);

    await service.speakYemeni('تم التسجيل');

    expect(tts.calls.where((call) => call.startsWith('speak:')), [
      'speak:أبشر يا شيخ، تم التسجيل',
    ]);
  });

  test('reports Vosk startup failures through the wake status callback',
      () async {
    final tts = FakeTtsPort();
    final vosk = FakeVoskServicePort(FakeSpeechCapturePort())
      ..failure = StateError('fake Vosk failure');
    final statuses = <String>[];
    final service = AiAgentService(tts: tts, voskService: vosk);

    await service.startWakeWordListening(
      onWakeWord: () async {},
      onCommand: (_) async {},
      onStatus: statuses.add,
    );

    expect(statuses, contains(startsWith('تعذر تشغيل Vosk المحلي')));
    await service.disposeVoiceResources();
  });

  test('detects a wake word from injected partial results', () async {
    final tts = FakeTtsPort();
    final capture = FakeSpeechCapturePort();
    final vosk = FakeVoskServicePort(capture);
    var wakeWords = 0;
    final service = AiAgentService(tts: tts, voskService: vosk);

    await service.startWakeWordListening(
      onWakeWord: () async => wakeWords++,
      onCommand: (_) async {},
    );
    capture.partials.add('{"partial":"يا مُحاسب"}');
    await Future<void>.delayed(Duration.zero);

    expect(wakeWords, 1);
    expect(service.isCommandMode, isTrue);
    await service.disposeVoiceResources();
    await capture.dispose();
  });

  test('captures the final Vosk result with an injected delay port', () async {
    final tts = FakeTtsPort();
    final capture = FakeSpeechCapturePort();
    final vosk = FakeVoskServicePort(capture)
      ..finalResult = '{"text":"سجلت مصروف بنزين"}';
    final delay = FakeDelayPort();
    final service = AiAgentService(
      tts: tts,
      voskService: vosk,
      delay: delay,
    );

    final result = await service.startListening10Seconds();

    expect(result, 'سجلت مصروف بنزين');
    expect(delay.waits, [const Duration(seconds: 10)]);
    expect(capture.starts, 1);
    expect(capture.stops, 1);
    await service.disposeVoiceResources();
    await capture.dispose();
  });
}
