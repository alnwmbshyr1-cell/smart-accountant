-- Security alerts required by the protected integration tests.
create table if not exists public.security_alerts (
  id uuid primary key default gen_random_uuid(),
  event_type text not null,
  severity text not null check (severity in ('low', 'medium', 'high', 'critical')),
  target_user_id uuid not null references auth.users(id) on delete cascade,
  metadata jsonb not null default '{}'::jsonb,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists security_alerts_target_user_idx
  on public.security_alerts(target_user_id, created_at desc);
create index if not exists security_alerts_severity_idx
  on public.security_alerts(severity, created_at desc);

alter table public.security_alerts enable row level security;
revoke all on public.security_alerts from anon;
revoke insert, update, delete on public.security_alerts from authenticated;
grant select on public.security_alerts to authenticated;

drop policy if exists "admins read security alerts" on public.security_alerts;
create policy "admins read security alerts"
  on public.security_alerts for select to authenticated
  using ((select private.is_admin()));
