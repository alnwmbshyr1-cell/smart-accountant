# مقاني — تطبيق إدارة المواشي

تطبيق Flutter عربي باتجاه RTL لإدارة رؤوس المواشي والأرقام والتطعيمات محلياً على Android. تم اعتماد اللون البرتقالي `#D97706` كلون أساسي، والأخضر `#16A34A` للإجراءات الناجحة.

## الوظائف المنفذة

تتضمن النسخة شاشة افتتاحية باسم «مقاني»، ولوحة رئيسية تحتوي على التنبيه والإحصاءات والبحث والمرشحات وبطاقات الحيوانات، بالإضافة إلى شاشة إضافة رأس مع التحقق من الرقم والاختيارات وتاريخ الولادة. كما تتضمن شاشة إنشاء الأرقام الملونة وحذفها والبحث فيها، وشاشة التطعيمات مع اختيار الشهر وقائمة رؤوس اليوم.

## التخزين المحلي

يُنشئ التطبيق قاعدة SQLite باسم `maqani.db` داخل مساحة تطبيق Android. الجداول الحالية هي `animals` و`tags`، وتُزرع أربعة سجلات تجريبية عند الإنشاء الأول حتى تظهر الواجهة بصورة قابلة للتجربة مباشرة. جميع عمليات الإضافة والقراءة والحذف في الواجهة تمر عبر طبقة `LivestockDb` المحلية.

## السجل المرضي والتقارير المالية

تحتوي شاشة `السجل المرضي` على إضافة حالة مرتبطة برقم الرأس، التشخيص، الملاحظات، وحالة المتابعة (`قيد المتابعة` أو `تماثل للشفاء` أو `مغلقة`) مع مرشحات لعرض الحالات حسب وضعها الصحي.

تحتوي شاشة `تقارير الأرباح والمصاريف` على ملخص الإيرادات والمصاريف وصافي الربح أو الخسارة، وقائمة آخر الحركات المالية، مع نموذج لإضافة إيراد أو مصروف وتصنيفه وقيمته وملاحظاته. تمت إضافة جدولَي `health_records` و`financial_entries` إلى SQLite مع ترقية تلقائية من إصدار القاعدة السابق.

## التنبيهات والإشعارات

تمت إضافة `lib/notification_service.dart` باستخدام إشعارات Android المحلية، لذلك لا يحتاج التذكير إلى خادم أو اتصال دائم بالإنترنت. عند تشغيل التطبيق تُطلب صلاحية الإشعارات وصلاحية المنبهات الدقيقة على Android. لجدولة تذكير تطعيم بعد حفظ الموعد، استدعِ:

```dart
await MaqaniNotificationService.instance.scheduleVaccinationReminder(
  id: animalId,
  animalNumber: '102',
  date: vaccinationDate,
);
```

ولجدولة متابعة حالة مرضية:

```dart
await MaqaniNotificationService.instance.scheduleHealthFollowUp(
  id: healthRecordId,
  animalNumber: '102',
  condition: 'التهاب العين',
  date: followUpDate,
);
```

تتم إعادة جدولة الإشعارات بعد إعادة تشغيل الجهاز عبر `RECEIVE_BOOT_COMPLETED`. قد تمنع بعض هواتف Android المعدّلة عمل التنبيهات في الخلفية؛ عند حدوث ذلك يجب السماح للتطبيق بالعمل تلقائياً من إعدادات البطارية.

## بناء APK عبر GitHub Actions

تمت إضافة الملف `.github/workflows/android-apk.yml`. يعمل تلقائياً عند الدفع إلى `main` أو إنشاء Pull Request، ويمكن تشغيله يدوياً من تبويب **Actions** عبر اختيار `Build Maqani Android APK` ثم `Run workflow`. بعد انتهاء المهمة، افتح قسم **Artifacts** وحمّل `maqani-apks-...`، وستجد نسخ APK منفصلة لمعمارية `armeabi-v7a` و`arm64-v8a` و`x86_64`.

النسخة الحالية تبني APK غير موقّع بتوقيع release مخصص؛ قبل النشر في Google Play يجب إضافة keystore مشفّر إلى GitHub Secrets واستخدامه في خطوة توقيع منفصلة، وعدم وضع ملف keystore أو كلمات المرور داخل المستودع.

## مزامنة SQLite مع السحابة

يوجد ملف `lib/sync_service.dart` كطبقة REST عامة، ويمكن استخدامه مع Supabase Data API أو خادم REST خاص. النمط المقترح هو **Offline-first**: تُحفظ العملية أولاً في SQLite، ثم تُرفع عند توفر الاتصال، ويُعاد تنزيل التغييرات بعد تسجيل الدخول أو عودة الشبكة.

مثال الاستخدام مع Supabase:

```dart
final sync = MaqaniSyncService(
  baseUrl: const String.fromEnvironment('SUPABASE_URL'),
  publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  userId: currentUserId,
);

await sync.sync(localTables: {
  'animals': localAnimals,
  'health_records': localHealthRecords,
  'financial_entries': localFinancialEntries,
});
```

