begin;

select plan(14);

-- بيانات اختبار محلية فقط. لا تستخدم UUIDs أو حسابات إنتاج.
create temporary table test_context (
  admin_id uuid,
  user_id uuid,
  other_user_id uuid,
  alert_id uuid,
  profile_id uuid
) on commit drop;

insert into test_context values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000002'
);

-- auth.users مرجع FK لملفات profiles والأدوار والتنبيهات.
insert into auth.users (id, email, aud, role, email_confirmed_at)
select admin_id, 'pgtap-admin@example.test', 'authenticated', 'authenticated', now()
from test_context
on conflict (id) do nothing;
insert into auth.users (id, email, aud, role, email_confirmed_at)
select user_id, 'pgtap-user@example.test', 'authenticated', 'authenticated', now()
from test_context
on conflict (id) do nothing;
insert into auth.users (id, email, aud, role, email_confirmed_at)
select other_user_id, 'pgtap-other@example.test', 'authenticated', 'authenticated', now()
from test_context
on conflict (id) do nothing;

insert into public.user_roles (user_id, role)
select admin_id, 'admin'::public.app_role from test_context
on conflict (user_id) do update set role = 'admin';
insert into public.user_roles (user_id, role)
select user_id, 'user'::public.app_role from test_context
on conflict (user_id) do update set role = 'user';

-- إدخال بيانات الاختبار بصلاحية مالك قاعدة البيانات قبل تفعيل role authenticated.
insert into public.profiles (id, display_name)
select user_id, 'pgtap user' from test_context
on conflict (id) do update set display_name = excluded.display_name;
insert into public.profiles (id, display_name)
select other_user_id, 'pgtap other' from test_context
on conflict (id) do update set display_name = excluded.display_name;
insert into public.security_alerts (
  id, event_type, severity, target_user_id, metadata
)
select alert_id, 'suspicious_activity', 'high', user_id, '{"test_run": true}'::jsonb
from test_context
on conflict (id) do nothing;

select has_table('public', 'admin_audit_logs', 'جدول التدقيق موجود');
select has_table('public', 'security_alerts', 'جدول التنبيهات موجود');
select has_column('public', 'security_alerts', 'event_type', 'نوع الحدث موجود');
select has_column('public', 'security_alerts', 'resolved_at', 'حقل الحل موجود');

-- محاكاة JWT للمشرف عبر auth.uid() ثم استخدام دور authenticated.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', admin_id::text, 'role', 'authenticated')::text,
  true
) from test_context;
set local role authenticated;

select is((select private.is_admin()), true, 'المشرف يمر من فحص is_admin');
select isnt_empty(
  $$select id from public.profiles order by id$$,
  'المشرف يرى ملفات المستخدمين'
);
select isnt_empty(
  $$select id from public.security_alerts where id = '00000000-0000-0000-0000-000000000004'$$,
  'المشرف يرى التنبيه الأمني'
);

-- محاكاة مستخدم عادي.
select set_config(
  'request.jwt.claims',
  json_build_object('sub', user_id::text, 'role', 'authenticated')::text,
  true
) from test_context;

select is((select private.is_admin()), false, 'المستخدم العادي ليس مشرفاً');
select is_empty(
  $$select id from public.profiles where id <> '00000000-0000-0000-0000-000000000002'$$,
  'المستخدم العادي لا يرى ملفات الآخرين'
);
select is_empty(
  $$select id from public.security_alerts$$,
  'المستخدم العادي لا يرى التنبيهات الأمنية'
);

-- يجب ألا يستطيع المستخدم تعديل تنبيه أو إدخال سجل تدقيق مباشرة.
select is_empty(
  $$update public.security_alerts
    set resolved_at = now()
    where id = '00000000-0000-0000-0000-000000000004'
    returning id$$,
  'المستخدم العادي لا يستطيع حل تنبيه'
);

select throws_ok(
  $$insert into public.admin_audit_logs (action, entity) values ('fake', 'fake')$$,
  '42501',
  null,
  'العميل لا يستطيع إدخال سجل تدقيق مباشرة'
);

-- العودة إلى postgres للتحقق من وجود سجل التدقيق الناتج عن Trigger.
reset role;
select ok(
  exists (
    select 1 from public.admin_audit_logs
    where target_user_id = '00000000-0000-0000-0000-000000000002'
      and entity = 'profiles'
  ),
  'تعديل profile يولد سجل تدقيق'
);

select * from finish();
rollback;
