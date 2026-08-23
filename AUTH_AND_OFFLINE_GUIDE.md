# مصادقة JWT وOffline-first في Smart Accountant

## التوصية

استخدم موفراً واحداً للهوية في البيئة الإنتاجية. **Supabase Auth** هو المسار الافتراضي المجهز في Backend الحالي لأنه يدعم التحقق المحلي عبر JWKS عند استخدام مفاتيح توقيع غير متماثلة. استخدم Firebase إذا كان تسجيل الدخول والبنية الحالية مبنية عليهما بالفعل. لا تقبل Firebase ID token في إعداد Supabase أو العكس.

| الخيار | تحقق الخادم | ما يرسله Flutter | متى يناسب |
|---|---|---|---|
| Firebase Auth | `firebase-admin.verifyIdToken(token, true)` | Firebase ID token | مشروع يعتمد Firebase Auth |
| Supabase Auth | `jose.jwtVerify` مع JWKS و`iss/aud/sub/role` | Supabase access token | مشروع يعتمد Supabase Auth ومفاتيح signing غير متماثلة |

توضح Firebase أن العميل يرسل ID token عبر HTTPS وأن الخادم يتحقق منه ويستخرج `uid`، بينما توصي Supabase باستخدام `getClaims()` أو مكتبة JWT موثوقة ومفاتيح JWKS بدلاً من كتابة التحقق يدوياً [1] [2].

## Backend

الملف `backend/src/auth.ts` يضيف `createJwtVerifier()` و`requireJwt()`. يختار `AUTH_PROVIDER`، ويرفض التوكن المفقود أو المنتهي أو ذي التوقيع أو issuer أو audience غير الصحيح. في Firebase يستخدم `verifyIdToken(token, true)`، والوسيط `true` يفعّل فحص الإبطال. في Supabase يستخدم JWKS من:

```text
https://<project-ref>.supabase.co/auth/v1/.well-known/jwks.json
```

إعداد Supabase:

```env
AUTH_PROVIDER=supabase
SUPABASE_PROJECT_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_JWT_AUDIENCE=authenticated
GEMINI_API_KEY=server-only-secret
```

إعداد Firebase:

```env
AUTH_PROVIDER=firebase
FIREBASE_PROJECT_ID=your-project-id
GEMINI_API_KEY=server-only-secret
```

في الإنتاج استخدم Application Default Credentials أو Workload Identity. للتطوير المحلي فقط يمكن تمرير `FIREBASE_SERVICE_ACCOUNT_JSON` كسر بيئي خارج Git. لا ترسل service-account JSON إلى الهاتف ولا تسجله.

في `server.ts` يجب أن يكون المسار محمياً هكذا:

```ts
const jwtVerifier = createJwtVerifier();
app.post(
  '/v1/accounting/parse',
  requireJwt(jwtVerifier),
  async (req, res) => {
    // req.authenticatedUser.uid هو هوية المستخدم الموثقة
  },
);
```

## Flutter: توفير التوكن

العميل الحالي `AccountingBackendClient` لا يحتاج إلى معرفة أسرار Gemini؛ يأخذ دالة `accessTokenLoader`. في Supabase استخدم SDK الرسمي:

```dart
Future<String?> loadSupabaseToken() async {
  return Supabase.instance.client.auth.currentSession?.accessToken;
}
```

وفي Firebase:

```dart
Future<String?> loadFirebaseToken() async {
  return FirebaseAuth.instance.currentUser?.getIdToken(true);
}
```

مرر الدالة عند إنشاء العميل، ولا تضع `GEMINI_API_KEY` في Flutter. استدعاء `getIdToken(true)` يطلب token محدثاً عند الحاجة، بينما يجب أن يتولى Supabase SDK إدارة الجلسة وتجديدها. في التطبيق الحالي، إذا لم تتم إضافة SDK بعد، يُستخدم التخزين الآمن للمفتاح `smart_accountant_backend_access_token` كحل انتقالي؛ هذا ليس بديلاً عن مصادقة حقيقية.

## Offline-first عند استخدام Backend

المسار الأساسي لا يعتمد على الشبكة:

```text
Vosk محلي → AiAgentParser → SQLite → الإجماليات → flutter_tts
```

وعند توفر اتصال وتوكن صالح يمكن استخدام المسار المحسن:

```text
Vosk محلي → Backend مصادق عليه → Gemini → Zod/تحقق Flutter → SQLite → TTS
```

عند حدوث timeout أو DNS failure أو 401 أو 429 أو 5xx أو JSON غير صالح، يرجع `AccountingBackendClient.parseCommand()` بقيمة `null`. عندها يستخدم `AiAgentService` `AiAgentParser` المحلي. لا يعلن التطبيق نجاح العملية قبل نجاح `saveParsedCommand()` في SQLite.

ينبغي حفظ كل عملية محلياً أولاً، وإضافة `requestId` أو بصمة مستقرة للأوامر التي قد تعاد بعد انقطاع الشبكة حتى لا تتكرر العملية. لا تضع عمليات المحاسبة في انتظار Gemini، ولا تحذف السجل المحلي عند فشل الرفع. عند عودة الشبكة، يمكن إضافة outbox منفصل للمزامنة، مع exponential backoff وjitter، وحالات `pending/sent/failed`; لا تعيد تنفيذ عملية محاسبية إلا بعد idempotency check.

تظل Vosk وSQLite وTTS متاحة في وضع الطيران بعد تنزيل النموذج. أما Gemini فهو تحسين اختياري عبر الإنترنت وليس جزءاً من الضمان الأوفلاين.

## اختبارات الأمان والاعتمادية

اختبر على الخادم: توكن مفقود، صيغة Bearer خاطئة، توكن منتهي، توقيع غير صالح، issuer خاطئ، audience خاطئ، `sub` مفقود، role غير مسموح، ونجاح مستخدم مصادق. اختبر Firebase مع توكن مُبطل، وSupabase بعد تدوير signing key. تحقق أن `uid` من claims هو المستخدم الذي تستخدمه الصلاحيات، ولا تعتمد على email أو user metadata القابل للتعديل.

اختبر على الهاتف: أمر صحيح مع الإنترنت، نفس الأمر دون إنترنت، انتهاء التوكن، فشل DNS، timeout، تكرار الطلب، إعادة تشغيل التطبيق أثناء الحفظ، وعودة الشبكة أثناء وجود outbox. معيار النجاح هو حفظ واحد فقط، وعدم فقدان السجل، وعدم نطق «تم» عند فشل SQLite.

## الحالة الحالية والقيود

تم تنفيذ طبقة التحقق الحقيقية في `backend/src/auth.ts`، وربطها بـ`/v1/accounting/parse`، وبناء Backend TypeScript بنجاح. كما نجحت اختبارات Flutter الحالية وعددها 108 اختبارات. ما يزال ربط `Supabase.instance.client` أو `FirebaseAuth.instance` بواجهة تسجيل دخول فعلية، واختبارات التوكن المنتهي والإبطال، مطلوباً قبل الاعتماد التجاري.

## References

[1]: https://firebase.google.com/docs/auth/admin/verify-id-tokens "Firebase Admin: Verify ID Tokens"
[2]: https://supabase.com/docs/guides/auth/jwts "Supabase: JSON Web Tokens"
[3]: https://supabase.com/docs/guides/auth/signing-keys "Supabase: JWT Signing Keys"
[4]: https://firebase.google.com/docs/auth/admin/manage-sessions "Firebase: Manage User Sessions"
