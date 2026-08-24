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

يعمل Workflow `.github/workflows/alertmanager-integration-pr.yml` تلقائياً مع كل Pull Request يغيّر ملفات Prometheus أو Alertmanager أو Compose أو Synthetic tooling. يبدأ Job على runner مع Docker، يشغل الاختبارات الثابتة، يرفع Compose محلياً، ينتظر readiness، ثم ينفذ `integration_test_alertmanager.py` للتحقق من firing وresolved وrouting.

استخدم `timeout-minutes` وconcurrency cancellation لمنع تراكم Jobs قديمة، و`if: always()` لرفع JSON evidence، و`if: failure()` لجمع logs و`docker compose ps`. يجب أن ينفذ cleanup عبر `down -v --remove-orphans` حتى عند الفشل. اجعل صلاحية workflow `contents: read` فقط، ولا تضف secrets أو kubeconfig أو PagerDuty routing keys.

يمكن جعل check المطلوب في Branch Protection بعد التأكد من ثبات اسم Job. احتفظ باختبار Staging أو الاختبار الذي يرسل إلى PagerDuty الحقيقي في Workflow منفصل مع GitHub Environment محمي وموافقة يدوية. لا تخلط synthetic local gate مع chaos أو production notification tests.

شغّل الاختبارات الثابتة في كل Pull Request، وارفع logs وJSON artifacts عند الفشل مع retention قصير. لا تستخدم secrets الإنتاج، ولا تفعّل Job تلقائياً على بيئة الإنتاج؛ اجعلها محلية أو على GitHub Environment اختبارية.

## References

[1] [Prometheus alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
[2] [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
[3] [Alertmanager API](https://prometheus.io/docs/alerting/latest/management_api/)
