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


## Automatic runtime permissions
- [x] فحص الصلاحيات المعلنة واعتماد permission_handler
- [x] طلب الميكروفون والإشعارات تلقائياً عند بدء الاستخدام أو الضغط على المايك
- [x] معالجة الرفض والرفض الدائم وفتح إعدادات النظام
- [x] اختبار التحليل والاختبارات بعد ربط الصلاحيات


## Settings and voice field autofill
- [x] إضافة زر إعدادات واضح إلى الواجهة
- [x] ربط ناتج الأمر الصوتي بالصفحة المناسبة والحفظ التلقائي
- [x] تحسين حالة المعالجة ومنع الطلبات الصوتية المتزامنة
- [x] إضافة اختبار main.dart لوجود زر الإعدادات وحالة واجهة التطبيق
- [x] إضافة اختبارات AiAgentService لأوامر الدين والمشتريات والمخزون والأمر الناقص المبلغ
- [x] قياس التغطية وعدم اعتبار 70% ناجحة قبل بلوغها فعلياً؛ النتيجة الحالية 33.62%


## VoskService unit coverage
- [x] جعل تبعيات Vosk قابلة للحقن في الاختبارات دون تشغيل plugin حقيقي
- [x] اختبار التهيئة المتكررة والفشل والإيقاف وdispose
- [x] قياس التغطية بعد إضافة اختبارات VoskService؛ ارتفعت من 33.62% إلى 35.20%


## AiAgentService unit coverage
- [x] اختبار أوامر التقرير والبحث والردود الصوتية الخاصة بها
- [x] اختبار مسارات الأنواع الستة مع الحفظ والتنقل والرد بعد الحفظ
- [x] اختبار المبلغ المفقود وفشل Gemini والـfallback
- [x] إعادة قياس تغطية AiAgentService والمشروع وتشغيل التحليل والاختبارات؛ التغطية 36.72% و16 اختباراً ناجحاً
- [x] إضافة دعم الأرقام العربية المفردة مثل «خمسة أصناف» لأوامر المخزون واختبارات AiAgentService


## Full remaining test batch
- [x] اختبار profit_report_screen لحالات التحميل والفراغ والبيانات والرسوم
- [x] اختبار دوال التصدير والفواتير ببيانات ثابتة مع عزل الطباعة والملفات
- [ ] اختبار حالات الواجهة منخفضة التغطية في main.dart
- [x] تشغيل المجموعة الكاملة وقياس coverage بدقة؛ 23 اختباراً ناجحاً والتغطية 45.57%
- [ ] دفع دفعة الاختبارات وتوثيق ما تبقى للوصول إلى 70%
- [x] استيراد fl_chart في اختبار profit_report_screen لإتاحة فحص BarChart
- [x] تعديل assertion في اختبار profit_report_screen لقبول تكرار اسم الشهر بين محور الرسم والملخص
- [x] إزالة import غير مستخدم من اختبار ExportService ثم إعادة الفحص
- [x] عزل path_provider في اختبارات ExportService عبر mock MethodChannel لمنع MissingPluginException
- [x] إنشاء مجلد documents الوهمي في اختبار ExportService قبل الكتابة


## DatabaseService unit coverage
- [x] تحليل الفروع غير المغطاة في DatabaseService ومخطط الجداول
- [x] اختبار الإدخال المفرد والدفعي والبيانات الافتراضية والحدّية
- [x] اختبار البحث وKeyset Pagination والإجماليات والتقارير الشهرية
- [x] اختبار حذف seed وتحديث المخزون والاستعلامات الفارغة
- [x] تشغيل التحليل والاختبارات وقياس coverage؛ 32 اختباراً ناجحاً والتغطية 49.79%
- [x] عزل اختبارات DatabaseService بحذف ملف SQLite التجريبي بين الحالات لمنع تراكم السجلات
- [x] إزالة import sqflite غير المستخدم من اختبارات DatabaseService ثم إعادة الفحص


## main.dart unit and widget coverage
- [x] اختبار حالات تحميل البيانات والواجهة الفارغة والمعبأة
- [x] اختبار زر الإعدادات وزر المايك وحالتي التسجيل والتهيئة
- [x] اختبار الصلاحيات والرسائل والتنقل بعد نتيجة الأمر الصوتي
- [x] تشغيل المجموعة الكاملة وقياس تغطية main.dart والمشروع
- [ ] دفع دفعة اختبارات main.dart وتوثيق المتبقي للوصول إلى 70%؛ 9 اختبارات جديدة، والمشروع 59.88%


## Aggressive coverage expansion — permissions, Vosk, export, and loadData
- [x] عزل مسارات قبول ورفض صلاحية الميكروفون وفتح إعدادات النظام
- [x] اختبار تهيئة Vosk والتسجيل ونتيجة النص الفارغة والأخطاء
- [x] اختبار أخطاء طباعة الفاتورة وتصدير Excel ورسائل النجاح والفشل
- [x] اختبار _loadData والصفحات والمكررات وتعارض generation والتحميل المتزامن
- [x] تشغيل الاختبارات الكاملة وقياس التغطية ودفع الدفعة الناجحة؛ main.dart = 82.93%، المشروع = 68.79%


