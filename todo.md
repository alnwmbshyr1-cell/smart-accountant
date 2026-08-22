# Smart Accountant TODO

- [x] Initial project scaffold & core UI (RTL, Arabic)
- [x] Sales, Purchases, Receivables & Payables modules
- [x] Inventory management & low stock alerts
- [x] Calculator & transaction history
- [x] PDF report generation & export
- [x] Interactive monthly analytics charts
- [x] User authentication and role-based access
- [x] Advanced Arabic & Yemeni dialect voice command parser & confirmation flow
- [x] Text-to-Speech (TTS) interactive voice responses with the owner
- [ ] End-to-end integration tests for offline storage and voice commands
- [ ] Final APK release build and GitHub release update

## v2.0.1 Tasks - Lean APK & Local Gemma Download
- [x] إزالة مجلد gemma من الأصول لتخفيف الـ APK (~35MB)
- [ ] تعديل pubspec.yaml لضبط intl: ^0.19.0 وإضافة dio
- [ ] تنفيذ التحميل التلقائي لموديل Gemma عبر Dio من GitHub Release (models) عند أول تشغيل
- [ ] ضبط Gradle (minSdkVersion 24, arm64-v8a, minifyEnabled false)
- [ ] بناء APK محلي وسحابي ناجح عبر GitHub Actions

## v2.0.3 Tasks - Fix intl & Dependency Resolution
- [ ] تعديل pubspec.yaml لضبط intl: ^0.19.0 وإصدار التطبيق v2.0.3
- [ ] تشغيل flutter pub get والتحقق من عدم وجود تعارض مع flutter_localizations
- [ ] تشغيل flutter analyze و flutter test
- [ ] دفع التعديلات والوسم v2.0.3 إلى GitHub

## v2.0.5 Tasks - Downgrade dependencies for Flutter 3.22.3 compatibility
- [ ] تحديث pubspec.yaml (sdk: '>=3.3.0 <3.6.0', intl: 0.19.0, flutter_gemma: 0.1.9 بدون dependency_overrides)
- [ ] تحديث .github/workflows/build.yml (checkout@v3, setup-java@v3, flutter 3.22.3)
- [ ] ضبط android/build.gradle (AGP 7.4.2, Kotlin 1.9.0)
- [ ] ضبط android/gradle/wrapper/gradle-wrapper.properties (Gradle 8.3)
- [ ] تشغيل flutter clean && flutter pub get && flutter build apk --release
- [ ] دفع التعديلات برمز v2.0.5: Downgrade deps to work with Flutter 3.22
