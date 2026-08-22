import 'package:flutter_test/flutter_test.dart';
import 'package:smart_accountant/services/vosk_service.dart';

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