## Coverage over 70% — remaining services
- [x] تحليل lcov على مستوى الملفات والدوال وتحديد أقل الخدمات تغطية
- [x] إضافة اختبارات وحدة مركزة للخدمات الأقل تغطية بأثر يتجاوز 1.21%
- [x] تشغيل flutter analyze والاختبارات الكاملة مع coverage والتحقق من تجاوز 70%؛ 52 اختباراً، 70.23%
- [ ] دفع الاختبارات وتحديث نتائج التغطية في GitHub


## Integration tests and HTML coverage report
- [x] اختبار التدفق الكامل من نتيجة Vosk إلى تحليل الأمر والحفظ المحلي
- [x] اختبار تحديث الإجماليات ثم تصدير Excel وPDF عبر منافذ معزولة
- [x] إنشاء تقرير HTML مفصل للملفات والدوال والأسطر غير المغطاة؛ coverage = 70.23%
- [x] مراجعة التقرير وتشغيل المجموعة الكاملة ودفع النتائج إلى GitHub؛ 55 اختباراً ناجحاً وتقرير HTML محدث


## Gemini and export exception coverage
- [x] اختبار Gemini JSON غير الصالح وMarkdown والحقول العربية والأنواع غير المعروفة
- [x] اختبار Gemini أخطاء التخزين وغياب المفتاح والمبالغ والكمية الحدية
- [x] اختبار ExportService للطباعة الفارغة والبيانات الحدية واستثناءات Printing
- [x] اختبار ExportService لفشل الكتابة والملف غير القابل للإنشاء
- [ ] تشغيل coverage والتحقق من تجاوز 80% للخدمات المستهدفة ودفع النتائج؛ Gemini 89.66%، Export 41.30%، الإجمالي 75.42%


## ExportService dependency injection refactor
- [x] فصل بناء PDF عن InvoicePrinter وFileWriter
- [x] إضافة providers لـExportService عبر Riverpod مع بدائل اختبارية
- [x] تحديث main.dart لاستخدام ExportService المحقون
- [x] إضافة اختبارات FakeInvoicePrinter وFakeFileWriter للوحدة والواجهة
- [x] تشغيل التحليل والاختبارات والتغطية ودفع التغييرات؛ ExportService 91.53%، GeminiService 89.66%، الإجمالي 77.62%


## CI integration test pipeline
- [x] تشغيل اختبارات الوحدة والتكامل معاً في GitHub Actions
- [x] توليد وتخزين تقرير HTML وlcov كـ artifacts
- [x] فرض حد التغطية قبل خطوة بناء APK
- [x] التحقق من YAML ودفع workflow المحدث؛ 65 اختباراً ناجحاً و77.62% coverage


## CI jobs and Git pre-push integration
- [x] إنشاء Jobs مستقلة للفحوصات fast وfull وsecurity
- [x] إضافة بوابة quality تعتمد على نتائج Jobs قبل بناء APK
- [x] إضافة سكريبت ci_local.sh متعدد الأوضاع إلى المستودع
- [x] إضافة pre-push hook قابل للتثبيت والتحقق من commits قبل الرفع
- [x] تشغيل التحقق المحلي ودفع ملفات CI الجديدة؛ fast نجح و65 اختباراً كاملة في آخر coverage


## Reusable Flutter CI coverage skill and Gemini tests
- [x] إنشاء مهارة reusable لخطوات fast/full/security وpre-push وcoverage
- [x] إضافة موارد أو قوالب المهارة وتعليمات التشغيل والتحقق؛ quick_validate ناجح
- [x] إضافة اختبارات GeminiService للتخزين المؤقت والمهلات والتطبيع والاستثناءات
- [x] تشغيل quick_validate والتحليل والاختبارات وcoverage؛ Gemini 90.80%، الإجمالي 77.72%
- [x] دفع الاختبارات وتسليم SKILL.md للمستخدم؛ commit 50ee413


## VoskEngine abstraction and fake_async timers
- [x] فحص العقود الحالية لـVoskService وAiAgentService والتوافق مع الاختبارات
- [x] تنفيذ واجهة VoskEngine وتنفيذ Vosk الحقيقي مع إدارة lifecycle آمنة
- [x] إضافة FakeVoskEngine قابل للتحكم في init/start/stop/failure
- [x] إضافة fake_async لاختبار Timer وحالات التسجيل والمهلات
- [x] تشغيل التحليل والاختبارات والتغطية ودفع التغييرات؛ 72 اختباراً ناجحاً، VoskService 64.86%، الإجمالي 77.99%


## Smart Accountant v3.0.0 — full Arabic voice accounting
- [x] محلل عربي أوفلاين للأوامر المركبة والوصف والأشخاص والأصناف
- [x] دعم الأرقام العربية والرقمية والفواصل والكمية × سعر الوحدة
- [x] إنشاء جداول expenses وpurchases وsales وdebt_for_me وdebt_on_me وinventory
- [x] ربط AiAgentService بالحفظ المتخصص مع استمرار سجل transactions القديم
- [x] دعم أوامر التقارير والبحث أوفلاين
- [x] اختبارات الأمثلة التسعة والتخزين والحسابات والبيانات غير الصالحة
- [x] flutter analyze و82 اختباراً ناجحاً وcoverage 80.58%
- [x] بناء APK v3.0.0 النهائي والتحقق من CI؛ app-release.apk بحجم 92.2MB


