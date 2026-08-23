# دليل اختبار Smart Accountant v3.0.0 ونقل Gemini إلى Backend آمن

## 1. النطاق والافتراضات

هذا الدليل يغطي مسارين منفصلين. المسار الأول هو اختبار APK على جهاز Android حقيقي، بما في ذلك الصلاحيات، تنزيل نموذج Vosk، الأوامر العربية، التخزين المحلي، العمل دون اتصال، الأداء، والاستماع في الخلفية. المسار الثاني هو نقل استدعاء Gemini من الهاتف إلى خادم وسيط حتى لا يوجد مفتاح Gemini داخل APK.

نقل Gemini إلى Backend يعني أن **تحليل Gemini يصبح مساراً يتطلب الإنترنت**. أما الوظائف الأساسية التي تعتمد على `AiAgentParser` وSQLite وVosk بعد تنزيل النموذج فتبقى محلية وأوفلاين. عند انقطاع الإنترنت يجب أن يستمر التطبيق باستخدام المحلل المحلي، ولا يجوز تعطيل التسجيل المحاسبي الأساسي بسبب فشل Backend.

## 2. اختبار APK على جهاز Android حقيقي

### 2.1 تجهيز الجهاز

استخدم جهازاً فعلياً واحداً على الأقل، ويفضل إنشاء مصفوفة اختبار تشمل Android 10 وAndroid 13 وAndroid 14 وAndroid 15، مع جهاز بمعمارية `arm64-v8a`. اشحن الجهاز، وفر مساحة إضافية كبيرة لتنزيل وفك نموذج Vosk، وتأكد من أن التاريخ والوقت مضبوطان تلقائياً. لا تستخدم جهازاً يحتوي على بيانات محاسبية حقيقية أثناء اختبار الحذف أو إعادة ضبط البيانات.

