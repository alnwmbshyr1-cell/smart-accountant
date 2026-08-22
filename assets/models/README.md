# Vosk model policy

The Arabic Vosk model is intentionally not bundled in the APK. The app downloads the official `vosk-model-ar-mgb2-0.4.zip` on first initialization through `ModelLoader.loadFromNetwork`, extracts it into the application documents directory, and reuses it offline on subsequent launches.

Official source: https://alphacephei.com/vosk/models/vosk-model-ar-mgb2-0.4.zip
