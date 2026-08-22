# Vosk model verification

- User-provided URL: https://alphacephei.com/vosk/models/vosk-model-ar-0.22.zip
- Result: HTTP/page 404 on 2026-08-22; this exact archive is not available at that path.
- Official models page: https://alphacephei.com/vosk/models
- Official current Arabic entries observed:
  - vosk-model-ar-mgb2-0.4.zip — 318M, Apache 2.0, Arabic model trained on MGB2.
  - vosk-model-ar-0.22-linto-1.1.0.zip — 1.3G, AGPL, large Arabic model.
- Official Vosk overview: https://alphacephei.com/vosk/
  - Vosk works offline and small models are generally about 50MB, but the current official Arabic list does not show a 50MB Arabic model named vosk-model-ar-0.22.
- vosk_flutter API docs: https://pub.dev/documentation/vosk_flutter/latest/vosk_flutter
  - Current latest docs expose ModelLoader, Model, Recognizer, SpeechService, and VoskFlutterPlugin.
- vosk_flutter repository usage: https://github.com/alphacep/vosk-flutter
  - The documented API uses VoskFlutterPlugin.instance(), ModelLoader().loadFromAssets(...), createRecognizer(model: ..., sampleRate: ...), and initSpeechService(recognizer).
  - The user-provided sample using VoskFlutter().initModel() and createModel() does not match the current documented API.

Decision: do not fabricate or generate a fake model. Keep the asset path documented, remove speech_to_text from code, and only mark model integration as ready after a valid model archive is supplied or the official 318M model is explicitly accepted. The 404 and size/license differences must be disclosed.
