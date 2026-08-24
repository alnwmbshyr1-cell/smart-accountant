# Local Docker SAST Preflight

يشغّل `tooling/sast_docker_preflight.sh` حاويتي Semgrep وTrivy محلياً مع mounted source للقراءة فقط، ويستخدم الإصدارات المثبتة نفسها المعلنة في السكربت. الهدف هو كشف مشكلات SAST، dependencies، misconfiguration، وsecrets قبل رفع الكود.

## التشغيل

```bash
cd smart-accountant
chmod +x tooling/sast_docker_preflight.sh
tooling/sast_docker_preflight.sh
```

تُكتب التقارير في:

```text
.sast-local/semgrep.sarif
.sast-local/trivy-webhook.sarif
.sast-local/summary.json
```

يفشل السكربت إذا أعاد Semgrep أو Trivy نتيجة غير صفرية، بما في ذلك اكتشاف High/Critical من Trivy. لا يضع الأسرار داخل command line أو environment، ولا يكتب إلى source tree إلا في مجلد النتائج المحلي.

## مطابقة CI

تستخدم مرحلة CI الحالية Semgrep مع قواعد Python وJavaScript وSecrets، وTrivy مع `vuln,misconfig,secret` و`HIGH,CRITICAL`. قبل اعتماد مطابقة كاملة، ثبّت إصدارات صور Docker في المستودع نفسه ولا تستخدم `latest`.

```bash
SEMGREP_IMAGE=semgrep/semgrep:1.136.0 \
TRIVY_IMAGE=aquasec/trivy:0.59.1 \
tooling/sast_docker_preflight.sh
```

## مراجعة SARIF

افتح ملفات SARIF في GitHub Code Scanning أو أي SARIF viewer. استخدم `summary.json` لمعرفة أي أداة فشلت، لكن لا تعتبر نجاح تشغيل الحاوية دليلاً على عدم وجود ثغرات؛ يجب أن تكون النتيجة نفسها بحالة PASS.

لا تشغّل هذا السكربت على مجلد يحتوي أسراراً محلية غير مطلوبة، ولا ترفع `.sast-local/` إلى Git. افحص `git status` قبل commit. في Pull Requests من fork، لا تمرر أسراراً إلى الحاويات ولا تستخدم `pull_request_target`.

## التنظيف

```bash
rm -rf .sast-local
```