## Final verification — v3.0.0
- [x] إصلاح تعارض google_fonts مع Flutter الحالي بإزالة الاستدعاء التنفيذي غير المتوافق مع بقاء الحزمة اختيارية في pubspec
- [x] تشغيل flutter analyze بنتيجة No issues found
- [x] تشغيل flutter test --coverage --concurrency=1؛ 104 اختبارات ناجحة
- [x] توليد coverage/html/index.html وcoverage/lcov.info؛ التغطية الكلية 86.95% (1239/1425)
- [x] بناء APK Release نهائي؛ build/app/outputs/flutter-apk/app-release.apk بحجم 95.6MB
- [x] توثيق عدم رفع ملفات النموذج الثنائية الكبيرة ضمن Git والاكتفاء بالأصول المتاحة فعلياً
- [x] جاهزية commit نهائي للمستودع smart-accountant

## ملاحظات تاريخية
- [x] تم تجاوز البنود التاريخية الخاصة بمراحل v1/v2 أو استبدالها بتصميم v3 الحالي؛ لا تُعاد دون طلب صريح.


## Gemini Backend Proxy Integration
- [x] إنشاء Backend Node.js/TypeScript مستقل مع Endpoint `/v1/accounting/parse`
- [x] إضافة Zod للتحقق من الطلب واستجابة Gemini والأنواع والمبالغ والكميات
- [x] إضافة مصادقة ومحدد معدل ومهلة وإخفاء الأسرار في سجلات Backend
- [x] نقل استدعاء Gemini من عميل Flutter إلى AccountingBackendClient عبر HTTPS
- [x] الإبقاء على AiAgentParser كـ fallback أوفلاين عند فشل Backend أو غياب الشبكة
- [x] إضافة اختبارات HTTP fake لمسارات النجاح والاستجابة غير 200 وtimeout وJSON غير الكائني
- [x] تشغيل analyze والاختبارات وبناء Backend TypeScript وتوثيق إعدادات التشغيل دون مفتاح داخل Git


## Real JWT Authentication and Offline-first Resilience
- [x] اختيار Supabase افتراضياً مع دعم Firebase Auth وتوثيق متطلبات التوكن
- [x] استبدال فحص Bearer الشكلي بتحقق JWT حقيقي في Backend
- [x] ربط هوية المستخدم بالطلب ومنع استخدام توكن منتهي أو جهة إصدار غير موثوقة
- [ ] ربط عميل Flutter فعلياً بـFirebase/Supabase SDK لتوفير access token وتجديده؛ fallback الشبكة مطبق
- [x] اختبار Supabase JWT بتوقيع RSA محلياً: التوكن الصحيح، audience الخاطئ، role الخاطئ، والانتهاء؛ واختبار Firebase adapter للـrevocation failure
- [ ] اختبار حفظ SQLite المحلي وعدم التكرار عند فشل Backend وإعادة المحاولة عبر outbox
- [x] تحديث دليل التشغيل ونتائج التحقق دون تضمين أسرار حقيقية


## Flutter Auth Token Binding
- [x] تحديث مهارة Smart Accountant لتوثيق ربط Flutter بـFirebase/Supabase access token مع كل طلب
- [x] إضافة نمط token loader قابل للحقن مع إعادة محاولة واحدة بعد 401؛ ربط SDK الفعلي يبقى اختيارياً لكل المشروع
- [x] منع إرسال GEMINI_API_KEY من Flutter والحفاظ على fallback المحلي عند فشل الشبكة أو المصادقة
- [x] إضافة اختبارات عميل تغطي Authorization وغياب التوكن و401 مع refresh وtimeout وfallback؛ 5 اختبارات ناجحة


## Supabase End-to-End Integration Tests
- [x] إضافة اختبار تكامل HTTP يمرر Supabase JWT إلى Backend ثم يعيد JSON محاسبياً مطابقاً للمخطط
- [x] تشغيل Backend محلياً مع JWKS RSA مزيف وGemini fake دون أسرار إنتاجية
- [x] اختبار رفض توكن Supabase المنتهي قبل استدعاء Gemini؛ تغطية انقطاع الشبكة و401 وإعادة التوكن موجودة في اختبارات العميل
- [x] توثيق تشغيل الاختبار في CI وAndroid staging دون تضمين مفاتيح حقيقية
- [x] تحديث مهارة Smart Accountant بسير عمل اختبارات التكامل والـfixtures


## Production Backend Observability
- [x] إضافة logging منظم بصيغة JSON مع request ID وإخفاء الأسرار والبيانات الحساسة
- [x] إضافة metrics للصحة ومعدلات الطلبات والأخطاء والمهل وزمن Gemini
- [x] إضافة health/readiness endpoints مناسبة للتشغيل الإنتاجي
- [x] إضافة اختبارات observability تمنع تسريب Authorization والنص المحاسبي الكامل؛ الأسرار لا تُقرأ أصلاً من الطلب
- [x] تحديث مهارة Smart Accountant بممارسات التنبيه والاحتفاظ بالسجلات والاستجابة للحوادث


## Prometheus Production Export
- [x] إضافة prom-client وPrometheus text exposition على `/metrics`
- [x] الإبقاء على `/metrics.json` للتشخيص الداخلي وحماية المسارين بـMETRICS_SCRAPE_TOKEN الاختياري
- [x] إضافة prometheus.yml وقواعد تنبيه مع bearer_token_file وHTTPS وlabels منخفضة الكاردينالية
- [x] إضافة اختبار Content-Type واسم metric ورفض/قبول scrape token
- [x] تحديث المهارة وREADME بممارسات promtool والتحقق الإنتاجي
- [ ] تشغيل promtool في CI أو بيئة Prometheus فعلية؛ غير متوفر محلياً في هذه الجولة


