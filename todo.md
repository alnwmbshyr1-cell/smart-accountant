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

## v2.0.6 Tasks - Upgrade Flutter to 3.27.1 for flutter_gemma compatibility
- [ ] تحديث الإصدار إلى v2.0.6 في pubspec.yaml
- [ ] تحديث .github/workflows/build.yml لاستخدام Flutter 3.27.1
- [ ] تشغيل flutter clean && flutter pub get وبناء محلي ناجح
- [ ] تشغيل flutter analyze و flutter test
- [ ] دفع الوسم v2.0.6 ومتابعة نجاح GitHub Actions 100%

## v3.2.0 Pro UI & Library Upgrade Tasks
- [x] تدقيق توافق Flutter/Dart مع إصدارات المكتبات المطلوبة
- [x] تحديث pubspec.yaml وإعادة حل التبعيات بأمان
- [x] تطبيق Material 3 بالألوان #0D47A1 و#FFC107 وخلفية #F5F5F5
- [x] إضافة Material Symbols وGoogle Fonts Cairo/Tajawal وflutter_svg
- [x] إضافة flutter_animate وshimmer وresponsive_framework
- [x] تفعيل Riverpod وإعادة تنظيم حالة الواجهة
- [x] تفعيل Dark Mode تلقائي وحفظ الإعدادات محلياً
- [x] إضافة Loading State لكل زر رئيسي
- [x] ربط getTransactionsPage مع ScrollController وتحميل الصفحات تدريجياً
- [ ] تهيئة رسوم التقارير باستخدام fl_chart
- [x] تقييم Drift وdrift_sqlcipher قبل استبدال طبقة sqflite العاملة
- [x] تشغيل flutter pub get وflutter analyze وflutter test
- [ ] تشغيل بناء APK Release والتحقق من CI/CD
- [ ] تحديث README وتوثيق أي تعارضات أو بدائل توافق
- [ ] قراءة todo.md والتحقق من علامات الإنجاز قبل checkpoint النهائي

## سجل طلب المستخدم الحالي
- [x] اعتماد مكتبات الواجهة والبيانات والذكاء والصوت والتقارير والأمان المحددة
- [x] فحص تأثير الحزم الأصلية على حجم APK ووقت البناء

## قرارات توافق
- [ ] عدم استبدال sqflite بـ Drift/SQLCipher إلا بعد اختبار ترحيل آمن
- [ ] عدم كسر العمل دون اتصال أو وظائف Gemma والصوت الحالية
- [ ] توثيق أي إصدار لا يعمل مع Flutter/Dart الحالي بدلاً من إخفاء التعارض

## نهاية تحديث v3.2.0

- [ ] مرحلة التنفيذ
- [ ] مرحلة الاختبارات
- [ ] مرحلة التسليم النهائي


## ميزات v3.2.0 — طلب المستخدم الحالي
- [x] إضافة شاشة الأرباح برسوم fl_chart وبيانات شهرية من SQLite
- [x] إضافة زر طباعة فاتورة باستخدام pdf وprinting
- [x] إضافة زر تصدير Excel باستخدام excel
- [x] إضافة تسجيل صوتي تلقائي مدته 3 ثوانٍ باستخدام record
- [x] تشغيل flutter clean وGradle clean وpub get
- [x] تشغيل flutter analyze وflutter test
- [x] بناء APK split-per-ABI وتوثيق النتيجة — تم بنجاح بناء APK ARM64 منفرد بحجم 35.1MB بعد إصلاح التبعيات


## Wake Word — يا محاسب
- [x] تدقيق قيود Porcupine وبديل speech_to_text الحالي
- [x] إضافة دورة الاستماع الخفيف ثم تسجيل الأمر لمدة 5 ثوانٍ
- [x] دعم العبارتين يا محاسب ويا حسابات في fallback العربي
- [x] إضافة زر تشغيل وإيقاف التنشيط الصوتي في الإعدادات
- [x] إضافة صلاحيات foreground service وmicrophone وWAKE_LOCK؛ الإشعار الدائم الكامل يحتاج runner foreground إضافياً
- [x] إضافة porcupine_flutter اختيارياً مع توثيق AccessKey وملف keyword العربي
- [x] تشغيل analyze وtest والتحقق من دورة wake word على مستوى الكود
- [x] تسليم ai_agent_service.dart وAndroidManifest.xml وpubspec.yaml المحدثة