فعّل خيارات المطور من **الإعدادات > حول الهاتف > رقم الإصدار** بالضغط سبع مرات، ثم فعّل **USB debugging**. عند توصيل الهاتف وافق على بصمة RSA التي تظهر على الجهاز. توصي وثائق Android الرسمية باختبار التطبيق على جهاز حقيقي قبل الإطلاق، مع استخدام ADB للتحقق من الاتصال [Android hardware testing](https://developer.android.com/studio/run/device).

### 2.2 تثبيت النسخة

نزّل APK من [GitHub Release v3.0.0](https://github.com/alnwmbshyr1-cell/smart-accountant/releases/tag/v3.0.0)، أو من [الرابط المباشر](https://github.com/alnwmbshyr1-cell/smart-accountant/releases/download/v3.0.0/app-release-v1.0.2.apk). اسم الملف الموجود في Release يحمل لاحقة `v1.0.2` تاريخياً، لكن الأصل مرفق داخل Release v3.0.0؛ لا تغيّر اسم الحزمة يدوياً أثناء الاختبار.

بعد تنزيل الملف إلى الكمبيوتر نفّذ:

```bash
adb devices
adb install -r app-release-v1.0.2.apk
adb shell pm list packages | grep -i smart
```

إذا ظهرت حالة `unauthorized`، افتح الهاتف ووافق على نافذة USB debugging ثم أعد تنفيذ `adb devices`. إذا أردت اختبار تجربة المستخدم من البداية، امسح بيانات التطبيق قبل الاختبار؛ استبدل القيمة باسم الحزمة الذي يظهر من الأمر السابق:

```bash
adb shell pm clear <PACKAGE_NAME>
```

لا تمنح صلاحية الميكروفون قسراً قبل اختبار شاشة الصلاحيات؛ الهدف هو التأكد من أن التطبيق يطلبها في الوقت الصحيح ويتعامل مع السماح والرفض والرفض الدائم.

### 2.3 سجل الأدلة قبل الاختبار

ابدأ جلسة Logcat جديدة حتى تستطيع ربط كل نتيجة بالاختبار:

```bash
adb logcat -c
adb logcat -v threadtime > smart-accountant-device.log
```

وفي نافذة ثانية راقب الأخطاء المهمة:

```bash
adb logcat -v time | grep -iE 'flutter|vosk|smart|exception|fatal|permission|gemini'
```

سجّل لكل حالة: إصدار Android، طراز الجهاز، حالة الشبكة، وقت بدء العملية، وقت ظهور النتيجة، وهل حفظت العملية فعلاً. لا تضع مفاتيح API أو نصوصاً مالية حساسة في ملفات Logs المرسلة إلى طرف ثالث.

## 3. مصفوفة الاختبار الوظيفي

### 3.1 التشغيل الأول والصلاحيات

امسح بيانات التطبيق، شغله، وتحقق من أن الشاشة لا تتجمد أثناء التهيئة. يجب أن تظهر رسالة واضحة عند طلب الميكروفون، وأن يكون الرفض قابلاً للمعالجة دون انهيار. اختبر الحالات الثلاث: سماح، رفض مؤقت، ورفض دائم. في حالة الرفض الدائم يجب أن يعرض التطبيق إرشاداً لفتح إعدادات النظام، لا أن يقول إن العملية حُفظت.

بعد السماح، تحقق من أن زر الميكروفون يصبح متاحاً فقط بعد اكتمال تهيئة Vosk. اضغط عليه مرتين بسرعة؛ يجب ألا تبدأ جلستان متزامنتان، وألا يظهر `LateInitializationError`.

### 3.2 تنزيل نموذج Vosk لأول مرة

ابدأ الاختبار مع Wi-Fi مستقر وبيانات التطبيق ممسوحة. تحقق من ظهور حالة تهيئة مفهومة، وانتظر اكتمال تنزيل وفك النموذج. أغلق التطبيق أثناء التنزيل وافتحه مجدداً؛ سجّل هل يعيد التنزيل من الصفر، وهل يعرض فشلاً واضحاً بدلاً من استخدام ملف ناقص. هذه نقطة مخاطرة معروفة في التقرير الحالي لأن الاختبارات الآلية لا تستطيع محاكاة دورة Android الأصلية كاملة.

بعد اكتمال التنزيل فعّل **وضع الطيران** وأعد تشغيل التطبيق. نفّذ أمراً صوتياً محلياً. نجاح هذه الخطوة يثبت أن النموذج المحفوظ يعمل دون اتصال، لكنه لا يثبت وحده استمرار الاستماع في الخلفية على كل الأجهزة.

### 3.3 أوامر المحاسبة الأساسية

استخدم بيانات تطبيق جديدة، ثم اختبر كل أمر وسجّل الشاشة والعملية والمبلغ والجدول أو القسم المتوقع:

| الأمر | النتيجة المتوقعة |
|---|---|
| «سجل مصروف بنزين بعشرين ألف» | مصروف، بنزين، 20,000 ريال |
| «سجل مشتريات 10 أكياس رز كل كيس 15000» | مشتريات، كمية 10، سعر الوحدة 15,000، الإجمالي 150,000 |
| «سجل مبيعات خمسين ألف» | مبيعات، 50,000 ريال |
| «بعت بضاعة بمئة ألف» | مبيعات، 100,000 ريال، وليس مخزوناً |
| «دين لي على خالد بمئة ألف» | دين لي، خالد، 100,000 ريال |
| «سجلت دين علي للمورد بعشرة آلاف» | دين علي، المورد، 10,000 ريال |
| «أضف عشرة كراتين للمخزن» | مخزون، كمية 10، مع التحقق من سعر الوحدة أو طلبه إذا كان ضرورياً |
| «كم صرفت اليوم» | تقرير مجموع المصروفات اليومية دون إنشاء سجل جديد |

بعد كل عملية تحقق من أربعة أمور معاً: ظهور المبلغ بالأرقام قبل الحفظ إن كانت شاشة التأكيد مفعلة، وجود العملية في الشاشة الصحيحة، تحديث الإجمالي، وصدور الرد الصوتي **بعد الحفظ الفعلي**. إذا قال التطبيق «تم الحفظ» ولم تظهر العملية بعد إعادة فتح الشاشة، سجّل الحالة كفشل حرج.

### 3.4 الأرقام واللهجة والحالات السلبية

اختبر الصيغ الرقمية والكلامية: «1000»، «١٠٠٠»، «الف»، «عشرين الف»، «مليون»، «مليونين وخمسمية»، «مليون و200 ألف»، والفواصل العربية والإنجليزية. اختبر أيضاً أمرًا بلا مبلغ، أمراً بلا نوع، مبلغاً صفراً، مبلغاً سالباً، وعبارة غير محاسبية. النتيجة الصحيحة في الحالات غير الكاملة هي طلب التوضيح أو رفض الحفظ، وليس إدخال مبلغ افتراضي ثم إصدار رسالة نجاح.

اختبر الضوضاء المعتدلة، الكلام السريع، التوقف أكثر من ثانيتين، وإعادة الأمر بعد خطأ. لا تعتبر نتيجة واحدة في غرفة هادئة دليلاً على دقة عامة للهجة اليمنية.

### 3.5 اختبار عدم الاتصال والتراجع المحلي

نفّذ هذه الدورة:

1. شغّل الإنترنت وتأكد من أن Vosk والنموذج مهيآن.
2. فعّل وضع الطيران.
3. نفّذ أمراً من الأنواع الستة.
4. أغلق التطبيق وافتحه مجدداً مع استمرار وضع الطيران.
5. تحقق من استمرار ظهور السجل والإجماليات.
6. تأكد من عدم وجود رسالة توحي بنجاح Gemini؛ النجاح يجب أن يكون من المسار المحلي.

ثم أعد الإنترنت، وفّر مفتاحاً صالحاً في بيئة الاختبار فقط إن كان المسار الحالي يستخدم Gemini، وكرر أمراً واحداً. يجب أن تتعامل الواجهة مع النتيجة نفسها دون ازدواجية في الحفظ.

### 3.6 الخلفية والبطارية

اختبر Wake Word والاستماع الخفيف، إن كانت الميزة مفعلة، في الحالات التالية: التطبيق مفتوح، التطبيق في الخلفية، الشاشة مقفلة، الهاتف في وضع توفير الطاقة، وبعد إعادة تشغيل الهاتف. راقب إشعار الخدمة الأمامية عند الحاجة. بعض الشركات المصنّعة تقتل خدمات الميكروفون في الخلفية، لذلك سجّل النتيجة حسب طراز الجهاز وإعدادات تحسين البطارية.

هذه الاختبارات لا تثبت أن التطبيق يستمع دائماً أو يتعرف على صوت مالك الهاتف وحده. التعرف على المتحدث يحتاج نموذج Speaker Verification مستقل وسياسة خصوصية وموافقة صريحة، ولا ينبغي اعتباره متحققاً لمجرد نجاح Vosk.

## 4. اختبارات الأداء على الجهاز

قِس زمن التشغيل البارد، زمن تهيئة Vosk بعد التنزيل، زمن تحويل أمر قصير إلى نص، زمن التحليل والحفظ، وزمن ظهور الرد. نفّذ كل قياس عشر مرات وسجّل الوسيط وأبطأ قيمة، بدلاً من نشر أفضل نتيجة فقط.

استخدم Android Studio Profiler لمراقبة CPU والذاكرة والشبكة أثناء التشغيل، أو استخدم ADB للقياسات الأساسية:

```bash
adb shell dumpsys meminfo <PACKAGE_NAME>
adb shell dumpsys cpuinfo | grep -i <PACKAGE_NAME>
adb shell dumpsys batterystats --reset
# نفّذ جلسة الاستماع المحددة ثم:
adb shell dumpsys batterystats <PACKAGE_NAME>
```

اختبر 100 و1,000 و10,000 سجل، ثم مجموعة أكبر على جهاز بذاكرة محدودة. راقب أن الشاشة لا تحمل ملايين الصفوف دفعة واحدة، وأن Keyset Pagination تستمر باستخدام `date` و`id` بدلاً من `OFFSET`. لا تنفّذ حقن 10 ملايين سجل على هاتف إنتاجي قبل توفير مساحة ونسخة احتياطية وخيار إلغاء واضح.

## 5. لماذا لا يكفي Secure Storage لمفتاح Gemini؟

`flutter_secure_storage` أفضل من وضع المفتاح في المصدر، لكنه لا يجعل المفتاح سرياً بشكل مطلق؛ فالـAPK يعمل على جهاز يملكه المستخدم، ويمكن لمستخدم متقدم تحليل التطبيق أو الذاكرة. توصي Google صراحة بعدم كشف مفاتيح Gemini داخل تطبيقات الهاتف الإنتاجية، واستخدام Backend Proxy للمكالمات [Google API key security](https://ai.google.dev/gemini-api/docs/api-key).

## 6. التصميم المقترح للـ Backend

يصبح المسار التجاري كالتالي:

```text
Vosk على الهاتف
      │
      ├── بدون إنترنت ──> AiAgentParser ──> SQLite ──> الرد المحلي
      │
      └── مع إنترنت ──> HTTPS Backend
                           │
                           ├── مصادقة المستخدم
                           ├── تحديد الحجم والمعدل
                           ├── تحقق JSON Schema
                           ├── استدعاء Gemini بمفتاح الخادم
                           ├── إزالة أي بيانات حساسة من السجل
                           └── JSON موحد للهاتف
```

لا ترسل التسجيل الصوتي الخام إلى الخادم إذا كان Vosk قد حوّله محلياً إلى نص؛ أرسل النص المنسوخ فقط. هذا يقلل البيانات الحساسة وحجم النقل. إذا كان النص يحتوي أسماء عملاء أو أرقام هواتف، طبّق سياسة احتفاظ واضحة واحذف السجلات الخام بعد مدة محددة.

## 7. مثال Backend عملي باستخدام Node.js 20 وExpress

أنشئ خدمة مستقلة خارج مشروع Flutter، وثبّت `express` و`zod` و`helmet` و`cors` و`express-rate-limit`. خزّن المفتاح في Secret Manager أو متغير بيئة محمي، وليس في `.env` المرفوع إلى Git.

### 7.1 متغيرات البيئة

```dotenv
GEMINI_API_KEY=ضع_القيمة_في_بيئة_الخادم_فقط
GEMINI_MODEL=gemini-1.5-flash
ALLOWED_ORIGINS=https://your-admin.example.com
PORT=8080
```

استخدم اسم نموذج تدعمه حساباتك وواجهة Gemini وقت النشر؛ اجعل الاسم قابلاً للضبط حتى لا تحتاج إلى إعادة بناء تطبيق الهاتف عند تغيير النموذج.

### 7.2 نقطة API مع تحقق JSON Schema

الكود التالي مثال مرجعي مختصر. في الإنتاج أضف التحقق من JWT في `authenticateUser`، وربط المستخدم بحصته، وطبقة تخزين سجلات تدقيق لا تحتوي على المفتاح أو النص الكامل:

```ts
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { z } from 'zod';

const app = express();
const port = Number(process.env.PORT ?? 8080);
const geminiKey = process.env.GEMINI_API_KEY;
const geminiModel = process.env.GEMINI_MODEL ?? 'gemini-1.5-flash';

if (!geminiKey) throw new Error('GEMINI_API_KEY is required on the server');

const commandSchema = z.object({
  text: z.string().trim().min(1).max(2000),
});

const resultSchema = z.object({
  type: z.enum(['مبيعات', 'مشتريات', 'مصروف', 'دين_لي', 'دين_علي', 'مخزون']),
  amount: z.number().finite().nonnegative(),
  desc: z.string().trim().min(1).max(160),
  name: z.string().trim().max(160).default(''),
  quantity: z.number().finite().positive().default(1),
});

app.use(helmet());
app.use(express.json({ limit: '16kb' }));
app.use(cors({
  origin: (process.env.ALLOWED_ORIGINS ?? '').split(',').filter(Boolean),
  methods: ['POST'],
}));
app.use(rateLimit({ windowMs: 60_000, limit: 30, standardHeaders: true }));

function authenticateUser(req: express.Request, res: express.Response, next: express.NextFunction) {
  // اربط هذه النقطة بمصادقة حقيقية مثل Firebase Auth أو Supabase Auth.
  // لا تعتبر وجود أي Bearer عشوائي مصادقة في الإنتاج.
  const authorization = req.header('authorization') ?? '';
  if (!authorization.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'unauthorized' });
  }
  return next();
}

const prompt = (text: string) => `
أنت محاسب يمني دقيق. استخرج عملية واحدة من النص التالي.
أعد JSON فقط وفق هذا المخطط:
{"type":"مبيعات|مشتريات|مصروف|دين_لي|دين_علي|مخزون","amount":number,"desc":string,"name":string,"quantity":number}
حوّل الأرقام العربية والكلمات مثل ألف ومليون إلى رقم.
إذا لم يتضح المبلغ، أعد amount=0.
النص: ${text}
`;

app.post('/v1/accounting/parse', authenticateUser, async (req, res) => {
  const parsed = commandSchema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: 'invalid_request' });

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 20_000);

  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${geminiModel}:generateContent`,
      {
        method: 'POST',
        signal: controller.signal,
        headers: {
          'content-type': 'application/json',
          'x-goog-api-key': geminiKey,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt(parsed.data.text) }] }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 256,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                type: { type: 'STRING', enum: ['مبيعات', 'مشتريات', 'مصروف', 'دين_لي', 'دين_علي', 'مخزون'] },
                amount: { type: 'NUMBER' },
                desc: { type: 'STRING' },
                name: { type: 'STRING' },
                quantity: { type: 'NUMBER' },
              },
              required: ['type', 'amount', 'desc', 'name', 'quantity'],
            },
          },
        }),
      },
    );

    if (!response.ok) return res.status(502).json({ error: 'gemini_upstream_error' });
    const body = await response.json() as any;
    const raw = body?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof raw !== 'string') return res.status(502).json({ error: 'empty_model_response' });

    const result = resultSchema.safeParse(JSON.parse(raw));
    if (!result.success) return res.status(422).json({ error: 'invalid_model_payload' });
    return res.json(result.data);
  } catch (error) {
    // سجّل نوع الخطأ فقط، ولا تسجل المفتاح أو نص المستخدم الكامل.
    console.error('gemini_parse_failed', error instanceof Error ? error.name : 'unknown');
    return res.status(504).json({ error: 'backend_timeout_or_network' });
  } finally {
    clearTimeout(timer);
  }
});

