# اختبار workflow_run محلياً باستخدام act

يتيح هذا المسار محاكاة اكتمال `Smart Accountant CI/CD` محلياً دون push إلى GitHub. يحتاج إلى Docker و`act` مثبتين على جهاز المطور.

## التشغيل

```bash
chmod +x tooling/act_workflow_run_preflight.sh

tooling/act_workflow_run_preflight.sh workflow_run-quality-failed.json
```

يجب أن ينتج fixture الفشل قرار `quality_failed=true`، مع تخطي Job طلب المراجعة لأن `ACT_LOCAL=true` يمنع كل طلبات API الكتابية.

اختبر الحالات الأخرى:

```bash
tooling/act_workflow_run_preflight.sh workflow_run-quality-passed.json
tooling/act_workflow_run_preflight.sh workflow_run-fork-failed.json
```

| Fixture | النتيجة المتوقعة |
|---|---|
| `workflow_run-quality-failed.json` | اكتشاف الفشل، ثم no-write محلياً |
| `workflow_run-quality-passed.json` | لا يوجد تصعيد |
| `workflow_run-fork-failed.json` | مسار fork الآمن بلا reviewer أو label أو comment |

## ضوابط عدم الكتابة

يستخدم السكربت:

```text
ACT_LOCAL=true
GITHUB_TOKEN فارغ
SECURITY_TEAM_SLUG فارغ
SECURITY_REVIEWER فارغ
```

لا تمرر token إلى `act`، ولا تستخدم `-s GITHUB_TOKEN=...`. أضف `--dryrun` أو `--verbose` عند الحاجة إلى تحليل الأفعال دون تشغيل كتابة. إذا حاولت Action الاتصال بـGitHub أو تعذر تنفيذها محلياً، اعتبر ذلك فشل إعداد وليس دليلاً على نجاح الصلاحيات؛ تعتمد صلاحيات GitHub الحقيقية على Workflow run في المستودع.

## ما يثبته الاختبار

يثبت الاختبار أن event payload يحتوي `workflow_run.head_sha` وPull Request مرتبطاً، وأن قرار `same_repo` ومسارات firing/fork تعمل، وأن بوابة `ACT_LOCAL` تمنع التعليق وطلب المراجعة وإضافة label. لا يثبت فعلياً صلاحية GitHub token أو وجود فريق الأمن؛ تحقق من ذلك لاحقاً في مستودع اختبار أو Environment staging منفصل.