## Grafana Dashboard Provisioning
- [x] إنشاء Dashboard JSON قابل للاستيراد يعرض مقاييس Smart Accountant الأساسية
- [x] إضافة provisioning لمصدر Prometheus واللوحة دون أسرار أو معرفات ثابتة
- [x] إضافة اختبارات بنية JSON ووجود PromQL للمقاييس الفعلية
- [x] تحديث المهارة بدليل الاستيراد والتشغيل والتنبيهات
- [x] توثيق أن التحقق النهائي يحتاج Grafana/Prometheus فعليين أو promtool في CI


## Prometheus 5xx Alert Delivery
- [x] إضافة قاعدة 5xx قابلة للتهيئة مع threshold وfor وlabels مستقرة
- [x] إضافة إعداد Alertmanager للتجميع والكبت وإرسال Slack أو Webhook
- [x] إبقاء Webhook وSlack secrets خارج Git باستخدام secret files أو environment
- [x] إضافة اختبار بنية قواعد التنبيه وإجراء dry-run آمن؛ الاختبار المحلي يثبت العقد، وamtool يحتاج CI/staging
- [x] تحديث مهارة Smart Accountant بتشغيل Alertmanager واختبار recovery


## Promtool Alert Rule Unit Tests
- [x] إنشاء ملف promtool test rules لقاعدة 5xx وسلاسل زمنية اصطناعية
- [x] تغطية حالات firing وpending وresolved وعدم إطلاق التنبيه تحت العتبة
- [x] إضافة فحص promtool إلى CI مع تثبيت نسخة Prometheus بشكل حتمي
- [x] تحديث المهارة بدليل promtool وقراءة نتائج الاختبار
- [x] توثيق وتشغيل مسار التحقق؛ promtool غير مثبت محلياً ويُشغّل داخل CI عبر حاوية رسمية


## Local Alertmanager Compose Lab
- [x] إنشاء Docker Compose محلي يربط Prometheus وAlertmanager وWebhook receiver
- [x] إضافة receiver اختباري يسجل payloads firing وresolved دون أسرار
- [x] إضافة إعداد Slack اختياري عبر secret file أو environment خارج Git
- [x] إضافة سكربت تشغيل وتنظيف واختبار health وalert delivery
- [x] تحديث المهارة بتركيب المختبر وقيود عدم استخدام Slack الإنتاجي محلياً


## Alertmanager CI/CD Automation
- [x] إضافة job مستقل لفحص promtool داخل GitHub Actions بنسخة Prometheus مثبتة
- [x] إضافة فحص amtool لإعداد Alertmanager داخل نفس المسار
- [x] ربط job المراقبة ببوابة الجودة لمنع Build وRelease عند الفشل
- [x] حفظ تقارير وإخفاقات المراقبة كـCI artifacts دون أسرار
- [x] تحديث المهارة بدليل تشغيل CI وقيود Docker والـsecrets


## Container and Dependency Security Scans
- [x] إضافة Trivy filesystem وdependency scan مع SARIF وthreshold واضح
- [x] إضافة فحص صور Docker المستخدمة في مختبر Alertmanager بإصدارات مثبتة
- [x] إضافة فحص Snyk اختياري مشروط بوجود SNYK_TOKEN دون فشل زائف عند غيابه
- [x] ربط نتائج الفحص ببوابة الجودة وحفظ التقارير دون أسرار
- [x] تحديث المهارة بوصف سياسة الثغرات وطرق التشغيل المحلي وCI


## Unified GitHub Security Report
- [x] جمع SARIF من Trivy وSnyk مع categories فريدة داخل GitHub Code Scanning
- [x] توليد تقرير Markdown وJSON موحد حسب الأداة والشدة والمكوّن والحالة
- [x] إضافة ملخص إلى GITHUB_STEP_SUMMARY ورفع التقرير كـartifact قصير الاحتفاظ
- [x] إضافة اختبار parser للتقرير يمنع التسريب ويعالج SARIF الناقص
- [x] تحديث المهارة بدليل GitHub Security وREST API وإعادة التشغيل


## Critical Security Notifications
- [x] إضافة أداة تقييم التقرير الموحد وإرسال تنبيه Critical إلى Slack أو البريد
- [x] تمرير القنوات عبر GitHub Secrets مع منع أي قيمة افتراضية أو تسجيل للسر
- [x] ربط الإخطار ببوابة الجودة ومنع النشر عند وجود Critical
- [x] إضافة اختبارات no-critical وcritical وredaction وفشل القناة
- [x] تحديث المهارة بدليل التشغيل والتدوير والـdeduplication


## Webhook Retry and Idempotency
- [x] إضافة backoff محدود لحالات 429 و5xx مع احترام Retry-After
- [x] إضافة مفتاح idempotency ثابت لكل Workflow/finding/channel
- [x] اختبار 429 و5xx وإعادة المحاولة وعدم تكرار الرسائل
- [x] تحديث Workflow والمهارة والتوثيق ثم دفع التعديل


## Local HTTPS Redis Idempotency Gateway
- [x] إضافة بوابة محلية تستقبل التنبيه وتطبق Redis SET NX مع TTL
- [x] إضافة تحقق من Idempotency-Key وحماية endpoint وforwarding اختياري
- [x] إضافة اختبارات مفتاح ثابت ومختلف ومنع المكرر في test_notify_security.py
- [x] إضافة Compose وHTTPS local certificate instructions وتحديث المهارة (فحص Compose يتطلب Docker Compose غير المتاح في الساندبوكس)


