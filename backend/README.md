# Smart Accountant Gemini Backend

هذا الخادم يحمي `GEMINI_API_KEY` خارج تطبيق الهاتف. يرسل العميل نص الأمر مع access token قصير العمر إلى `POST /v1/accounting/parse`، ويتحقق الخادم من JWT قبل استدعاء Gemini.

## اختيار موفر الهوية

اضبط `AUTH_PROVIDER=supabase` لاستخدام Supabase JWT Signing Keys غير المتماثلة، أو `AUTH_PROVIDER=firebase` لاستخدام Firebase Admin SDK. لا تخلط بين Firebase ID token وSupabase access token؛ كل token يجب أن يُتحقق منه عند موفر الإصدار الصحيح.

## Supabase

```bash
cp .env.example .env
# اضبط SUPABASE_PROJECT_URL وGEMINI_API_KEY وAUTH_PROVIDER=supabase
npm install
npm run build
node --env-file=.env dist/server.js
```

يستخدم الخادم JWKS من:

```text
https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json
```

ويتحقق من `iss` و`aud` و`exp` و`sub` و`role=authenticated`. في عميل Flutter، اجعل `accessTokenLoader` يعيد `supabase.auth.currentSession?.accessToken`؛ مكتبة Supabase تدير تجديد الجلسة وفق إعداداتها.

## Firebase

اضبط:

```text
AUTH_PROVIDER=firebase
FIREBASE_PROJECT_ID=your-project-id
```

في الإنتاج استخدم Application Default Credentials أو Workload Identity. للتطوير المحلي فقط، يمكن حقن `FIREBASE_SERVICE_ACCOUNT_JSON` كسر بيئي خارج Git. يستخدم الخادم `verifyIdToken(token, true)` لفحص التوقيع والانتهاء والإبطال.

في Flutter، اجعل `accessTokenLoader` يعيد:

```dart
FirebaseAuth.instance.currentUser?.getIdToken(true)
```

ولا ترسل service-account JSON إلى الهاتف مطلقاً.

## اختبار الصحة

```bash
curl http://localhost:8080/healthz
curl -X POST http://localhost:8080/v1/accounting/parse \
  -H 'content-type: application/json' \
  -H 'authorization: Bearer <short-lived-user-token>' \
  -d '{"text":"سجل مصروف بنزين بعشرين ألف"}'
```

استجابة 401 تعني أن التوكن مفقود أو غير صالح، و400 تعني أن الطلب غير صحيح، و422 تعني أن مخرجات النموذج لم تجتز Zod، و502/504 تعني فشل Gemini أو انتهاء مهلة الخادم.

## اختبارات التكامل

اختبر عقدة Supabase وEndpoint محلياً دون أسرار إنتاجية:

```bash
npx vitest run test/auth.test.ts test/supabase_integration.test.ts
npm run build
```

ينشئ `supabase_integration.test.ts` مفتاح RSA وJWKS محلياً، يوقع JWT تجريبياً، يرسل طلب HTTP إلى Express عبر منفذ محلي، ويعترض طلب Gemini فقط. لذلك يغطي التوقيع والمصادقة وZod وعقدة HTTP دون الاعتماد على Supabase أو Gemini الحقيقيين. نفّذ اختبار staging منفصلاً على جهاز Android باستخدام Supabase SDK وHTTPS، ولا تضع access token أو service-role key في GitHub Actions.

## Flutter

شغّل:

```bash
flutter run --dart-define=GEMINI_BACKEND_URL=https://api.example.com
```

يقرأ العميل access token من `smart_accountant_backend_access_token` في النسخة الحالية. عند ربط SDK حقيقي، استبدل هذا القارئ بـ`Supabase.instance.client.auth.currentSession?.accessToken` أو `FirebaseAuth.instance.currentUser?.getIdToken(true)`. عند غياب الشبكة أو انتهاء المهلة أو رجوع 401/5xx، يعيد العميل `null` ويستخدم `AiAgentParser` المحلي.
