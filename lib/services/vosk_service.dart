import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:vosk_flutter/vosk_flutter.dart';

/// Lifecycle-safe Vosk wrapper.
///
/// Multiple callers may request init at the same time (startup, wake word,
/// and microphone button). A shared Future makes all callers await one init.
class VoskService {
  VoskService({VoskFlutterPlugin? plugin}) : _providedPlugin = plugin;

  final VoskFlutterPlugin? _providedPlugin;
  VoskFlutterPlugin? _vosk;

  VoskFlutterPlugin get _plugin =>
      _vosk ??= _providedPlugin ?? VoskFlutterPlugin.instance();
  late final ModelLoader _modelLoader;

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
    _modelLoader = ModelLoader();
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
    final alreadyLoaded = await _modelLoader.isModelAlreadyLoaded(modelName);
    final modelPath = alreadyLoaded
        ? await _modelLoader.modelPath(modelName)
        : await _modelLoader.loadFromNetwork(modelUrl);

    if (_isDisposed) return;
    final model = await _plugin.createModel(modelPath);
    if (_isDisposed) {
      model.dispose();
      return;
    }
    final recognizer = await _plugin.createRecognizer(
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
    return _speechService ??= await _plugin.initSpeechService(_recognizer!);
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
