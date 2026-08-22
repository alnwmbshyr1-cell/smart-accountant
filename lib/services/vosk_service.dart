import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:vosk_flutter/vosk_flutter.dart';

/// Adapter for the model-loading operations used by [VoskService].
///
/// Keeping this boundary injectable makes unit tests deterministic: they can
/// simulate an already-downloaded model or a network failure without invoking
/// the real archive downloader.
abstract interface class VoskModelLoaderAdapter {
  Future<bool> isModelAlreadyLoaded(String modelName);
  Future<String> modelPath(String modelName);
  Future<String> loadFromNetwork(String modelUrl);
}

class DefaultVoskModelLoaderAdapter implements VoskModelLoaderAdapter {
  DefaultVoskModelLoaderAdapter() : _loader = ModelLoader();

  final ModelLoader _loader;

  @override
  Future<bool> isModelAlreadyLoaded(String modelName) =>
      _loader.isModelAlreadyLoaded(modelName);

  @override
  Future<String> modelPath(String modelName) => _loader.modelPath(modelName);

  @override
  Future<String> loadFromNetwork(String modelUrl) =>
      _loader.loadFromNetwork(modelUrl);
}

abstract interface class VoskEngine {
  Future<Model> createModel(String modelPath);
  Future<Recognizer> createRecognizer({
    required Model model,
    required int sampleRate,
  });
  Future<SpeechService> initSpeechService(Recognizer recognizer);
}

class DefaultVoskEngine implements VoskEngine {
  DefaultVoskEngine({VoskFlutterPlugin? plugin})
      : _plugin = plugin ?? VoskFlutterPlugin.instance();

  final VoskFlutterPlugin _plugin;

  @override
  Future<Model> createModel(String modelPath) => _plugin.createModel(modelPath);

  @override
  Future<Recognizer> createRecognizer({
    required Model model,
    required int sampleRate,
  }) =>
      _plugin.createRecognizer(model: model, sampleRate: sampleRate);

  @override
  Future<SpeechService> initSpeechService(Recognizer recognizer) =>
      _plugin.initSpeechService(recognizer);
}

/// Lifecycle-safe Vosk wrapper.
///
/// Multiple callers may request init at the same time (startup, wake word,
/// and microphone button). A shared Future makes all callers await one init.
class VoskService {
  VoskService({
    VoskFlutterPlugin? plugin,
    VoskModelLoaderAdapter? modelLoader,
    VoskEngine? engine,
  })  : _providedPlugin = plugin,
        _providedModelLoader = modelLoader,
        _providedEngine = engine;

  final VoskFlutterPlugin? _providedPlugin;
  final VoskModelLoaderAdapter? _providedModelLoader;
  final VoskEngine? _providedEngine;
  VoskFlutterPlugin? _vosk;
  VoskEngine? _engine;

  VoskFlutterPlugin get _plugin =>
      _vosk ??= _providedPlugin ?? VoskFlutterPlugin.instance();
  VoskEngine get _voskEngine =>
      _engine ??= _providedEngine ?? DefaultVoskEngine(plugin: _plugin);
  VoskModelLoaderAdapter? _modelLoader;

  bool _isInitialized = false;
  bool _isInitializing = false;
  Future<void>? _initializationFuture;
  bool _isDisposed = false;

  Model? _model;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isReady => _isInitialized && !_isDisposed;
  Recognizer? get recognizer => _recognizer;
  SpeechService? get speechService => _speechService;

  /// Initializes Vosk exactly once, even when called concurrently.
  Future<void> init() {
    if (_isDisposed) {
      throw StateError('VoskService has already been disposed');
    }
    if (_isInitialized) return Future<void>.value();
    final running = _initializationFuture;
    if (running != null) return running;

    _isInitializing = true;
    _modelLoader ??= _providedModelLoader ?? DefaultVoskModelLoaderAdapter();
    final future = _initializeOnce();
    _initializationFuture = future;
    return future.whenComplete(() {
      _isInitializing = false;
      if (!_isInitialized) _initializationFuture = null;
    });
  }

  Future<void> _initializeOnce() async {
    const modelUrl =
        'https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip';
    final modelName = p.basenameWithoutExtension(modelUrl);
    final loader = _modelLoader!;
    final alreadyLoaded = await loader.isModelAlreadyLoaded(modelName);
    final modelPath = alreadyLoaded
        ? await loader.modelPath(modelName)
        : await loader.loadFromNetwork(modelUrl);

    if (_isDisposed) return;
    final model = await _voskEngine.createModel(modelPath);
    if (_isDisposed) {
      model.dispose();
      return;
    }
    final recognizer = await _voskEngine.createRecognizer(
      model: model,
      sampleRate: 16000,
    );
    if (_isDisposed) {
      await recognizer.dispose();
      model.dispose();
      return;
    }

    _model = model;
    _recognizer = recognizer;
    _isInitialized = true;
  }

  Future<SpeechService> ensureSpeechService() async {
    await init();
    if (_isDisposed || _recognizer == null) {
      throw StateError('Vosk recognizer is not available');
    }
    return _speechService ??= await _voskEngine.initSpeechService(_recognizer!);
  }

  Future<void> stop() async {
    try {
      await _speechService?.stop();
    } catch (_) {}
  }

  /// Stops capture and releases recognizer/model resources. Safe to call twice.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _isInitialized = false;
    _isInitializing = false;
    _initializationFuture = null;
    await stop();
    try {
      await _speechService?.dispose();
    } catch (_) {}
    try {
      await _recognizer?.dispose();
    } catch (_) {}
    try {
      _model?.dispose();
    } catch (_) {}
    _speechService = null;
    _recognizer = null;
    _model = null;
  }
}
