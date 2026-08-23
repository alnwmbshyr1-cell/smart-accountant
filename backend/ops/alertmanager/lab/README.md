# Local Alertmanager delivery lab

هذا المختبر يشغل Prometheus وAlertmanager وmetrics fixture وWebhook receiver محلياً. لا يتصل بـSupabase أو Gemini أو Slack افتراضياً، ولا يستخدم بيانات Smart Accountant الحقيقية.

## التشغيل

من مجلد `backend/ops/alertmanager`:

```bash
chmod +x lab/run_lab.sh
./lab/run_lab.sh
```

يفتح المختبر:

| الخدمة | العنوان |
|---|---|
| Prometheus | http://localhost:19090 |
| Alertmanager | http://localhost:19093 |
| Webhook receiver | http://localhost:18080/alertmanager |

تبدأ fixture بنسبة 10% أخطاء 5xx، بينما قاعدة المختبر تستخدم threshold قدره 5% و`for: 45s`. انتظر تقريباً دقيقة، ثم افحص:

```bash
curl -s http://localhost:19090/api/v1/alerts
curl -s http://localhost:19093/api/v2/alerts
ls -lt lab/received
cat lab/received/*.json
```

لتمثيل التعافي، خفّض النسبة إلى 1%:

```bash
printf '0.01\n' > lab/state/error_ratio
```

بعد مرور نافذة rate البالغة دقيقة، يجب أن يظهر resolved payload في `lab/received`. لا تستخدم `docker compose down -v` إذا أردت الاحتفاظ بالملفات المستلمة للفحص؛ استخدم:

```bash
docker compose down
```

## Slack الحقيقي بشكل اختياري

الافتراضي هو Webhook محلي آمن. لاختبار Slack حقيقي، أنشئ secret file خارج Git:

```bash
mkdir -p lab/secrets
umask 077
printf '%s\n' 'https://hooks.slack.com/services/REDACTED' > lab/secrets/slack_webhook_url
```

لا تستخدم القيمة أعلاه حرفياً. استخدم Slack Incoming Webhook حقيقياً من مساحة اختبار منفصلة. أنشئ override خاصاً خارج Git يوجه route إلى `optional-slack`، ثم شغل:

```bash
docker compose -f docker-compose.yml -f lab/docker-compose.slack.override.yml up -d
```

احذف secret file بعد الاختبار، وراجع قناة Slack للتأكد من firing ثم resolved. لا تجعل هذا المختبر يستهدف قناة إنتاجية.

## فحص الإعدادات

```bash
amtool check-config /etc/alertmanager/alertmanager.yml
promtool check config /etc/prometheus/prometheus.local.yml
promtool check rules /etc/prometheus/tests/local-5xx-alerts.yml
```

داخل Compose يمكن تنفيذها عبر:

```bash
docker run --rm -v "$PWD:/work:ro" -w /work --entrypoint /bin/amtool prom/alertmanager:v0.28.1 check-config ops/alertmanager/lab/alertmanager.local.yml
docker run --rm -v "$PWD:/work:ro" -w /work --entrypoint /bin/promtool prom/prometheus:v3.5.0 check rules ops/alertmanager/lab/local-5xx-alerts.yml
```

المستقبل المحلي يحفظ نسخة منقحة من payload: status وlabels وannotations فقط. لا ترسل النص المحاسبي أو Authorization أو أي مفتاح إلى هذه الخدمة.

## تنظيف

```bash
docker compose -f docker-compose.yml down
rm -rf lab/prometheus-data lab/alertmanager-data lab/received/*.json
```
