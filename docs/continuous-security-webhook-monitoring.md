# Continuous security webhook monitoring

Use Alertmanager for immediate security notifications and keep the daily report as a separate aggregation channel. Route alerts with `category="security"` to `smart-accountant-security-webhook`; keep `send_resolved: true` so recovery is visible.

The receiver must be HTTPS in staging/production and expose a secret-file URL in Alertmanager:

```text
/etc/alertmanager/secrets/security_webhook_url
```

The receiving gateway must verify the raw body with HMAC-SHA256 over `timestamp + "." + raw_body`, reject timestamps outside the configured skew window, enforce a body-size limit, validate the Alertmanager schema, and claim `X-Webhook-Id` atomically in Redis with a bounded TTL. Store a request hash with the claim and reject the same ID with a different body. Return 2xx only after durable acceptance; use a dead-letter queue for repeated delivery failures rather than infinite retries.

A minimal local receiver is provided at `backend/ops/continuous_alert_webhook.py`. It is a test harness, not a complete production gateway: set `REDIS_URL` to enable atomic Redis replay claims, but add production schema validation, metrics, durable queueing, and authenticated HTTPS termination before deployment. Without `REDIS_URL`, its in-memory replay set is process-local and is suitable only for isolated tests.

Run the local integration tests:

```bash
python3 -m unittest tooling/test_continuous_alert_webhook.py
```

For local testing, use a secret supplied through the environment and a temporary events file:

```bash
CONTINUOUS_WEBHOOK_SECRET=local-only-secret \\
CONTINUOUS_EVENTS_PATH=/tmp/continuous-events.jsonl \\
WEBHOOK_PORT=8090 \\
python3 backend/ops/continuous_alert_webhook.py
```

Never point the test harness at Slack, a production Alertmanager, a production database, or a real payment endpoint. The daily report remains responsible for 24-hour aggregation, while the continuous webhook is responsible for low-latency firing and resolved notifications.

## تصميم Dead-Letter Queue الإنتاجي

افصل **قبول Webhook** عن **التسليم إلى الوجهة النهائية**. بعد نجاح HMAC والتحقق من freshness وclaim ذري لمفتاح الحدث، يكتب المستقبل الرسالة إلى Redis Stream مثل `security:webhook:events` ثم يعيد `202 Accepted`. يقرأ Worker الرسائل عبر Consumer Group، ويؤكدها فقط بعد نجاح التسليم إلى Slack أو البريد أو نظام التذاكر. تدعم Redis Streams Consumer Groups وقائمة الرسائل المعلقة لهذا النمط [3].

احفظ لكل رسالة `event_id` و`payload_hash` و`attempts` و`first_seen_at` و`last_error_code` و`next_attempt_at` و`trace_id`. عند الفشل استخدم exponential backoff مع jitter، مثل 5 ثوانٍ ثم 30 ثانية ثم دقيقتين، وبحد أقصى 5 محاولات، مع احترام `Retry-After` إن أعادته الوجهة. بعد استنفاد الحد، انقل الرسالة إلى Stream مستقل مثل `security:webhook:dead-letter` مع سبب الفشل، ثم أكد الرسالة الأصلية حتى لا تبقى عالقة بلا نهاية. هذا يتوافق مع نمط Redis الموثق للطوابير الموثوقة وإعادة المحاولة وDLQ [4].

لا تُعد تشغيل DLQ بلا حدود. اجعل Replay عملية مصرحاً بها، تفحص سبب الفشل وتحافظ على `event_id` نفسه وتمنع إنشاء أثر مكرر. لا تحذف الرسالة من DLQ إلا بعد نجاح replay أو قرار احتفاظ/إتلاف موثق.

## مقاييس التسليم التفصيلية

استخدم labels منخفضة cardinality مثل `channel` و`status_class` و`reason`، ولا تضع `event_id` أو نص التنبيه الخام في labels:

| المقياس | النوع | الغرض |
|---|---|---|
| `security_webhook_received_total` | Counter | الطلبات المستلمة |
| `security_webhook_accepted_total` | Counter | الطلبات المقبولة بعد التحقق |
| `security_webhook_rejected_total{reason}` | Counter | رفض التوقيع أو timestamp أو schema أو الحجم |
| `security_webhook_duplicate_total` | Counter | عمليات replay المطابقة |
| `security_webhook_idempotency_conflict_total` | Counter | نفس المعرّف مع body مختلف |
| `security_webhook_queue_depth` | Gauge | الرسائل غير المؤكدة |
| `security_webhook_delivery_attempts_total{channel}` | Counter | محاولات التسليم |
| `security_webhook_delivery_success_total{channel}` | Counter | التسليم الناجح |
| `security_webhook_delivery_failure_total{channel,reason}` | Counter | الفشل المصنف |
| `security_webhook_delivery_latency_seconds{channel}` | Histogram | p50 وp95 وp99 للتسليم |
| `security_webhook_retry_total{channel}` | Counter | إعادة المحاولة |
| `security_webhook_dead_letter_total{reason}` | Counter | النقل إلى DLQ |
| `security_webhook_oldest_pending_age_seconds` | Gauge | عمر أقدم رسالة معلقة |

أنشئ تنبيهات عند تجاوز عمق الطابور 100 لمدة 5 دقائق، أو استمرار فشل التسليم، أو ارتفاع p95 فوق ثانيتين، أو وصول عمر أقدم رسالة إلى 300 ثانية، أو حدوث أي `idempotency_conflict`. وجّه تنبيه DLQ إلى قناة الأمن.

## حدود التنفيذ الحالي

التغيير الحالي يفعّل المسار الفوري والتحقق الأمني وRedis replay claim عند ضبط `REDIS_URL`. أما Redis Stream Worker وDLQ الفعلي وPrometheus metrics endpoint وعمليات replay المصرح بها، فتحتاج دمجاً في خدمة Backend الإنتاجية الحالية؛ مستقبل الاختبار المحلي ليس بديلاً عنها.

[3] [Redis Streams and consumer groups](https://redis.io/docs/latest/develop/data-types/streams/)
[4] [Redis-backed reliable job queue with retries and dead-letter stream](https://redis.io/tutorials/redis-backed-job-queue-for-background-workers/)
