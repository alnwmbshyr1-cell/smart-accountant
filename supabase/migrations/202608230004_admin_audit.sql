-- مقاني: أدوار المشرفين وسجل التدقيق. طبّقها بعد 202608230002_auth_profiles.sql.
create type public.app_role as enum ('user', 'admin', 'support');

create table if not exists public.user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role public.app_role not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  target_user_id uuid references auth.users(id) on delete set null,
  action text not null check (action <> ''),
  entity text not null check (entity <> ''),
  entity_id text,
  old_data jsonb,
  new_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_roles_role_idx on public.user_roles(role);
create index if not exists admin_audit_actor_idx on public.admin_audit_logs(actor_user_id, created_at desc);
create index if not exists admin_audit_target_idx on public.admin_audit_logs(target_user_id, created_at desc);
create index if not exists admin_audit_created_idx on public.admin_audit_logs(created_at desc);

create schema if not exists private;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, private
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = (select auth.uid()) and role = 'admin'
  );
$$;

revoke all on function private.is_admin() from public;
grant execute on function private.is_admin() to authenticated;

alter table public.user_roles enable row level security;
alter table public.admin_audit_logs enable row level security;
revoke all on public.user_roles, public.admin_audit_logs from anon;
grant select on public.user_roles, public.admin_audit_logs to authenticated;

drop policy if exists "users read own role" on public.user_roles;
create policy "users read own role" on public.user_roles
for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "admins read roles" on public.user_roles;
create policy "admins read roles" on public.user_roles
for select to authenticated
using ((select private.is_admin()));

drop policy if exists "admins read audit logs" on public.admin_audit_logs;
create policy "admins read audit logs" on public.admin_audit_logs
for select to authenticated
using ((select private.is_admin()));

-- لا تمنح العميل صلاحية insert/update/delete على user_roles أو audit_logs.
revoke insert, update, delete on public.user_roles, public.admin_audit_logs from authenticated;

create or replace function private.audit_profile_change()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
declare
  actor uuid := (select auth.uid());
  target uuid;
  before_data jsonb;
  after_data jsonb;
begin
  target := coalesce(new.id, old.id);
  before_data := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end;
  after_data := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end;

  insert into public.admin_audit_logs (
    actor_user_id, target_user_id, action, entity, entity_id, old_data, new_data, metadata
  ) values (
    actor, target, lower(tg_op), 'profiles', target::text,
    before_data, after_data,
    jsonb_build_object('source', case when actor is null then 'system' else 'authenticated_session' end)
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists profiles_admin_audit on public.profiles;
create trigger profiles_admin_audit
after insert or update or delete on public.profiles
for each row execute function private.audit_profile_change();

create or replace function private.audit_role_change()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  insert into public.admin_audit_logs (
    actor_user_id, target_user_id, action, entity, entity_id, old_data, new_data
  ) values (
    (select auth.uid()), coalesce(new.user_id, old.user_id), lower(tg_op), 'user_roles',
    coalesce(new.user_id, old.user_id)::text,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) else null end
  );
  return coalesce(new, old);
end;
$$;

drop trigger if exists user_roles_admin_audit on public.user_roles;
create trigger user_roles_admin_audit
after insert or update or delete on public.user_roles
for each row execute function private.audit_role_change();

-- يمنع حذف أو تخفيض آخر مشرف، حتى عبر مسار إداري غير مقصود.
create or replace function private.prevent_last_admin_removal()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  if (tg_op = 'DELETE' and old.role = 'admin') or
     (tg_op = 'UPDATE' and old.role = 'admin' and new.role <> 'admin') then
    if (select count(*) from public.user_roles where role = 'admin') <= 1 then
      raise exception 'لا يمكن إزالة آخر مشرف';
    end if;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists prevent_last_admin_removal on public.user_roles;
create trigger prevent_last_admin_removal
before update or delete on public.user_roles
for each row execute function private.prevent_last_admin_removal();
