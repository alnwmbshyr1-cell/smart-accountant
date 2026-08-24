# اختبارات Alertmanager التكاملية محلياً

## الهدف

تحقق من السلسلة الكاملة قبل استخدام مستقبل حقيقي:

```text
Synthetic metric → Prometheus rule → Alertmanager routing → Mock Webhook/PagerDuty
```

تستخدم التجربة Compose محلياً ولا تتصل بـPagerDuty أو Slack أو Webhook إنتاجي.

## التشغيل

```bash
docker compose \
  -f backend/ops/observability/docker-compose.alertmanager-integration.yml \
  up -d

python3 tooling/integration_test_alertmanager.py \
  --receiver http://127.0.0.1:18080 \
  --prometheus http://127.0.0.1:9090 \
  --wait-seconds 30 \
  --output artifacts/alertmanager-integration.json

docker compose \
  -f backend/ops/observability/docker-compose.alertmanager-integration.yml \
  down -v
```

يبدأ الـharness بقيمة RSS اصطناعية أعلى من threshold، فينتظر وصول `firing`، ثم يخفض القيمة وينتظر `resolved`. يكتب الأدلة في JSON، بينما يسجل Mock receiver channel وstatus وalert names وbody hash فقط.

## الاختبارات

| المسار | التحقق |
|---|---|
| Prometheus scrape | القيمة الاصطناعية ظاهرة في Prometheus |
| Rule evaluation | تنتقل القاعدة من inactive إلى pending ثم firing بعد `for` |
| Critical routing | يصل التنبيه إلى PagerDuty-shaped receiver وWebhook receiver |
| Resolved | يصل resolved إلى القناتين عند عودة metric إلى الطبيعي |
| Grouping | لا تتكرر الأحداث أكثر من سياسة التجميع |
| Inhibition | تُختبر القاعدة الحرجة مع warning المطابق |
| Isolation | لا توجد production URLs أو secrets أو routing keys |

## تحسين الاختبار

اختبر rule evaluation منفرداً باستخدام `promtool test rules` ببيانات زمنية ثابتة، ثم استخدم Compose لاختبار routing الفعلي. اختبر timeout أو توقف Mock receiver، وتحقق من أن Alertmanager يعيد المحاولة دون أن يحجب مسارات أخرى. اختبر body معدلاً على بوابة HMAC الحقيقية منفصلة عن Alertmanager، لأن Alertmanager webhook القياسي لا يوقع payload تلقائياً.

## CI

شغّل الاختبارات الثابتة في كل Pull Request. شغّل Compose integration job في runner مع Docker عند تغييرات Prometheus أو Alertmanager. ارفع logs وJSON artifacts عند الفشل، واستخدم retention قصيراً. لا تستخدم secrets الإنتاج، ولا تفعّل job تلقائياً على بيئة الإنتاج؛ اجعلها محلية أو على GitHub Environment اختبارية.

## References

[1] [Prometheus alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
[2] [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
[3] [Alertmanager API](https://prometheus.io/docs/alerting/latest/management_api/)
