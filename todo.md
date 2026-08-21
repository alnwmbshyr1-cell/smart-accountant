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
