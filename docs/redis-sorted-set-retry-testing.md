# Redis Sorted Set delayed retry and Worker testing

## Delayed retry

لا تستخدم `asyncio.sleep()` داخل مسار معالجة الرسالة. عند فشل transient، احسب `due_at = now + backoff + jitter`، خزّن نسخة الرسالة في Sorted Set باسم `security:webhook:retry-at` والـscore هو Unix timestamp، ثم نفّذ `XACK` للرسالة الحالية. يبقى العامل متاحاً لمعالجة رسائل أخرى.

يعمل Scheduler قصير الدورة قبل `XREADGROUP` على تنفيذ Lua script واحد: يقرأ أعضاء `ZRANGEBYSCORE retry_zset -inf now LIMIT 0 batch_size`، يحذف كل عضو بـ`ZREM` بشرط نجاح الحذف، ثم يعيد إدخاله إلى Stream. تنفيذ النقل في Lua يمنع عاملين من ترقية نفس العضو. لا تعتمد على `ZRANGE` ثم `ZREM` في طلبين منفصلين دون claim ذري.

ضع `attempts` داخل الرسالة، واحفظ `next_attempt_at` وسبب الخطأ وhash الرسالة. بعد `MAX_ATTEMPTS` انقل الرسالة إلى DLQ ثم أكد الأصل. استخدم jitter لتقليل thundering herd، وحداً أقصى للـbackoff، ومراقبة `queue_depth` و`oldest_pending_age` و`retry_total` و`dead_letter_total`.

## اختبار Pytest وFakeRedis

قسّم الاختبارات إلى ثلاث طبقات. اختبارات الوحدة تختبر دوال pure مثل حساب backoff، بناء hash، والتحقق من HMAC مع الوقت الحالي والقديم والتوقيع المعدل. اختبارات Redis contract تستخدم `fakeredis.aioredis.FakeRedis` وتتحقق من `ZADD`، وعدم ترقية الرسائل غير المستحقة، وترقية الرسائل المستحقة، وإزالة العضو بعد الترقية، وحفظ `attempts`. اختبارات التكامل تشغل FastAPI عبر `httpx.AsyncClient` أو TestClient، وتستبدل Redis وNotifier بـfakes، ثم تتحقق من HTTP 202/401/409، والكتابة إلى Stream، والـack بعد النجاح، وإعادة الجدولة بعد 5xx، والنقل إلى DLQ بعد استنفاد الحد.

اختبر التنافس بإطلاق عدة coroutines على نفس Sorted Set وتحقق من أن كل member ينتقل إلى Stream مرة واحدة. اختبر crash قبل `XACK` ثم استخدم pending recovery أو `XAUTOCLAIM` في طبقة الاسترداد. اختبر Redis unavailable، وNotifier timeout، و429 مع `Retry-After`، و400 كفشل دائم، وbody مختلفاً مع نفس `event_id`. يجب أن تكون الاختبارات حتمية باستخدام clock وrandom seed قابلين للحقن، وألا تتصل بخدمة Slack أو Redis إنتاجية.

الأمر المقترح:

```bash
pytest -q tooling/test_security_webhook_worker.py \
  tooling/test_continuous_alert_webhook.py \
  tooling/test_continuous_monitoring_policy.py
```

الاختبار الذي يعتمد على `fakeredis` يُتخطى تلقائياً إذا لم تكن الإضافة مثبتة؛ في CI يجب تثبيت `pytest`, `pytest-asyncio`, `redis`, `fakeredis`, و`prometheus-client` ثم جعل غياب FakeRedis فشلاً في job الاختبارات بدلاً من skip صامت.

## مراجع

[1] [Redis Sorted Sets](https://redis.io/docs/latest/develop/data-types/sorted-sets/)
[2] [Redis queues and delayed tasks](https://redis.io/glossary/redis-queue/)