app.get('/healthz', (_req, res) => res.json({ ok: true }));
app.listen(port, () => console.log(`accounting backend listening on ${port}`));
```

تنبيه: `JSON.parse(raw)` يجب أن يكون داخل طبقة معالجة أخطاء كما في المثال، ويجب عدم إعادة `raw` إلى العميل عند فشل التحقق. أما في الإنتاج فيُفضل استخدام **Structured Outputs** مع JSON Schema كما توضح وثائق Gemini [structured output](https://ai.google.dev/gemini-api/docs/structured-output)، مع إبقاء التحقق باستخدام Zod كطبقة دفاع ثانية.

## 8. تعديل Flutter

أضف عميلاً صغيراً للـBackend بدلاً من إنشاء `GenerativeModel` داخل الهاتف. لا تضع `GEMINI_API_KEY` في Flutter، ولا ترسل مفتاحاً محفوظاً في `flutter_secure_storage` إلى الخادم كبديل؛ الهاتف يرسل access token للمصادقة فقط.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AccountingBackendClient {
  AccountingBackendClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, dynamic>?> parseCommand({
    required String text,
    required String accessToken,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl/v1/accounting/parse'),
          headers: {
            'content-type': 'application/json',
            'authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }
}
```

في `AiAgentService` اجعل الترتيب كالتالي:

