# اختبار إشعارات Slack التكاملية عبر act

استخدم هذا المسار للتحقق من payloads التي يرسلها Alertmanager إلى مستقبل Slack محلي، دون استخدام Slack Webhook حقيقي أو GitHub API حقيقي.

## التشغيل المحلي

شغّل مستقبل المختبر في طرفية:

```bash
mkdir -p /tmp/sa-alert-lab
ALERT_LAB_EVENTS_PATH=/tmp/sa-alert-lab/events.jsonl \
python3 backend/ops/alert-lab/webhook_receiver.py
```

ثم شغّل محاكاة `workflow_run` في طرفية ثانية:

```bash
tooling/act_workflow_run_preflight.sh \
  workflow_run-quality-failed.json
```

عند اختبار Alertmanager فعلياً عبر Compose، اجعل receiver المحلي هو webhook URL الداخلي، ثم أرسل حالة firing وحالة resolved من مصدر المقاييس الاصطناعي. بعد وصول الرسائل، تحقق منها:

```bash
python3 tooling/validate_slack_alert_events.py \
  /tmp/sa-alert-lab/events.jsonl act-1
```

## عقد التحقق

| الفحص | الشرط |
|---|---|
| firing/resolved | وصول الحالتين لنفس Alertmanager group/fingerprint |
| testid | وجود معرف التشغيل المتوقع في payload |
| deduplication | لا يوجد أكثر من حدث لنفس `(status, fingerprint)` |
| redaction | لا توجد Bearer أو token أو api_key أو secret أو password أو webhook |
| no-write | `ACT_LOCAL=true` يمنع طلب reviewer وإضافة label أو comment |

يجب إبقاء `groupKey` أو fingerprint ثابتاً بين firing وresolved، مع اختلاف status فقط. إذا وصلت رسائل متكررة لنفس الحالة، فراجع `group_wait` و`group_interval` و`repeat_interval` في Alertmanager، ولا تخفِ المشكلة بحذف السجلات.

## CI

شغّل الاختبارات التكاملية مع اختبارات fixtures:

```bash
python3 -m unittest \
  tooling/test_slack_notification_integration.py \
  tooling/test_act_workflow_run_preflight.py
```

داخل GitHub Actions، شغّل Alertmanager وreceiver في network معزولة، واستخدم payloads اصطناعية. ارفع `events.jsonl` عند الفشل فقط، بعد تطبيق redaction. لا تمرر Slack webhook أو GitHub token إلى `act`، ولا تستخدم `pull_request_target`.

هذا الاختبار يثبت صحة payload والمعالجة المحلية وdeduplication/redaction. لا يثبت وصول الرسالة إلى Slack SaaS أو صلاحيات GitHub الحقيقية؛ نفّذ اختباراً منفصلاً في staging عند الحاجة وبـWebhook قصير العمر وقابل للإلغاء.
