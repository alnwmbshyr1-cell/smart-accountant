# Staging Redis outage Chaos Test

## الغرض

تحاكي التجربة فقدان Redis المفاجئ لفترة قصيرة للتحقق من أن Workers لا تنهار بشكل متسلسل، وأن Circuit Breaker يفتح أو يفشل مغلقاً وفق السياسة، وأن الرسائل لا تتكرر، وأن النظام يتعافى بعد عودة Redis.

## ضوابط إلزامية

التجربة يدوية فقط من GitHub Environment محمي باسم `staging-chaos`. يجب أن يكون namespace محتوياً على `staging`، وأن يستخدم kubeconfig محدود الصلاحيات، وأن تكون مدة العطل بين 5 و300 ثانية. لا تستخدم عنقود الإنتاج أو بياناته أو أسراره. شغّل `--dry-run` أولاً.

```bash
python3 tooling/staging_redis_chaos.py \
  --namespace smart-accountant-staging \
  --redis-deployment redis \
  --fault-seconds 30 \
  --recovery-timeout 180 \
  --dry-run
```

التنفيذ يتطلب تأكيداً صريحاً:

```bash
python3 tooling/staging_redis_chaos.py \
  --namespace smart-accountant-staging \
  --redis-deployment redis \
  --fault-seconds 30 \
  --recovery-timeout 180 \
  --confirm-staging-chaos \
  --execute
```

يسجل المشغّل baseline، يخفض Redis إلى صفر replicas، يراقب مؤشرات التطبيق، ثم يعيد **عدد replicas الأصلي نفسه** داخل `finally`. بعد ذلك ينتظر عودة Redis إلى baseline قبل إعلان النجاح. إذا أُلغي Job قسراً فقد لا ينفذ `finally`؛ لذلك يجب تشغيل recovery runbook مستقل فوراً.

## معايير القبول

| المجال | معيار النجاح |
|---|---|
| Redis | عودة عدد replicas إلى القيمة الأصلية |
| Workers | إعادة الاتصال وعودة readiness |
| Circuit Breaker | انتقال متوقع دون retry storm |
| Stream | عدم فقد أو تكرار الأحداث، وانخفاض backlog بعد التعافي |
| DLQ | عدم وجود نمو غير متوقع |
| API | timeouts و5xx ضمن SLO التجريبي |
| Observability | وجود observations وEvents وlogs قابلة للمراجعة |

## GitHub Actions

يشغّل `.github/workflows/staging-redis-chaos.yml` التجربة يدوياً فقط، ويمنعها ما لم يكن `confirm_chaos=true`. يرفع ملف `artifacts/redis-chaos-observations.jsonl` وملفات diagnostics دائماً. أضف إلى Environment الأسرار `STAGING_KUBECONFIG_B64` و`STAGING_METRICS_URL` فقط، ولا تضف أسرار الوجهات الخارجية.

## Grafana

راقب `circuit_breaker_state` و`circuit_breaker_rejected_total` و`security_webhook_queue_depth` و`security_webhook_oldest_pending_age_seconds` و`security_webhook_dead_letter_total`، إضافة إلى `kube_deployment_status_replicas_ready` وRedis exporter metrics. استخدم annotations لوقت fault injection وrestore حتى تميّز أثر التجربة عن أعطال أخرى.

## References

[1] [Principles of Chaos Engineering](https://principlesofchaos.org/)
[2] [Kubernetes scaling a Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#scaling-a-deployment)
[3] [GitHub Actions environments](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