1. حوّل الصوت إلى نص محلياً عبر Vosk.
2. إذا كان النص فارغاً، أعد رسالة «لم أسمع شيئاً» دون اتصال بالشبكة.
3. إذا كان الإنترنت متاحاً ولدى المستخدم جلسة مصادق عليها، أرسل النص إلى Backend.
4. إذا أعاد Backend نتيجة صحيحة، تحقق منها مرة ثانية في Flutter ثم احفظها في SQLite.
5. إذا فشل الاتصال أو انتهت المهلة أو كانت النتيجة غير صالحة، استخدم `AiAgentParser` المحلي.
6. لا تنطق «تم الحفظ» إلا بعد نجاح `saveParsedCommand` فعلياً.

لا تستخدم `connectivity_plus` كدليل وحيد على توفر الإنترنت؛ الاختبار الحقيقي هو نجاح الطلب أو فشله. كما يجب منع إرسال الأمر نفسه مرتين باستخدام `requestId` أو بصمة للنص والزمن إذا كان زر المايك أو Wake Word قد يكرر الحدث.

## 9. حماية Backend قبل الاستخدام التجاري

استخدم TLS فقط، وضع الخادم خلف HTTPS وWAF أو API Gateway، وخزّن مفتاح Gemini في Google Secret Manager أو مدير أسرار مكافئ. حدّد حصة يومية لكل مستخدم، وحداً أقصى لطول النص، ومعدل طلبات، وميزانية وتنبيهات Billing. لا تعتمد على CORS للحماية من تطبيق الهاتف؛ CORS ليس آلية مصادقة لتطبيقات native.

