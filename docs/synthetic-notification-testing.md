# Synthetic Testing محلي لإشعارات Alertmanager

## الهدف

اختبر firing وresolved وHMAC وdeduplication محلياً من دون إرسال أي طلب إلى PagerDuty أو Slack أو Webhook إنتاجي. يستخدم المختبر مستقبلاً محلياً على loopback ومسارات مشابهة لوجهات Alertmanager.

## التشغيل

```bash
mkdir -p artifacts
python3 tooling/synthetic_alert_receiver.py \
  --host 127.0.0.1 --port 18080 \
  --secret local-only \
  --output artifacts/synthetic-receiver-events.json
```

في طرفية ثانية:

```bash
python3 tooling/run_synthetic_notifications.py \
  --base-url http://127.0.0.1:18080 \
  --secret local-only \
  --output artifacts/synthetic-results.json
```

يتحقق الـrunner من إرسال حالتي `firing` و`resolved` إلى `/webhook` و`/pagerduty/v2/enqueue` مع status `202`. اعرض الأحداث المسجلة عبر:

```bash
curl -fsS http://127.0.0.1:18080/received | jq .
```

## العزل الأمني

يقبل الـrunner loopback فقط، ويرفض receiver أي bind غير محلي. لا تضع `routing_key_file` أو Slack URL أو Webhook إنتاجياً أو قيمة HMAC إنتاجية في الاختبارات. استخدم `local-only` أو secret يولده CI داخل GitHub Environment منفصل باسم `synthetic`.

يوقّع مسار Webhook المحلي body بـHMAC، بينما يقبل مسار PagerDuty mock الحدث دون secret لأنه لا يتصل بـPagerDuty الحقيقي. اختبر HMAC غير صالح وتأكد من `401`، واختبر إعادة نفس payload للتحقق من body hash وdeduplication في البوابة الحقيقية.

## دمج Alertmanager محلياً

أنشئ override محلياً يوجه receiver إلى:

```yaml
webhook_configs:
  - url: http://host.docker.internal:18080/webhook
    send_resolved: true
pagerduty_configs:
  - routing_key: local-test-only
    send_resolved: true
```

لا تستخدم هذا override في الإنتاج. إذا كان Alertmanager داخل Linux container، استخدم شبكة Compose مشتركة واسم service بدلاً من `host.docker.internal`. يمكن فحص configuration قبل التشغيل بـ`amtool check-config`.

## معايير النجاح

| الاختبار | معيار القبول |
|---|---|
| Firing | وصول حدث واحد لكل قناة وstatus=`firing` |
| Resolved | وصول حدث واحد لكل قناة وstatus=`resolved` |
| HMAC | body المعدل أو التوقيع الخاطئ مرفوض بـ401 |
| Isolation | لا يحتوي الكود أو fixtures على production URLs أو secrets |
| Timeout | فشل mock لا يحجز Alertmanager indefinitely |
| Evidence | إنشاء JSON results وreceiver events كـCI artifacts |

## CI

شغّل اختبارات Python الثابتة في كل Pull Request، وشغّل integration job محلياً داخل Compose عند الحاجة. ارفع artifacts عند الفشل، واحذفها أو قلّص retention إذا احتوت بيانات تشخيصية. لا تجعل Synthetic job يرسل إشعارات فعلية؛ استخدم mock أو PagerDuty test service مع routing key غير إنتاجي فقط.

## References

[1] [Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/)
[2] [PagerDuty Events API v2](https://developer.pagerduty.com/docs/events-api-v2/)
