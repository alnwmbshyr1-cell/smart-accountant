# قواعد التنبيه المتقدمة لـOpenTelemetry Collector

## الملفات

أضف `backend/ops/prometheus/collector-alerts.yml` إلى rule files في Prometheus، وأضف مسار `category="observability"` إلى Alertmanager. القواعد الحالية تغطي ضغط الذاكرة، امتلاء طوابير exporters، رفض spans، فشل التصدير، غياب scrape، وارتفاع إسقاط Tail Sampling.

## نموذج الشدة

| الشدة | أمثلة | التوجيه |
|---|---|---|
| critical | MemoryCritical، QueueSaturation، ScrapeMissing | PagerDuty فوراً وWebhook resolved |
| high | RefusedSpans، ExporterFailures | observability Webhook أو Slack بعد تجميع قصير |
| warning | MemoryPressure، TailSamplingDropSpike | Slack/لوحة Grafana دون paging مباشر |

لا تستخدم labels ذات cardinality عالية. يجب أن تكون labels ثابتة مثل `severity` و`category` و`component`، مع أبعاد بنية تحتية محدودة عند الحاجة. أبقِ trace IDs وevent IDs والـURLs والـpayloads خارج labels.

## التحقق

```bash
promtool check rules backend/ops/prometheus/collector-alerts.yml
amtool check-config backend/ops/alertmanager/alertmanager.yml
pytest -q tooling/test_advanced_collector_alerts.py
```

استخدم نسخة Prometheus/Alertmanager المطابقة للإنتاج؛ قد تختلف أسماء مقاييس Collector بين التوزيعات والإصدارات. اختبر القواعد عبر `promtool test rules` ببيانات اصطناعية، ثم نفّذ اختبار delivery على Webhook وPagerDuty test service في Staging فقط.

## Alertmanager routing

المسار الحرج يستخدم `group_wait: 0s` لإرسال Circuit/Collector incidents بسرعة، مع `group_interval` و`repeat_interval` لمنع العاصفة. استخدم secret files مثل `routing_key_file` و`url_file`، ولا تضع قيمة السر داخل YAML أو logs. `send_resolved: true` ضرورية لإغلاق incident في PagerDuty وتحديث Webhook.

استخدم inhibition لتقليل الضجيج: عند وجود `OTelCollectorMemoryCritical` لنفس `service_instance_id` و`component`، يمكن إسكات `OTelCollectorMemoryPressure`. لا تكتم `ScrapeMissing` أو exporter failures بشكل واسع، فقد تكون هي الدليل الوحيد على توقف طبقة المراقبة.

## حدود التنبيه

قيمة `644245094` تعادل تقريباً 85% من حد 768 MiB، وقيمة `725937562` تعادل تقريباً 95% منه، وهي متوافقة مع إعداد Collector الحالي فقط. أعد حسابها إذا تغيرت موارد Pod أو `memory_limiter.limit_mib`. عتبة queue utilization 90% تحتاج معايرة من baseline الحقيقي، ولا تعني وحدها أن البيانات فُقدت.

## References

[1] [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
[2] [Prometheus alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
[3] [OpenTelemetry Collector internal telemetry](https://opentelemetry.io/docs/collector/internal-telemetry/)