استخدم Firebase Auth أو Supabase Auth أو مزود هوية مؤسسي للتحقق من access token في الخادم. اربط كل طلب بـ`userId`، لكن لا تسجل النص المالي الكامل في السجلات الاعتيادية. أضف مراقبة لمعدلات 401 و429 و5xx ووقت الاستجابة، مع إخفاء الأسرار في أدوات التتبع.

أنشئ مفتاحاً مخصصاً للخادم فقط، وقيّده بالخدمة والمشروع والحصة حسب ما تسمح به Google. راقب الاستخدام والتنبيهات المالية، وإذا ظهر تسريب فأنشئ مفتاحاً بديلاً، انقل الخادم إليه، ثم عطّل القديم بعد التحقق؛ هذه من خطوات الاستجابة الموصى بها في وثائق Google [API key security](https://ai.google.dev/gemini-api/docs/api-key).

## 10. خطة إطلاق تدريجية

ابدأ ببيئة staging ومفتاح وحصة منفصلين، ثم اختبر Backend باختبارات unit باستخدام HTTP fake دون اتصال Gemini. اختبر JSON صالحاً، JSON غير صالح، مبلغاً صفراً، نوعاً غير معروف، timeout، 401، 429، و502. بعد ذلك نفّذ اختبار جهاز حقيقي مع الشبكة ثم وضع الطيران.

في الإنتاج لا تجعل Backend شرطاً وحيداً لحفظ المعاملات. المسار الآمن لتجربة التطبيق هو: Vosk محلي، parser محلي مضمون، حفظ SQLite محلي، ثم Gemini كتحسين اختياري عند توفر الشبكة. بهذه البنية تبقى المحاسبة الأساسية أوفلاين، بينما ينتقل المفتاح والاتصال الخارجي إلى طبقة يمكن حمايتها ومراقبتها وتدوير أسرارها.

## 11. معايير القبول

يُقبل اختبار الجهاز إذا ثبت أن التطبيق يطلب الصلاحية ويتعامل مع كل نتائجها، ينزّل النموذج أو يعلن الفشل بوضوح، ينفذ الأوامر الستة مع حفظ فعلي، لا يكرر العملية عند النقر المتعدد، يعمل بعد تنزيل النموذج في وضع الطيران، ولا يعلن نجاحاً دون كتابة SQLite. ويُقبل Backend إذا لم يظهر المفتاح في Flutter أو APK أو Git، ونجحت المصادقة والتحديد والحصة والمهلة والتحقق من JSON، وعاد التطبيق إلى المحلل المحلي عند فشل الشبكة.
