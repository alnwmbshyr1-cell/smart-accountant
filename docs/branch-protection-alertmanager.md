# حماية فرع main لفحص Alertmanager

## الحالة المطبقة

تمت إضافة check الدقيق التالي إلى required status checks لفرع `main`:

```text
Prometheus to Alertmanager integration
```

وتبقى الفحوصات الأمنية والجودة الحالية مطلوبة أيضاً:

```text
SAST and dependency security
Security scanning
Quality gate
Integration tests
Full coverage
Fast checks
Prometheus to Alertmanager integration
```

القاعدة تستخدم strict status checks، ومراجعة Pull Request واحدة، وCode Owners، وlinear history، وconversation resolution، وتمنع force-push وdeletion، مع enforcement على administrators.

## التحقق

```bash
gh api repos/OWNER/REPO/branches/main/protection/required_status_checks \
  --jq '{strict,checks:[.checks[].context]}'
```

ينبغي أن يظهر check الجديد بالاسم الكامل. لا تعتمد على اسم Workflow فقط؛ الاسم الذي يجب إدخاله هو اسم Job/check الذي يعيده `gh pr checks`.

## واجهة GitHub

من `Settings → Branches` اختر قاعدة `main`، فعّل **Require status checks to pass before merging**، ثم اختر `Prometheus to Alertmanager integration` مع الفحوصات الموجودة. فعّل **Require branches to be up to date**، واطلب مراجعة واحدة، وفعّل إغلاق المحادثات قبل الدمج.

## التشغيل والصيانة

إذا تغيّر اسم Workflow أو Job، سيظهر check القديم كـPending دائماً وقد يمنع الدمج. عند تغيير الاسم، نفّذ التحديث في نفس Pull Request وتحقق من check جديد على Pull Request تجريبي قبل حذف القديم. لا تجعل اختبارات PagerDuty الحقيقية أو Chaos أو Staging notification checks جزءاً من هذا gate المحلي؛ أبقها في Environments محمية منفصلة.

## References

[1] [GitHub protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
[2] [GitHub REST branch protection](https://docs.github.com/en/rest/branches/branch-protection)
