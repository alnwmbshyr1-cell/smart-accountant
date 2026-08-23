// مقاني: لا تنشر هذه الوظيفة مع أسرار داخل المستودع. استخدم Supabase Secrets.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': Deno.env.get('ADMIN_APP_ORIGIN') ?? '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function errorMessage(error: unknown) {
  return error instanceof Error ? error.message : 'خطأ غير متوقع';
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'الطريقة غير مسموحة' }, 405);

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !publishableKey || !serviceRoleKey) return json({ error: 'إعدادات الخادم غير مكتملة' }, 500);

  const authorization = request.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'تسجيل الدخول مطلوب' }, 401);
  const token = authorization.slice('Bearer '.length);

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await userClient.auth.getUser(token);
  const actor = userData.user;
  if (userError || !actor) return json({ error: 'جلسة غير صالحة' }, 401);

  const { data: actorRole, error: actorRoleError } = await adminClient
    .from('user_roles')
    .select('role')
    .eq('user_id', actor.id)
    .maybeSingle();
  if (actorRoleError) return json({ error: 'تعذر التحقق من صلاحية المشرف' }, 500);
  if (actorRole?.role !== 'admin') return json({ error: 'هذه العملية للمشرفين فقط' }, 403);

  let body: { user_id?: string; role?: 'user' | 'admin' | 'support' };
  try {
    body = await request.json();
  } catch {
    return json({ error: 'جسم الطلب غير صالح' }, 400);
  }
  if (!body.user_id || !body.role) return json({ error: 'user_id و role مطلوبان' }, 400);
  if (!/^[0-9a-f-]{36}$/i.test(body.user_id)) return json({ error: 'معرّف المستخدم غير صالح' }, 400);
  if (body.user_id === actor.id && body.role !== 'admin') return json({ error: 'لا يمكنك تخفيض دورك بنفسك' }, 409);

  const { data: target, error: targetError } = await adminClient.auth.admin.getUserById(body.user_id);
  if (targetError || !target.user) return json({ error: 'المستخدم المطلوب غير موجود' }, 404);

  const { error: upsertError } = await adminClient.from('user_roles').upsert({
    user_id: body.user_id,
    role: body.role,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'user_id' });
  if (upsertError) return json({ error: 'تعذر حفظ الدور' }, 500);

  const { error: auditError } = await adminClient.from('admin_audit_logs').insert({
    actor_user_id: actor.id,
    target_user_id: body.user_id,
    action: 'assign_role',
    entity: 'user_roles',
    entity_id: body.user_id,
    new_data: { role: body.role },
    metadata: { source: 'assign-user-role', request_id: request.headers.get('x-request-id') },
  });
  if (auditError) return json({ error: 'تم حفظ الدور لكن تعذر تسجيل التدقيق' }, 500);

  return json({ ok: true, user_id: body.user_id, role: body.role });
});