## Vosk Offline Speech Migration
- [x] التحقق من توفر vosk_flutter وواجهة API الفعلية
- [x] تنزيل نموذج Vosk العربي والتحقق من سلامة الأرشيف وحجمه
- [x] إضافة النموذج إلى assets أو توثيق بديل محلي لا يضخم Git
- [x] حذف speech_to_text من pubspec والكود والاختبارات
- [x] دمج Vosk مع AiAgentService وتسجيل الأمر محلياً
- [x] تحديث Wake Word وعدم استخدام speech_to_text في fallback
- [x] تشغيل analyze وtest؛ بناء APK يحتاج تقييم حجم نموذج 318MB


## Smart Accountant — إعادة البناء المعماري الصوتي المحلي
- [x] تدقيق حالة Vosk وGemma والأصول الفعلية قبل إعادة التنظيم
- [ ] إنشاء services/db_service.dart مع SQLite ومخطط transactions المطلوب
- [ ] إنشاء services/tts_service.dart مع flutter_tts العربي
- [ ] إنشاء services/ai_agent_service.dart وربط Vosk والتحليل المحلي
- [x] إزالة Gemma من المسار التنفيذي والإبقاء على parser محلي كـ fallback عند غياب الإنترنت
- [ ] إنشاء screens/home_screen.dart بواجهة Material 3 وRiverpod
- [ ] ربط الصوت والحفظ والإجماليات والرد الصوتي end-to-end
- [ ] تحديث AndroidManifest وقواعد ProGuard وأصول النماذج
- [x] حذف speech_to_text بالكامل من الكود والتبعيات والاختبارات
- [ ] تشغيل analyze وtest والبناء وتوثيق أي موديل غير متاح
- [ ] تسليم الملفات كاملة دون ملفات نموذج وهمية


## Gemma 2B GGUF
- [x] التحقق من flutter_gemma 1.2.0 وAPI تحميل GGUF الفعلية
- [x] التحقق من رابط Hugging Face وحجم الملف والمساحة المتاحة
- [x] تحديث pubspec إلى إصدار Gemma المتوافق أو توثيق التعارض
- [ ] إضافة مسار assets/models/gemma-2-2b-it-Q8_0.gguf دون ملف وهمي — الملف gated والمساحة غير كافية
- [x] إزالة تحميل Gemma عند بدء AiAgentService واستبداله بمسار Gemini اختياري
- [x] تنفيذ processWithGemini وإرجاع JSON محقق أو null
- [x] تفعيل fallback إلى AiAgentParser عند غياب مفتاح Gemini أو فشل الشبكة
- [x] تشغيل analyze وtest؛ fallback المحلي اجتاز الاختبارات
- [ ] تسليم تعليمات وضع ملف GGUF وبناء التطبيق


## APK Release — المحاسب الصوتي 1.0.0
- [x] التحقق من وجود assets/models/vosk-model-ar-mgb2-0.4/ وجميع ملفات النموذج
- [x] تحديث اسم التطبيق إلى المحاسب الصوتي ورقم الإصدار إلى 1.0.0
- [x] تجهيز أيقونة محاسبة بسيطة وربطها بإعدادات Android
- [x] تنفيذ flutter clean وflutter pub get
- [x] تشغيل flutter analyze بنتيجة 0 أخطاء
- [x] تشغيل flutter test بنتيجة 6 اختبارات ناجحة
- [x] تشغيل flutter build apk --release عبر GitHub Actions بنجاح
- [x] التحقق من build/app/outputs/flutter-apk/app-release.apk ورفع الأصل إلى Release
- [x] إنشاء README.txt بتعليمات التثبيت ومفتاح Gemini
- [x] تسليم APK وREADME.txt معاً

- [x] تحديث اختبار الواجهة ليتحقق من اسم الإصدار الجديد «المحاسب الصوتي»


## Network and Vosk footprint remediation
- [x] تشخيص Network is unreachable ومصادر Gradle/Maven المستخدمة في البناء
- [x] اختيار استراتيجية تحميل نموذج Vosk خارج APK؛ لا يوجد نموذج عربي عام أصغر رسمي مناسب للهجة اليمنية في القائمة الرسمية
- [x] تحديث pubspec وAiAgentService ومسار الأصول بما يطابق الاستراتيجية المختارة
- [x] التحقق من flutter analyze وflutter test بعد التعديل
- [x] توثيق خطوات إصلاح الشبكة وإعادة البناء


