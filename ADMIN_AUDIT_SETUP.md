# إسناد دور المشرف وسجل التدقيق في مقاني

## ما تمت إضافته

أضيفت Migration `supabase/migrations/202608230004_admin_audit.sql`، وتقوم بإنشاء `user_roles` و`admin_audit_logs`، وتفعيل RLS، وإضافة دوال `private.is_admin()` وTriggers لتسجيل تغييرات `profiles` و`user_roles`. كما تمنع قاعدة البيانات إزالة آخر مشرف.

أضيفت Edge Function باسم `assign-user-role`. تتحقق الوظيفة من JWT في رأس `Authorization`، ثم تتحقق من دور المنفذ، وتتحقق من وجود المستخدم الهدف، وتمنع المشرف من تخفيض دوره بنفسه، وتستخدم مفتاح الخدمة داخل الوظيفة فقط، ثم تسجل العملية في `admin_audit_logs`.

## النشر

طبّق الهجرات أولاً في staging، ثم أنشئ مشرفاً أولياً يدوياً من SQL آمن أو Dashboard:

```sql
insert into public.user_roles (user_id, role)
values ('ADMIN_USER_UUID', 'admin')
on conflict (user_id) do update set role = 'admin';
```

بعد تجهيز Supabase CLI:

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase secrets set ADMIN_APP_ORIGIN=https://maqaniui-aduh9upy.manus.space
supabase functions deploy assign-user-role
```

يتم توفير `SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` في بيئة الوظيفة. لا تحفظ `SUPABASE_SERVICE_ROLE_KEY` في Flutter أو React أو GitHub repository.

## استدعاء الوظيفة من العميل

```ts
const { data, error } = await supabase.functions.invoke('assign-user-role', {
  body: { user_id: targetUserId, role: 'support' },
});
```

عميل Supabase يرسل جلسة المستخدم في Authorization. أبقِ التحقق من JWT مفعلاً افتراضياً في `supabase/config.toml`. لا تسمح للعميل بتحديد `actor_user_id`؛ الوظيفة تستخرجه من JWT.

## قراءة سجل التدقيق

لا تمنح `insert`, `update`, أو `delete` للمستخدمين على `admin_audit_logs`. القراءة للمشرف فقط:

```sql
select id, actor_user_id, target_user_id, action, entity,
       entity_id, metadata, created_at
from public.admin_audit_logs
order by created_at desc
limit 100;
```

تجنب عرض `old_data` و`new_data` بالكامل في الشاشة إذا احتوت بيانات شخصية. اعرض الحد الأدنى من الحقول، وطبّق pagination، واجعل السجل append-only.

## اختبارات الأمان

اختبر بمستخدم عادي أن استدعاء الوظيفة يعيد `403`، وبمشرف أن إسناد `support` ينجح، وبمشرف أن تخفيض دوره بنفسه يرفض، وأن تغيير `profiles` ينشئ سجلاً، وأن محاولة حذف آخر مشرف ترفضها قاعدة البيانات. اختبر أيضاً JWT منتهي الصلاحية و`user_id` غير صالح وطلباً مكرراً.

تستخدم Edge Function نمط `withSupabase({ auth: 'user' })` أو ما يعادله في بيئة Supabase التي تدعم ذلك؛ الكود الحالي يتحقق يدوياً من JWT باستخدام عميل المستخدم، ثم يستخدم عميل الخدمة فقط للعمليات الإدارية المحددة. توصي Supabase بإبقاء مفاتيح الخدمة على الخادم، والتحقق من Authorization قبل تنفيذ المنطق الحساس [1] [2].

### References

[1]: https://supabase.com/docs/guides/functions/auth "Securing Edge Functions — Supabase"
[2]: https://supabase.com/docs/reference/javascript/auth-admin-updateuserbyid "Supabase Admin Auth API"
[3]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security"
