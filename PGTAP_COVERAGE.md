# اختبارات pgTAP وCoverage في مقاني

## التشغيل المحلي

```bash
supabase start -x studio
supabase db reset
supabase test db --local
flutter pub get
flutter test --coverage --concurrency=1 integration_test/rls_security_test.dart
```

يوضع اختبار قاعدة البيانات في `supabase/tests/database/rls_security_test.sql`. يختبر وجود الجداول والحقول، مرور المشرف من `private.is_admin()`, عزل المستخدم العادي، منع تعديل التنبيهات، منع إدخال سجل تدقيق مباشرة، ووجود سجل تدقيق ناتج عن Trigger.

## معنى التغطية

pgTAP يعطي نتيجة TAP وعدد assertions ناجحة وفاشلة، لكنه لا يعطي line coverage حقيقياً لسياسات SQL. لذلك تحفظ Pipeline ملف `test-results/pgtap.tap` كدليل تنفيذ، بينما يحسب Flutter ملف `coverage/lcov.info` لتغطية كود Dart. يجب عرضهما كتقريرين منفصلين؛ نجاح تغطية Dart لا يثبت صحة RLS.

## CI

يستخدم `.github/workflows/supabase-integration-tests.yml` Supabase المحلي، يعيد تطبيق الهجرات من الصفر، يشغّل `supabase test db --local`، ثم يشغّل اختبار Flutter ويجمع:

```text
test-results/pgtap.tap
test-results/flutter-integration.log
coverage/lcov.info
```

ترفع الملفات كـ artifact لمدة 14 يوماً. يوقف أي فشل في pgTAP أو Flutter المهمة، بينما تبقى التقارير محفوظة عبر `if: always()`.

## ملاحظات مهمة

لا تشغل اختبارات pgTAP عبر اتصال مالك قاعدة البيانات باعتبارها اختبار RLS؛ الاختبارات يجب أن تنتقل إلى دور `authenticated` وتضبط `request.jwt.claims` كما يفعل الملف الحالي. لا تستخدم بيانات الإنتاج أو مفاتيح `service_role` في CI الخاص بـ Pull Request.

إذا لم يدعم إصدار CLI الخيار `--local` مع `supabase test db`, احذف الخيار لأن وجود Supabase المحلي النشط يجعل التنفيذ محلياً، أو استخدم:

```bash
supabase test db 2>&1 | tee test-results/pgtap.tap
```

اختبارات Realtime تحتاج عميل Supabase متصلاً بمشروع محلي، ويجب أن تعيد query ابتدائياً بعد `CHANNEL_ERROR` أو `TIMED_OUT` لأن Realtime ليس سجلاً تاريخياً كاملاً.