## Security Gateway Production TLS Integration
- [x] إضافة إعدادات Redis TLS وشهادات mTLS إلى Security Gateway عبر متغيرات بيئة أو ملفات أسرار
- [x] ربط security-notify في GitHub Actions بـSecurity Gateway عبر HTTPS وIdempotency-Key
- [x] توثيق أسرار الشهادات وإجراءات الدوران وعدم تخزينها في Git أو artifacts
- [x] إضافة اختبارات الإعدادات والتوثيق والتحقق ثم دفع التعديل


## Security Gateway Reusable Skill and Live Integration Test
- [x] إضافة runner لاختبار البوابة وRedis داخل Docker Compose
- [x] إثبات 202 للطلب الأول و200 duplicate للطلب الثاني عبر Redis الفعلي
- [x] تحديث مهارة skill-creator بمسار الاختبار الحي وmTLS وRedis TLS
- [x] تشغيل التحقق وتوثيق قيود Docker ثم دفع التعديل


## Weekly Security Gateway Monitoring
- [x] إضافة أداة تجميع أخطاء البوابة وتوليد تقرير أسبوعي منقح
- [x] إضافة Workflow مجدول يرسل التقرير إلى Slack
- [x] إضافة اختبارات للتجميع والتنقيح والحالات الخالية من الأخطاء
- [x] تحديث المهارة والتوثيق ثم التحقق والدفع


## Weekly Report Verification
- [x] إضافة اختبار متوسط زمن الاستجابة مع قيم غير صالحة أو مفقودة
- [x] إضافة اختبار حدود نافذة السبعة أيام والأحداث بلا timestamp
- [x] توثيق cron الإثنين وتشغيل workflow يدوياً


## Weekly Workflow Failure Alerts
- [x] إضافة أداة تنبيه فشل Workflow إلى Slack بملخص آمن
- [x] إضافة job يعمل دائماً بعد فشل التقرير الأسبوعي
- [x] إضافة مفتاح idempotency لتنبيه الفشل واختبارات التكرار
- [x] تحديث المهارة والتوثيق ثم التحقق والدفع


## Prometheus Alertmanager and Redis Idempotency Slides
- [x] جمع مراجع رسمية وتوثيق PromQL وقواعد Alertmanager وفحص Redis
- [x] إنشاء عرض شرائح عربي منظم مع أمثلة تشغيلية
- [x] مراجعة العرض وتقديمه للمستخدم


## Security Gateway Load Testing
- [x] إضافة اختبار k6 قابل للتشغيل مع ramp-up وتحقق من SLA وIdempotency
- [x] إضافة مراقبة Redis وGateway أثناء اختبار الحمل وتوثيق حدود البيئة
- [x] تحديث المهارة بالاختبار الآمن وتحليل النتائج وعدم تشغيل ضغط إنتاجي افتراضياً
- [x] إضافة اختبارات/تحقق للملفات ثم دفع التعديل


## k6 Results Visual Analysis
- [x] إضافة محلل Python لنتائج load-results.json وتقرير HTML/Markdown
- [x] توليد رسوم للكمون ومعدل الطلبات والأخطاء ونتائج thresholds
- [x] إضافة اختبارات صيغ k6 الأساسية والحالات الناقصة
- [x] تحديث المهارة والتحقق ثم دفع التعديل


## k6 CI Visual Performance Report
- [x] إضافة Workflow staging لتشغيل k6 وتصدير load-results.json
- [x] تشغيل محلل Python وتوليد HTML/JSON وGITHUB_STEP_SUMMARY
- [x] فرض thresholds ورفع التقارير كـartifacts دون أسرار
- [x] تحديث المهارة والتوثيق والاختبارات ثم دفع التعديل


## k6 Failure Alerts
- [x] إضافة أداة Slack لملخص فشل اختبار الحمل دون كشف الأسرار
- [x] ربط التنبيه بوظيفة always في Workflow مع الاحتفاظ بفشل الاختبار
- [x] إضافة اختبارات payload وIdempotency ومسار القناة غير المفعلة
- [x] تحديث المهارة والتوثيق ثم التحقق والدفع


## Grafana Live Load Dashboard
- [x] إضافة Dashboard JSON لمقاييس k6 والبوابة وRedis
- [x] إضافة provisioning لمصدر Prometheus ولوحة Grafana
- [x] إضافة اختبار صحة JSON وPromQL وتوثيق الاستيراد
- [x] تحديث المهارة والتحقق ثم دفع التعديل


## Per-Endpoint PromQL Latency
- [x] إضافة متغير Endpoint واستعلامات p95 وp99 حسب route
- [x] إضافة اختبارات صحة PromQL وتحقق أسماء histogram labels
- [x] تحديث المهارة وتوثيق cardinality ثم التحقق والدفع


## P99 Latency Alert
- [x] إضافة قاعدة تنبيه p99 أعلى من 500ms لمدة 5 دقائق حسب route
- [x] ربط alert بـAlertmanager receiver مع labels وannotations آمنة
- [x] إضافة اختبار promtool لحالة firing وinactive
- [x] تحديث المهارة والتحقق ثم دفع التعديل


## Live P99 Alert Integration Test
- [x] إضافة fixture latency يرفع p99 فوق 500ms
- [x] إضافة runner يثبت pending ثم firing ثم resolved عبر Prometheus وAlertmanager
- [x] التحقق من وصول payload إلى مستقبل Alertmanager المحلي
- [x] تحديث المهارة والتوثيق ثم التحقق والدفع