لا تضع `service_role_key` داخل APK؛ يجب استخدام publishable/anon key مع تسجيل دخول المستخدم وسياسات RLS. أُضيف ملف SQL اختياري في `supabase/migrations/202608230001_sync.sql` ينشئ الجداول السحابية مع `owner_id` و`local_id` و`updated_at` و`deleted_at` وسياسات تمنع المستخدم من الوصول إلى بيانات مزرعة أخرى. هذا يتبع قاعدة Supabase التي تجعل `auth.uid()` حدّ الملكية والصلاحية [2].

للمزامنة ثنائية الاتجاه في الإنتاج، أضف إلى SQLite حقول `updated_at` و`sync_status` و`deleted_at`. عند الحفظ يُعيّن السجل إلى `pending`، وعند نجاح الرفع إلى `synced`. إذا حدث تعديل على الجهاز والخادم معاً، استخدم قاعدة واضحة مثل **آخر تعديل يفوز** بالاعتماد على `updated_at` UTC، أو احتفظ بنسختين واعرض التعارض للمستخدم في شاشة المزامنة. لا تحذف السجل فوراً؛ استخدم soft delete حتى يصل الحذف إلى الخادم ثم احذف السجل محلياً بعد تأكيد المزامنة.

يوجد مساران عمليان للمزامنة:

| المسار | المزايا | ما يحتاجه |
|---|---|---|
| Supabase | PostgreSQL وAuth وRLS وRealtime جاهزة | مشروع Supabase، تسجيل دخول، وMigration SQL |
| خادم REST خاص | تحكم كامل واستضافة داخلية أو سحابية | API للمصادقة وupsert ونسخ احتياطي ومراقبة |

لبيئة مزرعة داخلية بلا إنترنت خارجي، يمكن تشغيل REST API داخل الشبكة المحلية على جهاز دائم التشغيل، مع إبقاء SQLite هو المصدر المحلي الأساسي. للمزامنة عبر الإنترنت بين أجهزة متعددة، يُفضّل Supabase أو خادم HTTPS موثوق مع نسخ احتياطي.

## مصادقة المستخدمين عبر Supabase

أُضيفت شاشة `lib/auth_screen.dart` وبوابة `AuthGate` في `lib/main.dart`. عند تزويد التطبيق بعنوان المشروع ومفتاح publishable، سيظهر تسجيل الدخول تلقائياً، وتُحفظ الجلسة محلياً بواسطة Supabase، ويؤدي زر تسجيل الخروج إلى إنهاء الجلسة والعودة إلى شاشة الدخول. عند عدم تزويد القيم، يستمر التطبيق في وضع SQLite المحلي للتجربة.

فعّل **Email provider** من Supabase Dashboard، ثم شغّل التطبيق بقيم البناء التالية:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

للتسجيل يستخدم التطبيق `signUp`، وللدخول يستخدم `signInWithPassword`. إذا كان تأكيد البريد مفعلاً، سيُطلب من المستخدم فتح رسالة التأكيد قبل إنشاء جلسة دخول. راقب تغييرات الجلسة عبر `onAuthStateChange`؛ هذا هو التدفق الموصى به في عميل Supabase Flutter، مع استخدام `currentSession` عند بدء التطبيق [3].

شغّل Migration `supabase/migrations/202608230002_auth_profiles.sql` لإنشاء جدول `profiles` وربطه بـ `auth.users`. يجب أن تكون كل جداول التطبيق التي تحتوي بيانات مزرعة مرتبطة بعمود `owner_id uuid references auth.users(id)` وأن تحتوي على سياسات RLS تستخدم `auth.uid()`. لا تضع `service_role_key` داخل التطبيق؛ المفتاح الموجود في APK يجب أن يكون publishable/anon فقط، بينما الحماية الفعلية تُفرض في PostgreSQL عبر RLS [4].

## التشغيل

بعد تثبيت Flutter وAndroid SDK، نفّذ:

```bash
flutter pub get
flutter run
```

ولإنشاء حزمة Android:

```bash
flutter build apk --debug
```

ملاحظة: بيئة التنفيذ الحالية لا تحتوي على أمر `flutter` أو `dart`، لذلك تعذّر تشغيل `flutter analyze` وبناء APK داخلها. تم الاحتفاظ بملفات Android الحالية وتحديث اسم التطبيق الظاهر إلى «مقاني» في `AndroidManifest.xml`.

### References

[1]: https://pub.dev/packages/flutter_local_notifications "flutter_local_notifications — Pub.dev"
[2]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security"
[3]: https://supabase.com/docs/reference/dart/auth-onauthstatechange "Supabase Dart onAuthStateChange"
[4]: https://supabase.com/docs/guides/getting-started/quickstarts/flutter "Supabase Flutter Quickstart"
