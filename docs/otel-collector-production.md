# OpenTelemetry Collector في الإنتاج

## الهدف

يقلل هذا الإعداد حجم traces ويحافظ على traces ذات القيمة العالية أثناء الضغط. يحتفظ بكل الأخطاء، والطلبات الأبطأ من SLO، وحالات Circuit Open، وتجارب Chaos المعتمدة، بينما يأخذ عينة 5% من baseline الطبيعي.

## ترتيب المعالجة

| المرحلة | الوظيفة |
|---|---|
| `memory_limiter` | منع تجاوز الذاكرة وإيقاف استقبال البيانات مؤقتاً عند الضغط |
| `resource/normalize` | توحيد `service.version` وبيئة النشر |
| `filter/drop-sensitive` | إسقاط spans التي تحمل حقولاً ممنوعة |
| `transform/redact` | حذف أو إخفاء authorization وcookies وconnection strings وأسرار query |
| `tail_sampling` | اتخاذ قرار sampling بعد اكتمال trace أو انتهاء الانتظار |
| `batch` | تجميع الإرسال وتقليل تكلفة الشبكة |

يجب ضبط `decision_wait` و`num_traces` و`expected_new_traces_per_sec` من معدل حقيقي. زيادة `num_traces` ترفع الذاكرة المطلوبة لأن Tail Sampling يحتفظ بالـspans حتى القرار [1].

## إعداد مبدئي

الملف المرجعي هو `backend/ops/observability/otel-collector-production.yml`. يحتوي على `decision_wait: 10s` و`num_traces: 50000` و`expected_new_traces_per_sec: 2000` وذاكرة soft limit مقدارها 768 MiB مع spike limit مقدارها 192 MiB. هذه ليست قيماً عالمية؛ اختبرها في Staging ثم اضبطها وفق حجم trace وعدد replicas.

## النشر

شغّل Collector كـDeployment متعدد replicas، واستخدم load-balancing أو gateway يضمن وصول spans الخاصة بالـtrace نفسه إلى نفس tail-sampling instance. اربط exporters عبر TLS والمصادقة، واجعل OTLP receiver خاصاً بشبكة الخدمة. لا تستخدم debug exporter في الإنتاج.

## سياسات الأمان

فلتر الأسرار قبل sampling وقبل التصدير. لا تسجل body أو Authorization أو Cookie أو password أو token أو Redis connection string أو بيانات المستخدم. لا تستخدم هذه القيم في policy attributes أو labels. اختبر redaction باستخدام أسرار اصطناعية فقط.

## مؤشرات المراقبة

راقب ذاكرة Collector، refused spans، queue size، exporter failures، traces sampled، traces dropped، وlatency. عند الضغط، خفّض baseline sampling أولاً، ولا تتنازل عن error وsecurity وChaos traces. اختبر توقف exporter للتأكد من أن فشل telemetry لا يوقف FastAPI أو Workers.

## التحقق

```bash
python3 -m yaml backend/ops/observability/otel-collector-production.yml
pytest -q tooling/test_otel_collector_config.py
```

استخدم أيضاً أمر التحقق الخاص بتوزيعة Collector التي تعتمدها؛ فبعض التوزيعات تضيف exporters أو processors مختلفة. لا تطبق الإعداد على الإنتاج قبل اختبار استهلاك الذاكرة وعدد traces الفعلي.

## References

[1] [OpenTelemetry Tail Sampling](https://opentelemetry.io/blog/2022/tail-sampling/)
[2] [OpenTelemetry Collector processors](https://opentelemetry.io/docs/collector/components/processor/)
[3] [OpenTelemetry handling sensitive data](https://opentelemetry.io/docs/security/handling-sensitive-data/)
[4] [OpenTelemetry Collector scaling](https://opentelemetry.io/docs/collector/scaling/)
