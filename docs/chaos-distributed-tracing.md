# Distributed tracing أثناء Redis Chaos

## البنية

أضف OpenTelemetry SDK إلى FastAPI وWorkers، واربط التطبيق بـOTLP/HTTP أو OTLP/gRPC. يمكن استخدام Jaeger محلياً للفحص، بينما يُفضّل OpenTelemetry Collector في Staging لتجميع traces وتطبيق batch وtail sampling. استخدم `backend/ops/otel_tracing.py` كنقطة إعداد مشتركة.

```bash
export OTEL_SERVICE_NAME=smart-accountant-webhook
export DEPLOYMENT_ENVIRONMENT=staging
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318

docker compose -f backend/ops/observability/docker-compose.jaeger.yml up -d
```

يظهر Jaeger UI محلياً على `http://localhost:16686`، ويستقبل OTLP/HTTP على المنفذ 4318. لا تجعل هذه المنافذ عامة.

## التتبع المطلوب

| Span | Attributes المسموحة |
|---|---|
| `HTTP POST /alertmanager` | route، status، duration، environment |
| `redis.xreadgroup` | operation، stream name المنقح، consumer group |
| `redis.xack` و`redis.xadd` | operation، destination name، outcome |
| `worker.delivery` | outcome، retry count، hashed event ID، experiment ID محدود |
| `notifier.send` | channel allowlisted، status، error type |
| `chaos.redis.outage` | experiment ID، fault duration، namespace staging |

لا تسجل body الخام، HMAC، Redis URL، كلمات المرور، event ID الكامل، بيانات المستخدم أو نص الاستثناء غير المنقح. استخدم sampler مناسباً حتى لا يتحول tracing نفسه إلى مصدر ضغط.

## ربط تجربة Chaos

شغّل `staging_redis_chaos.py` من Workflow محمي، ومرر `CHAOS_EXPERIMENT_ID` إلى Load Test. يرسل k6 المعرف في header `X-Chaos-Experiment-Id`، ويجب على FastAPI قبول header من قائمة staging فقط وتحويله إلى attribute محدود. إذا كان المصدر لا يثق به، لا تستخدمه كهوية أمنية؛ هو للارتباط التشخيصي فقط.

أثناء انقطاع Redis، ابحث في Jaeger عن traces التي تحتوي على timeout أو connection error، ثم تحقق من أن Circuit Breaker فتح أو فشل مغلقاً، وأن retry بقي ضمن الحد، وأن Worker عاد بعد restore. اربط trace timestamps مع Grafana metrics وملف JSONL الناتج من Chaos runner.

## معايير القبول

تنجح التجربة إذا ظهرت traces فشل واضحة أثناء fault window، ولم تتضمن أسراراً، ولم يحجب exporter حركة التطبيق، ولم يحدث retry storm، وعاد Redis وWorkers، وتوقفت زيادة backlog ثم بدأ drain، ولم يحدث duplicate delivery أو DLQ growth غير متوقع.

اختبر exporter outage منفصلاً بإيقاف Jaeger/Collector؛ يجب أن تستمر الطلبات مع فقد traces أو sampling degradation فقط. استخدم in-memory exporter في Unit Tests، وJaeger/Collector حقيقياً في Integration/Staging.

## References

[1] [OpenTelemetry Python](https://opentelemetry.io/docs/languages/python/)
[2] [OpenTelemetry FastAPI instrumentation](https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/fastapi/fastapi.html)
[3] [Jaeger OpenTelemetry](https://www.jaegertracing.io/docs/2.0/architecture/)
