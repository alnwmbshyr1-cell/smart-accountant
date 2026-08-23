import 'package:flutter_tts/flutter_tts.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import 'vosk_service.dart';

/// Minimal speech-capture boundary consumed by [AiAgentService].
abstract interface class VoskSpeechCapturePort {
  Stream<String> onPartial();
  Stream<String> onResult();
  Future<bool?> start();
  Future<bool?> stop();
  Future<void> dispose();
}

/// Minimal Vosk lifecycle boundary consumed by [AiAgentService].
abstract interface class VoskServicePort {
  Future<void> init();
  Future<VoskSpeechCapturePort> ensureSpeechService();
  Future<void> stop();
  Future<String> getFinalResult();
  Future<void> dispose();
}

class ProductionVoskServicePort implements VoskServicePort {
  ProductionVoskServicePort({VoskService? service})
      : _service = service ?? VoskService();

  final VoskService _service;

  @override
  Future<void> init() => _service.init();

  @override
  Future<VoskSpeechCapturePort> ensureSpeechService() async {
    final speechService = await _service.ensureSpeechService();
    return ProductionVoskSpeechCapturePort(speechService);
  }

  @override
  Future<void> stop() => _service.stop();

  @override
  Future<String> getFinalResult() async {
    final recognizer = _service.recognizer;
    if (recognizer == null) {
      throw StateError('Vosk recognizer is not available');
    }
    return recognizer.getFinalResult();
  }

  @override
  Future<void> dispose() => _service.dispose();
}

class ProductionVoskSpeechCapturePort implements VoskSpeechCapturePort {
  ProductionVoskSpeechCapturePort(this._service);

  final SpeechService _service;

  @override
  Stream<String> onPartial() => _service.onPartial();

  @override
  Stream<String> onResult() => _service.onResult();

  @override
  Future<bool?> start() => _service.start();

  @override
  Future<bool?> stop() => _service.stop();

  @override
  Future<void> dispose() => _service.dispose();
}

abstract interface class DelayPort {
  Future<void> wait(Duration duration);
}

class ProductionDelayPort implements DelayPort {
  const ProductionDelayPort();

  @override
  Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}

abstract interface class TtsPort {
  Future<dynamic> setLanguage(String language);
  Future<dynamic> setSpeechRate(double rate);
  Future<dynamic> setPitch(double pitch);
  Future<dynamic> speak(String text);
}

class ProductionTtsPort implements TtsPort {
  ProductionTtsPort({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<dynamic> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<dynamic> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<dynamic> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<dynamic> speak(String text) => _tts.speak(text);
}
