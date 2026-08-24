# مراقبة Required Status Checks وإشعارات Slack

## الهدف

يستقبل `backend/ops/github_required_checks_webhook.py` أحداث `check_run` و`workflow_run` من GitHub، ويتحقق من توقيع HMAC قبل تحليل الحمولة، ثم يرشح الفحوصات الإلزامية المكتملة التي انتهت بـ `failure` أو `timed_out` أو `action_required` أو `cancelled`. عند وجود فشل على `main` أو Pull Request يستهدف `main`، يرسل إشعاراً محدود البيانات إلى Slack.

> لا يُستخدم Slack كبديل عن Branch Protection. المنع الفعلي للدمج يبقى من خلال Required Status Checks في إعدادات GitHub؛ Slack قناة تنبيه تشغيلية فقط.

## إعداد GitHub Webhook

من إعدادات المستودع اختر `Settings → Webhooks → Add webhook`. استخدم `Content type: application/json`، أنشئ secret عشوائياً عالي الإنتروبيا، واجعل Payload URL يشير إلى `https://HOST/github` خلف HTTPS وreverse proxy أو بوابة شبكة موثوقة. فعّل الحدثين `Check runs` و`Workflow runs`، ثم فعّل **Active**.

يجب ألا يكون المستقبل مكشوفاً دون TLS أو rate limiting أو body limit. أضف health endpoint داخلياً فقط، واسمح فقط بالمسار `/github` للإرسال.

## متغيرات التشغيل

| المتغير | الاستخدام | مثال آمن |
|---|---|---|
| `GITHUB_WEBHOOK_SECRET` | التحقق من `X-Hub-Signature-256` | secret manager فقط |
| `SLACK_WEBHOOK_URL` | عنوان Incoming Webhook للقناة | secret manager فقط |
| `REQUIRED_CHECKS` | أسماء الفحوصات الدقيقة مفصولة بفواصل | `Quality gate,Prometheus to Alertmanager integration` |
| `PROTECTED_BRANCH` | الفرع المستهدف | `main` |
| `REDIS_URL` | تخزين delivery IDs لمنع التكرار بين النسخ | `rediss://...` |
| `GITHUB_WEBHOOK_IDEMPOTENCY_TTL` | مدة الاحتفاظ بالتسليم | `86400` |
| `SLACK_MAX_RETRIES` | محاولات Slack المحدودة | `2` |

لا تضع القيم السرية في GitHub workflow أو ملفات Compose أو السجلات. استخدم GitHub Environment أو secret manager للمستضيف، ودوّر سر GitHub وSlack عند الاشتباه بتسربه.

## تشغيل الخدمة

```bash
export GITHUB_WEBHOOK_SECRET='from-secret-manager'
export SLACK_WEBHOOK_URL='from-secret-manager'
export REQUIRED_CHECKS='SAST and dependency security,Security scanning,Quality gate,Integration tests,Full coverage,Fast checks,Prometheus to Alertmanager integration'
export PROTECTED_BRANCH='main'
python3 backend/ops/github_required_checks_webhook.py
```

في الإنتاج شغّلها خلف ASGI/HTTP reverse proxy أو خدمة مستقلة مع systemd/Kubernetes، وأضف health check وmetrics على مستوى المستضيف. يجب أن يكون Redis مشفراً ومحمياً بالمصادقة، وأن يستخدم `SET NX EX` على `X-GitHub-Delivery`.

## سياسة الإشعار

يُرسل Slack فقط بعد اكتمال الفحص وفشله. لا تُرسل الأحداث الناجحة أو المكررة. تحتوي الرسالة على اسم المستودع، اسم الفحص، النتيجة، أول 12 خانة من SHA، رقم التسليم، ورابط GitHub. تُخفى عناوين Slack تلقائياً قبل بناء الرسالة. يعيد المستقبل `502` إذا تعذر Slack بعد retry محدود، كي يمكن رصد الفشل دون تحويله إلى نجاح كاذب.

تتعامل الخدمة مع `429` و`5xx` كأخطاء مؤقتة، وتحترم `Retry-After` مع سقف زمني. أما أخطاء التحقق أو الحمولة غير الصالحة فتُرفض مباشرة ولا تُعاد محاولتها.

## الاختبارات

```bash
python3 -m py_compile backend/ops/github_required_checks_webhook.py
pytest -q tooling/test_github_required_checks_webhook.py
```

تغطي الاختبارات التوقيع الصحيح والخاطئ، الفحص المكتمل والفحص غير المكتمل، تصفية الفرع، Pull Request المستهدف، deduplication، redaction، وعدم وجود Slack URL. استخدم مستقبلاً fake Slack receiver محلياً، ولا توجه الاختبارات إلى قناة إنتاج.

## التنبيه عند تعطل التنبيه

راقب عدد استجابات `401` و`413` و`502`، وزمن Slack، وعدد delivery IDs المكررة، وحالة Redis، وعدد الفحوصات الفاشلة المستلمة. يجب أن تملك الخدمة قناة بديلة مثل سجل مركزي أو Alertmanager داخلي؛ لأن فشل Slack لا ينبغي أن يخفي فشل Required Check.

## المراجع

[1] [GitHub webhook events and payloads](https://docs.github.com/en/webhooks/webhook-events-and-payloads)

[2] [GitHub status checks](https://docs.github.com/en/pull-requests/statuses)

[3] [Slack incoming webhooks](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks)

[4] [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
