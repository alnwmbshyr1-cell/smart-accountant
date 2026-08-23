# Webhook and Redis Replay Protection

## حماية Webhooks

استخدم HTTPS مع تحقق صارم من شهادة الخادم، ويفضل mTLS بين Alertmanager أو الخدمة المرسلة والمستقبل الداخلي. وقّع body الخام باستخدام HMAC-SHA256، وأرسل `X-Webhook-Timestamp` و`X-Webhook-Id` و`X-Webhook-Signature`. احسب التوقيع على صيغة ثابتة مثل `timestamp + "." + raw_body`، ثم قارن التوقيع باستخدام constant-time comparison.

ارفض الطلب إذا كان timestamp خارج نافذة قصيرة، مثل خمس دقائق، أو إذا كان `Webhook-Id` مستخدماً سابقاً. خزّن hash للطلب أو معرفه في Redis مع TTL أطول من نافذة القبول، مثل عشر دقائق أو حسب أقصى تأخير متوقع. لا تعتمد على IP allowlisting وحده، ولا تقبل توقيعاً بعد parsing وإعادة serialization للـJSON.

طبّق body-size limit وcontent-type allowlist وrate limiting وtimeout، وارفض الحقول غير المعروفة. طبّق schema validation قبل المعالجة، واجعل المعالجة idempotent. لا تسجل Authorization أو HMAC secret أو body الخام أو بيانات الدفع؛ سجّل request ID وalert fingerprint منقحين فقط.

## إدارة Idempotency Keys في Redis

استخدم مفتاحاً namespaced مثل `idempotency:{tenant}:{key_hash}`، ولا تخزن المفتاح الخام إذا كان يحتوي بيانات حساسة. اجعل القيمة تتضمن request hash وحالة `processing` أو `completed` ونتيجة منقحة، وضع TTL إلزامياً. نفّذ claim ذرياً عبر `SET key value NX EX ttl`.

إذا نجح claim، عالج العملية. إذا كان المفتاح موجوداً وكانت قيمة request hash مطابقة، أعد النتيجة المخزنة أو حالة `processing`؛ لا تنفذ الأثر مرة ثانية. إذا اختلفت قيمة hash، أعد `409 Idempotency-Key-Reuse` ولا تغير السجل الموجود.

لا تحذف المفتاح عند timeout من العميل؛ قد تكون العملية نفذت في الخادم. اجعل الانتقال من `processing` إلى `completed` ذرياً، واستخدم fencing token أو Lua/CAS عند الحاجة. لا تستخدم `KEYS` أو `MONITOR` في الإنتاج، وراقب evictions وmemory وTTL وrejected connections.

## منع Replay Attacks

اربط المفتاح بهوية verified tenant/user، والـroute، وrequest hash، ونافذة زمنية، ولا تسمح بنقله بين مستخدمين أو endpoints. اجعل المفاتيح عشوائية عالية entropy من العميل، لكن لا تعتمد على عشوائيتها وحدها؛ الحماية الحقيقية هي claim ذري، تحقق timestamp/signature، request hash، TTL، وسجل أثر مالي فريد.

للدفع، اجعل uniqueness في قاعدة البيانات أيضاً مثل `(merchant_id, idempotency_key_hash)`، لأن Redis وحده ليس مصدراً نهائياً للحقيقة. اكتب ledger وpayment record داخل transaction، ثم أرسل webhook أو event بعد commit. نفذ reconciliation دورياً بين سجل idempotency والآثار المالية.

## اختبار الأمان

اختبر توقيعاً صحيحاً، timestamp منتهياً، signature خاطئاً، body معدلاً، `Webhook-Id` مكرراً، نفس key مع body مختلف، retries المتزامنة، Redis restart، TTL expiry، وeviction. يجب ألا ينتج عن replay أثر مالي ثانٍ، ويجب ألا تكشف التقارير أو Slack أي secret أو body خام.
