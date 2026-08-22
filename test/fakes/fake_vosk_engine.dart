import 'package:flutter/services.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'package:smart_accountant/services/vosk_service.dart';

class FakeVoskEngine implements VoskEngine {
  FakeVoskEngine({this.modelPath = '/tmp/fake-vosk-model'})
      : _channel = const MethodChannel('fake.vosk');

  final String modelPath;
  final MethodChannel _channel;
  int createModelCalls = 0;
  int createRecognizerCalls = 0;
  int initSpeechServiceCalls = 0;
  Object? modelFailure;
  Object? recognizerFailure;
  Object? speechServiceFailure;

  late final Model model = Model(modelPath, _channel);
  late final Recognizer recognizer = Recognizer(
    id: 1,
    model: model,
    sampleRate: 16000,
    channel: _channel,
  );
  late final SpeechService speechService = SpeechService(_channel);

  @override
  Future<Model> createModel(String path) async {
    createModelCalls++;
    if (modelFailure != null) throw modelFailure!;
    return model;
  }

  @override
  Future<Recognizer> createRecognizer({
    required Model model,
    required int sampleRate,
  }) async {
    createRecognizerCalls++;
    if (recognizerFailure != null) throw recognizerFailure!;
    return recognizer;
  }

  @override
  Future<SpeechService> initSpeechService(Recognizer recognizer) async {
    initSpeechServiceCalls++;
    if (speechServiceFailure != null) throw speechServiceFailure!;
    return speechService;
  }
}