## Complete build execution
- [x] تنفيذ البناء الكامل للإصدار الحالي بعد إصلاح عوائق Gradle والشبكة
- [x] التحقق من APK Release وREADME وتسليمهما إن نجح البناء
- [x] إصلاح namespace المفقود في vosk_flutter ليتوافق مع AGP 8.11.1
- [x] استبدال afterEvaluate غير الصالح بحل plugins.withId لتعيين namespace لـ vosk_flutter


## Vosk initialization guard
- [x] منع تهيئة Vosk مرتين ومعالجة LateInitializationError
- [x] تعطيل زر المايك أثناء تهيئة Vosk
- [x] إضافة dispose آمن لخدمة Vosk وتشغيل الفحوصات


## Pro voice accounting workflow
- [x] ربط المايكروفون بالأوامر الصوتية للدين لي والدين علي والمبيعات والمشتريات والمخزون والرفع
- [x] توحيد نموذج الأوامر الصوتية والتحقق من المبلغ والنوع والوصف والجهة
- [x] ربط كل نوع عملية بقاعدة البيانات وتحديث الأرصدة والمخزون
- [x] إظهار نتيجة العملية في الواجهة وإصدار رد صوتي مؤكد بعد الحفظ الفعلي
- [x] إضافة اختبارات لكل أنواع الأوامر الصوتية وسيناريوهات الفشل
- [x] إصلاح أولوية تصنيف عبارة «بعت بضاعة» حتى لا تُصنف كمخزون
- [x] جعل اختبار الواجهة لا ينتظر استقراراً لا نهائياً بسبب الأنيميشن
- [x] تحديث توقع targetTab للمبيعات من الرئيسية إلى شاشة المبيعات والمشتريات
- [x] تجاوز كاش Kotlin DSL التالف metadata.bin عبر GitHub Actions وإعادة بناء APK


## Professional audit
- [x] تدقيق الإعدادات والاعتمادات والأصول والصلاحيات
- [x] تشغيل analyze والاختبارات الوظيفية وقاعدة البيانات والأوامر الصوتية
- [x] التحقق من بناء APK وسلامة الحزمة وGitHub Actions
- [x] قياس المخاطر والأداء والأمان وتجربة الاستخدام
- [x] إنشاء تقرير فحص شامل مع الأدلة والتوصيات


## Test coverage improvement
- [ ] تحليل lcov وتحديد الملفات والمسارات غير المغطاة
- [ ] إضافة اختبارات parser للأوامر الستة والأرقام المركبة والحالات غير الصالحة
- [ ] إضافة اختبارات DatabaseService للإدخال والبحث والتصفح الدفعي والإجماليات والحذف
- [ ] إضافة اختبارات GeminiService للـ JSON غير الصالح والمفتاح المفقود والـ fallback
- [ ] إضافة اختبارات دورة حياة Vosk مع plugin وModelLoader قابلين للحقن
- [ ] إضافة اختبارات واجهة للتنقل وحالات المايك والتحميل والأخطاء
- [ ] إضافة coverage gate إلى GitHub Actions ورفع الحد تدريجياً


## CI coverage gate
- [ ] إضافة تشغيل flutter test --coverage إلى GitHub Actions
- [ ] إضافة بوابة تفشل البناء عند تغطية أقل من 70%
- [ ] التحقق محلياً من أن النسبة الحالية 34.69% ستفشل البوابة بوضوح
- [ ] دفع التعديل وتوثيق أن رفع الاختبارات مطلوب قبل اجتياز الحد


## Microphone and coverage expansion
- [ ] إصلاح حالات بدء وإيقاف التسجيل وتعارض جلسات المايك
- [ ] اختبار زر المايك وحالة التهيئة والصلاحيات في main.dart
- [ ] اختبار AiAgentService مع خدمات صوت وقاعدة بيانات قابلة للحقن
- [ ] إعادة قياس التغطية وعدم رفع حد CI قبل تحقيق 70% فعلياً


## Microphone button visual state
- [x] تحويل زر الميكروفون إلى اللون الأحمر أثناء التسجيل
- [x] تصغير حجم زر الميكروفون مع الحفاظ على وضوحه
- [x] تشغيل التحليل والاختبارات بعد تعديل الواجهة
