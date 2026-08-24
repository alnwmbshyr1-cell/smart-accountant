# Local Prometheus, Alertmanager, and Slack Alert Lab

يستخدم هذا المختبر Docker Compose ومقاييس اصطناعية ومستقبلاً محلياً يحاكي Slack. لا تستخدم Webhook Slack حقيقياً، ولا تضع الأسرار في ملفات المختبر. الغرض هو التحقق من Prometheus rule evaluation، تجميع Alertmanager، حالتي firing/resolved، redaction، وغياب التكرار غير المقصود.

## التشغيل

```bash
cd smart-accountant
mkdir -p backend/ops/alert-lab/received
docker compose -f backend/ops/alert-lab/docker-compose.yml up -d
```

تحقق من الخدمات:

```bash
curl -fsS http://127.0.0.1:9090/-/ready
curl -fsS http://127.0.0.1:9093/-/ready
curl -fsS http://127.0.0.1:8080/healthz
```

## اختبار firing

ابدأ المقاييس تحت threshold، ثم أعد تشغيل مصدر المقاييس بوضع التنبيه:

```bash
docker compose -f backend/ops/alert-lab/docker-compose.yml stop metrics
docker compose -f backend/ops/alert-lab/docker-compose.yml run -d --name sa-alert-lab-metrics \
  -e ALERT_LAB_HIGH=1 -e TEST_ID=local-p95-001 metrics
```

افتح `http://127.0.0.1:9090/alerts` وتحقق من `LabK6P95LatencyHigh`. افتح `http://127.0.0.1:9093` وتحقق من وصول التنبيه إلى Alertmanager. تحقق من الملف:

```bash
tail -n 5 backend/ops/alert-lab/received/events.jsonl
```

يجب أن تكون الحالة `firing` وأن يكون `testid` هو `local-p95-001` دون token أو body خام.

## اختبار resolved

أوقف مصدر المقاييس المرتفع وأعد المصدر الطبيعي:

```bash
docker rm -f sa-alert-lab-metrics
docker compose -f backend/ops/alert-lab/docker-compose.yml start metrics
```

انتظر أكثر من نافذة `for` ثم تحقق من `/alerts` ومن وصول حدث `resolved` إلى المستقبل المحلي. لا تعتبر recovery ناجحاً إذا لم تصل حالة resolved أو إذا استمر التنبيه بعد عودة المقاييس إلى baseline.

## فحص PromQL يدوياً

```bash
curl -G -s http://127.0.0.1:9090/api/v1/query \
  --data-urlencode 'query=histogram_quantile(0.95,sum by (testid,le)(rate(k6_http_req_duration_seconds_bucket{testid!=""}[30s])))'
```

## التنظيف

```bash
docker compose -f backend/ops/alert-lab/docker-compose.yml down -v
rm -rf backend/ops/alert-lab/received/*.jsonl
```

إذا فشل Prometheus في تحميل القواعد، افحص `docker compose logs prometheus`. وإذا لم يصل Slack mock، افحص `docker compose logs alertmanager receiver`. لا تستخدم `--force-recreate` على بيئة staging أو الإنتاج من هذا الدليل.