## Alertmanager Webhook Security Testing
- [x] إضافة اختبارات منع تسريب Authorization وtokens وcookies وبيانات payload
- [x] اختبار تنقيح السجلات ورفض الحقول الحساسة عبر مستقبل Webhook
- [x] ربط فحص التسريب بالـCI دون طباعة الأسرار
- [x] تحديث المهارة والتوثيق ثم التحقق والدفع


## Authorized Security Gateway Penetration Testing
- [x] إضافة خطة نطاق وتفويض واختبار غير تدميري للبوابة
- [x] إضافة فحوص مصادقة mTLS وBearer وRedis وWebhook وAlertmanager
- [x] إضافة اختبارات حدود CI ومنع تسريب التقارير والأسرار
- [x] تحديث المهارة بتقرير PenTest وقواعد التوقف والتصعيد
- [x] تشغيل التحقق والدفع


## Weekly Authorized PenTest Digest
- [x] إضافة مولد ملخص أسبوعي لنتائج PenTest المنقحة
- [x] إضافة Workflow مجدول يوم الإثنين على staging مع Environment approval
- [x] إرسال ملخص الثغرات إلى Slack مع Idempotency وعدم كشف الأسرار
- [x] إضافة اختبارات وتحديث المهارة والتحقق ثم الدفع


## Security Regression Detection
- [x] إضافة أداة مقارنة التقرير الحالي بالسابق حسب بصمة finding
- [x] تصنيف الثغرات الجديدة والعائدة والمغلقة وتغيرات الشدة
- [x] دمج النتيجة في التقرير الأسبوعي وSlack وCI
- [x] إضافة اختبارات وتحديث المهارة والتحقق ثم الدفع


## Safe Endpoint Abuse-Resistance Testing
- [x] إضافة اختبار محدود للتحقق من 429 وRetry-After وrate limiting
- [x] إضافة اختبار timeout وpayload/connection bounds دون ضغط DDoS فعلي
- [x] ربط الفحوص بـCI مع guard يمنع production targets
- [x] تحديث المهارة والتوثيق والاختبارات ثم التحقق والدفع


## Safe Medium Stress Testing
- [x] إضافة سيناريو Stress متدرج للحمل المتوسط مع thresholds للكمون والأخطاء
- [x] إضافة مراقبة الموارد وقواعد الإيقاف وعدم استهداف الإنتاج
- [x] إضافة اختبارات الحواجز والمدخلات وتحديث المهارة
- [x] التحقق والدفع ثم توثيق تفسير النتائج


## Idempotent Payment Stress Testing
- [x] إضافة سيناريو k6 للدفع مع Idempotency-Key وإعادة المحاولة المحدودة
- [x] التحقق من 2xx/409/429/5xx وعدم تكرار الأثر المالي
- [x] توثيق وتحسين Node.js Event Loop وقياس event-loop lag
- [x] إضافة اختبارات الحواجز وتحديث المهارة والتحقق والدفع


## CI Idempotency and Database Transient Errors
- [x] إضافة Workflow لاختبارات الدفع وIdempotency في staging المحمي
- [x] إضافة quality gates للتكرار والـretry والـ429/5xx مع artifacts منقحة
- [x] توثيق استراتيجية Deadlock وserialization failures مع retry محدود وآمن
- [x] إضافة اختبارات الحواجز والتحقق وتحديث المهارة ثم الدفع


## Deadlock Alerts and Replay Protection
- [x] إضافة قواعد Prometheus لتنبيهات Deadlock وفشل staging
- [x] ربط Alertmanager بمسار Slack آمن مع deduplication وrecovery
- [x] توثيق ضوابط Webhook وتوقيع الطلبات وRedis Idempotency ضد Replay
- [x] إضافة اختبارات الحماية والتحقق وتحديث المهارة ثم الدفع


## Redis Lock and Idempotency Integration CI
- [x] إضافة اختبار تكامل متزامن لنفس Idempotency-Key مع Redis
- [x] التحقق من رفض body مختلف وإعادة المحاولة بعد انتهاء القفل
- [x] دمج الاختبار في GitHub Actions مع Redis service وartifacts منقحة
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## CI Idempotency Load Test
- [x] إضافة Job k6 مستقل يعتمد على نجاح Redis integration
- [x] إضافة smoke وmedium profiles مع thresholds وartifacts
- [x] إضافة حواجز staging ومنع production وإشعار فشل منقح
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## Live Grafana p95 Alert During k6
- [x] إضافة قاعدة p95 لكل testid عند تجاوز 750ms
- [x] ربط Alertmanager بتنبيه Slack مع deduplication وresolved notifications
- [x] إضافة تشغيل k6 عبر remote write وملخص فشل فوري في GitHub Actions
- [x] إضافة اختبارات المراقبة وتحديث المهارة والتحقق والدفع


## Local Prometheus Alertmanager Slack Lab
- [x] إضافة Compose محلي بمقاييس اصطناعية ومستقبل Webhook منقح
- [x] اختبار firing وresolved وتنبيه p95 وidempotency للـfingerprint
- [x] توثيق أوامر التشغيل وعدم استخدام Slack الإنتاجي
- [x] تحديث المهارة والتحقق والدفع


