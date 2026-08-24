# CI/CD gate لاختبار KEDA في Staging

## الترتيب

يعمل Workflow `staging-keda-load.yml` بعد اكتمال Workflow اسمه `Deploy Staging` بنجاح، كما يمكن تشغيله يدوياً عبر `workflow_dispatch`. يجب أن يكون النشر قد اكتمل قبل بدء الحمل؛ لذلك يتحقق Job من rollout الخاص بـ`security-webhook-worker` ومن وجود ScaledObject وHPA.

## GitHub Environment

أنشئ Environment باسم `staging` وأضف قواعد حماية ومراجعة يدوية عند الحاجة. أضف الأسرار التالية إلى Environment وليس إلى مستودع عام:

| Secret | الغرض |
|---|---|
| `STAGING_KUBECONFIG_B64` | kubeconfig محدود الصلاحيات لـnamespace Staging فقط |
| `STAGING_TARGET_URL` | عنوان HTTPS الخاص بـWebhook staging |
| `STAGING_REDIS_URL` | اتصال `rediss://` بقاعدة Redis staging |
| `STAGING_TEST_WEBHOOK_SECRET` | مفتاح HMAC للاختبار فقط |

يجب أن يملك kubeconfig صلاحيات قراءة Deployment/HPA/ScaledObject/Events/Logs في namespace المحدد، وصلاحيات أقل ما يمكن. لا تستخدم kubeconfig عنقود الإنتاج أو مفاتيح PagerDuty/Slack الحقيقية.

## مثال التشغيل اليدوي

```bash
gh workflow run staging-keda-load.yml \
  --ref main \
  -f rps=100 \
  -f duration=2m
```

يُفضّل البدء بـSmoke Test منخفض، ثم Baseline، ثم حمل مضبوط. لا تجعل RPS غير محدوداً؛ المشغّل يرفض القيم خارج 1–2000، ويفرض HTTPS و`rediss://` ووجود كلمة `staging` في العنوان.

## بوابة القبول

يفشل Job إذا لم يرتفع عدد replicas فوق baseline خلال `scale-up-timeout`، أو إذا فشل k6، أو إذا لم يفرغ backlog ولم يعد HPA إلى min replicas خلال `scale-down-timeout`. تُحفظ ملاحظات Kubernetes وRedis وk6 كـartifacts، وتُجمع `describe` وevents وworker logs عند الفشل.

لا تعتمد على عدد replicas وحده. قارنه مع `security_webhook_queue_depth` و`security_webhook_oldest_pending_age_seconds` وprocessing throughput و`circuit_breaker_state` وDLQ rate في Dashboard Grafana. إذا ارتفع عدد Workers مع استمرار backlog أو DLQ، أوقف الاختبار وراجع downstream أو Circuit Breaker.

## ملاحظة عن workflow_run

إذا كان اسم Workflow النشر الفعلي مختلفاً عن `Deploy Staging`، عدّل قائمة `workflow_run.workflows` إلى الاسم الدقيق. عند استخدام `workflow_run` مع أسرار وبيئة محمية، راجع صلاحيات الحدث وقيود الفروع قبل التفعيل. لا تسمح بتشغيل حمولة من fork غير موثوق بها باستخدام أسرار Staging.

## References

[1] [GitHub Actions workflow syntax](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
[2] [GitHub Actions environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
[3] [KEDA Redis Streams scaler](https://keda.sh/docs/2.20/scalers/redis-streams/)
