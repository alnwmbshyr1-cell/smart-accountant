import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/services/vosk_service.dart';
import 'fakes/fake_vosk_engine.dart';

class ReadyModelLoader implements VoskModelLoaderAdapter {
  @override
  Future<bool> isModelAlreadyLoaded(String modelName) async => true;

  @override
  Future<String> modelPath(String modelName) async => '/tmp/$modelName';

  @override
  Future<String> loadFromNetwork(String modelUrl) async => '/tmp/model';
}

class FailingModelLoader implements VoskModelLoaderAdapter {
  int loadChecks = 0;

  @override
  Future<bool> isModelAlreadyLoaded(String modelName) async {
    loadChecks++;
    throw StateError('simulated model download failure');
  }

  @override
  Future<String> modelPath(String modelName) async => '/tmp/$modelName';

  @override
  Future<String> loadFromNetwork(String modelUrl) async => '/tmp/model';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses injectable VoskEngine and initializes it once', () async {
    final engine = FakeVoskEngine();
    final service = VoskService(
      engine: engine,
      modelLoader: FailingModelLoader(),
    );

    // Override the failing loader with a deterministic loader for this case.
    final readyService = VoskService(
      engine: engine,
      modelLoader: ReadyModelLoader(),
    );
    await readyService.init();
    await readyService.init();

    expect(readyService.isReady, isTrue);
    expect(engine.createModelCalls, 1);
    expect(engine.createRecognizerCalls, 1);
    expect(service.isInitialized, isFalse);
  });

  test('surfaces model creation failure and resets initializing state',
      () async {
    final engine = FakeVoskEngine()..modelFailure = StateError('model failed');
    final service = VoskService(
      engine: engine,
      modelLoader: ReadyModelLoader(),
    );

    await expectLater(service.init(), throwsA(isA<StateError>()));
    expect(service.isInitialized, isFalse);
    expect(service.isInitializing, isFalse);
  });

  test('surfaces recognizer creation failure without marking ready', () async {
    final engine = FakeVoskEngine()
      ..recognizerFailure = StateError('recognizer failed');
    final service = VoskService(
      engine: engine,
      modelLoader: ReadyModelLoader(),
    );

    await expectLater(service.init(), throwsA(isA<StateError>()));
    expect(service.isReady, isFalse);
    expect(engine.createModelCalls, 1);
    expect(engine.createRecognizerCalls, 1);
  });

  test('init is idempotent and concurrent callers share one failure', () async {
    final loader = FailingModelLoader();
    final service = VoskService(modelLoader: loader);

    final first = service.init();
    final second = service.init();

    await expectLater(first, throwsA(isA<StateError>()));
    await expectLater(second, throwsA(isA<StateError>()));
    expect(loader.loadChecks, 1);
    expect(service.isInitialized, isFalse);
    expect(service.isInitializing, isFalse);

    expect(() => service.init(), throwsA(isA<StateError>()));
    expect(loader.loadChecks, 2);
  });

  test('dispose is safe when called more than once', () async {
    final service = VoskService(modelLoader: FailingModelLoader());

    await service.dispose();
    await service.dispose();

    expect(service.isReady, isFalse);
    expect(service.isInitialized, isFalse);
    expect(() => service.init(), throwsA(isA<StateError>()));
  });

  test('ensureSpeechService rejects a disposed service without touching Vosk',
      () async {
    final service = VoskService(modelLoader: FailingModelLoader());
    await service.dispose();

    await expectLater(
      service.ensureSpeechService(),
      throwsA(isA<StateError>()),
    );
  });

  test('stop is safe before initialization and after dispose', () async {
    final service = VoskService(modelLoader: FailingModelLoader());

    await service.stop();
    await service.dispose();
    await service.stop();
  });
}