## PR Alert Lab CI
- [x] إضافة Workflow يعمل مع كل Pull Request لتشغيل مختبر التنبيهات المحلي
- [x] اختبار firing وresolved والتحقق من payload المنقح
- [x] رفع logs وartifacts عند الفشل فقط دون أسرار
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## PR Webhook SAST and DAST
- [x] إضافة SAST وفحص dependencies داخل Pull Request
- [x] إضافة DAST محدود على مختبر Webhook محلي غير إنتاجي
- [x] رفع SARIF وartifacts منقحة مع quality gates للثغرات العالية
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## Local Docker SAST Preflight
- [x] إضافة سكربت Docker لتشغيل Semgrep وTrivy بإصدارات مطابقة لـCI
- [x] حفظ SARIF وتقارير JSON وملخص منقح مع quality gates
- [x] إضافة اختبارات الحواجز والتحقق من عدم تسريب الأسرار
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## SARIF Pull Request Comments
- [x] إضافة رفع SARIF إلى Code Scanning مع category لكل أداة
- [x] إضافة ملخص SAST منقح داخل تعليق Pull Request قابل للتحديث
- [x] حماية تعليقات fork ومنع الأسرار وازدواجية التعليقات
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## Protected Production Branch
- [x] تحديد أسماء status checks الخاصة بـSAST وCode Scanning المطلوبة
- [x] إعداد سياسة branch protection لـmain/master مع مراجعة وموافقة
- [x] إضافة تحقق آلي من حماية الفرع وتوثيق خطوات GitHub
- [x] تحديث المهارة والتحقق والدفع


## CI Quality Gate Diagnosis
- [x] جمع سجلات GitHub Actions وتحديد الأسباب الجذرية للفشل
- [x] إصلاح تعارض Flutter SDK مع pubspec والـlockfile
- [x] إصلاح migration وخطة pgTAP ومسار Flutter integration test
- [x] تحديث المهارة والتوثيق والتحقق


## Security Review PR Escalation
- [x] إضافة قالب Pull Request يتضمن شرط مراجعة الأمن عند فشل Quality gate
- [x] إضافة CODEOWNERS لمسارات الأمن وWorkflow وBackend
- [x] إضافة Workflow لتصعيد PR الفاشل إلى فريق الأمن دون أسرار أو صلاحيات زائدة
- [x] إضافة اختبارات القالب والتصعيد وتحديث المهارة والتحقق والدفع


## Local workflow_run Simulation with act
- [x] إضافة payloads اصطناعية لنجاح وفشل workflow_run وfork PR
- [x] إضافة أمر act محلي يمنع أي API writes أو أسرار حقيقية
- [x] اختبار قرار التصعيد وmarker وsafe no-write path
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## act Slack Notification Integration
- [x] إضافة اختبار تكامل يستقبل firing وresolved من Alertmanager محلي
- [x] التحقق من deduplication وtestid وredaction داخل payloads
- [x] ربط التشغيل مع fixtures وact دون Slack أو GitHub API حقيقي
- [x] تحديث المهارة والتوثيق والتحقق والدفع


## Daily Unified Test and Security Report
- [x] إضافة مجمع يومي لنتائج الاختبارات التكاملية وSAST/DAST/Trivy وCoverage
- [x] إضافة Workflow مجدول مع تقرير Markdown وJSON منقح
- [x] إضافة إرسال Slack وEmail مع idempotency وحماية الأسرار
- [x] إضافة اختبارات التقرير وتحديث المهارة والتحقق والدفع


## Continuous Security Webhook Monitoring
- [x] إضافة مسار Alertmanager فوري منفصل عن التقرير اليومي
- [x] إضافة مستقبل Webhook مصادق مع HMAC وtimestamp وRedis Idempotency عند ضبط REDIS_URL
- [ ] إضافة retry محدود وdead-letter وقياس صحة التسليم في بوابة الإنتاج (Alertmanager retry موثق؛ التنفيذ الإنتاجي اللاحق)
- [x] إضافة اختبارات التكامل وتحديث المهارة والتحقق والدفع


## PR #1 status and production DLQ follow-up
- [x] متابعة نتائج فحوصات Pull Request رقم 1 وتوثيق حالات النجاح والفشل
- [ ] تنفيذ طابور Dead-Letter Queue لرسائل Webhook بعد استنفاد retry
- [ ] إضافة مقاييس التسليم التفصيلية وendpoint صحة/metrics واختبارات DLQ
- [x] تحديث توثيق التشغيل والمهارة بعد التحقق النهائي


## Redis Stream Worker and HMAC replay hardening
- [x] كتابة نموذج FastAPI لاستقبال Webhook والتحقق من HMAC وtimestamp
- [x] كتابة Redis Stream Worker مع Consumer Group وretry وDLQ
- [x] إضافة اختبارات للعقد الأمني والتكرار وإعادة المحاولة
- [x] توثيق إدارة مفاتيح HMAC والحدود الإنتاجية للنموذج


## Sorted Set delayed retry and Worker tests
- [x] استبدال انتظار العامل بجدولة retry في Redis Sorted Set
- [x] إضافة claim ذري للرسائل الجاهزة وإعادة إدخالها إلى Stream
- [x] إضافة اختبارات Pytest وFakeRedis للوحدة والتكامل والتنافس
- [x] تحديث توثيق retry والاختبارات والمهارة


