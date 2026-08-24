# قالب وتصعيد مراجعة الأمن في Pull Requests

يستخدم المستودع ثلاثة مستويات متكاملة: قالب Pull Request يطلب توثيق فحوص الأمن، و`CODEOWNERS` لمسارات الحساسية، وWorkflow يصعّد المراجعة عند فشل Quality gate.

## الإعداد

أنشئ في إعدادات المستودع أو البيئة متغيري Repository/Environment التاليين:

| المتغير | الغرض |
|---|---|
| `SECURITY_TEAM_SLUG` | slug لفريق GitHub داخل المنظمة، مثل `security`؛ اتركه فارغاً إذا لم يوجد فريق |
| `SECURITY_REVIEWER` | حساب احتياطي لمراجع الأمن؛ الافتراضي مالك المستودع |

لا تضع token أو Slack webhook أو أي secret داخل القالب أو المتغيرات العامة. يتطلب طلب المراجعة صلاحيات `pull-requests: write` و`issues: write`، ويعمل فقط عندما يكون PR من نفس المستودع.

## السلوك

يشغّل `.github/workflows/security-review-on-quality-failure.yml` عند فتح/تحديث Pull Request، وعند اكتمال Workflow `Smart Accountant CI/CD`، وعند التشغيل اليدوي. يفحص حالات `Quality gate` و`Fast checks` و`Integration tests` و`Full coverage` و`SAST and dependency security` و`Security scanning`.

عند فشل أحدها في PR من نفس المستودع، يطلب مراجعة الحساب أو الفريق، يضيف label باسم `security-review-required`، وينشئ أو يحدّث تعليقاً واحداً باستخدام marker ثابت. لا يعيد إنشاء التعليق في كل إعادة تشغيل.

لا يستخدم Workflow `pull_request_target`، ولا يكتب على PR من fork. في حالة fork يكتفي بمسار read-only آمن، وتبقى حماية الفرع وrequired checks هي الحاجز النهائي.

## التفعيل النهائي

بعد إضافة الفريق أو الحساب، اجعل required checks في حماية `main` تشمل `Quality gate` وجميع فحوص SAST وCode Scanning. قالب PR والتصعيد الآلي لا يستبدلان branch protection؛ هما يضيفان وضوحاً ومسار مراجعة عند الفشل.