## Redis-backed Circuit Breaker
- [x] تعريف حالات Circuit Breaker ومفاتيح Redis وسياسة الفتح والإغلاق
- [x] إضافة مورد Circuit Breaker قابل لإعادة الاستخدام مع single-flight
- [x] إضافة اختبارات الوحدة والتكامل والضغط للحالات والفشل المتزامن
- [x] تحديث المهارة والتوثيق والتحقق ثم مزامنة Pull Request


## Circuit Breaker Prometheus metrics
- [x] تعريف metrics منخفضة cardinality لحالات الدائرة ونتائج الاستدعاءات
- [x] إضافة Metrics collector وFastAPI /metrics instrumentation
- [x] إضافة اختبارات المقاييس وعدم تسريب labels عالية cardinality
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Circuit Open alert routing
- [x] إضافة قاعدة Prometheus لتنبيه Circuit Open المستمر
- [x] إضافة مسارات Alertmanager لـPagerDuty وWebhook مع resolved
- [x] إضافة اختبارات routing وpayload دون اتصال خارجي
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Grafana Redis Stream and Circuit Breaker dashboard
- [x] تحديد panels ومقاييس Redis Stream وCircuit Breaker
- [x] إنشاء Dashboard JSON قابل للاستيراد في Grafana
- [x] إضافة اختبارات JSON وPromQL وعدم استخدام labels عالية cardinality
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Redis Stream and Circuit Breaker load lab
- [x] تحديد سيناريوهات الحمل وحدود التشغيل الآمن خارج الإنتاج
- [x] إضافة سكربت Load Testing قابل للضبط يحفز Circuit Open
- [x] إضافة تحليل نتائج واختبارات تمنع استهداف الإنتاج أو labels عالية cardinality
- [x] تحديث المهارة والتوثيق ولوحة Grafana والتحقق ومزامنة Pull Request


## Kubernetes autoscaling from Redis Stream depth
- [x] تحديد عتبة عمق Redis Stream وقيم min/max replicas وسياسة scale down
- [x] إضافة Deployment وScaledObject KEDA مع Redis TLS وSecret reference
- [x] إضافة اختبارات manifests وتحديث Dashboard Grafana بمؤشرات HPA/KEDA
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## KEDA staging load verification
- [x] تحديد مراحل الحمل ومعايير نجاح scale-up وscale-down في Staging
- [x] إضافة مشغّل اختبار يقيس Redis Stream backlog وKEDA/HPA replicas
- [x] إضافة اختبارات آلية للـrunbook وحماية أهداف الاختبار
- [x] تحديث المهارة والتوثيق وGrafana والتحقق ومزامنة Pull Request


## CI/CD KEDA staging load gate
- [x] تعريف GitHub Environment وSecrets المطلوبة لاختبار Staging
- [x] إضافة Workflow ينتظر النشر ويشغل KEDA Load Test
- [x] إضافة تحقق scale-up وscale-down ورفع artifacts عند الفشل
- [x] تحديث المهارة والتوثيق واختبارات Workflow والتحقق ومزامنة Pull Request


## Redis outage chaos verification
- [x] تحديد تجربة Redis outage وحدود namespace والوقت ومعايير النجاح
- [x] إضافة مشغّل Chaos محمي يعزل Redis ويضمن الاستعادة
- [x] إضافة Workflow واختبارات تمنع التشغيل خارج Staging وتجمع الأدلة
- [x] تحديث المهارة والتوثيق وGrafana والتحقق ومزامنة Pull Request


## Distributed tracing for Redis chaos
- [x] تعريف spans وattributes آمنة لطلبات FastAPI وWorkers وRedis
- [x] إضافة OpenTelemetry instrumentation وJaeger exporter/configuration
- [x] ربط trace IDs بتجربة Redis outage وإضافة اختبارات collector والتسريب
- [x] تحديث المهارة والتوثيق وGrafana والتحقق ومزامنة Pull Request


## Production OpenTelemetry Collector sampling
- [x] تحديد pipeline وذاكرة Collector وسياسة Tail-based Sampling
- [x] إضافة فلترة وإزالة الحقول الحساسة مع إعداد Collector إنتاجي
- [x] إضافة اختبارات YAML وPII redaction وsampling/resource limits
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## OpenTelemetry Collector Grafana observability
- [x] تحديد مقاييس Collector للطوابير والذاكرة والرفض والتصدير وsampling
- [x] تحديث Dashboard Grafana بلوحات أداء Collector والتنبيهات
- [x] إضافة اختبارات Dashboard وPromQL وغياب labels عالية cardinality
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Advanced Collector alert routing
- [x] تعريف قواعد Prometheus للذاكرة والطوابير والرفض وفشل التصدير وغياب Collector
- [x] إضافة Alertmanager routing مخصص حسب severity مع deduplication وinhibition
- [x] إضافة اختبارات YAML وPromQL وpromtool وغياب الأسرار
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Local synthetic notification testing
- [x] تعريف Mock Webhook وPagerDuty وعزل الأسرار والوجهات الإنتاجية
- [x] إضافة Synthetic runner لاختبارات firing وresolved وdeduplication
- [x] إضافة اختبارات payload وHMAC وredaction وtimeouts
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request


## Alertmanager integration verification
- [x] تعريف Compose محلي لـPrometheus وAlertmanager وMock receiver
- [x] إضافة اختبار تكاملي لـfiring وresolved وrouting
- [x] إضافة تحقق inhibition وgrouping وغياب أسرار الإنتاج
- [x] تحديث المهارة والتوثيق والتحقق ومزامنة Pull Request
