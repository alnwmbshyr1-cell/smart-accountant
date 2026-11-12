-- Run in Supabase SQL Editor (or apply as a migration) before enabling cloud snapshots.
-- Client app uses the publishable/anon key only. RLS binds every row to auth.uid().
create table if not exists public.accounting_snapshots (
  user_id uuid primary key references auth.users(id) on delete cascade,
  schema_version integer not null check (schema_version = 1),
  payload jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.accounting_snapshots enable row level security;
revoke all on public.accounting_snapshots from anon;
grant select, insert, update, delete on public.accounting_snapshots to authenticated;

drop policy if exists "owner reads own accounting snapshot" on public.accounting_snapshots;
create policy "owner reads own accounting snapshot"
  on public.accounting_snapshots for select to authenticated
  using (auth.uid() = user_id);

drop policy if exists "owner creates own accounting snapshot" on public.accounting_snapshots;
create policy "owner creates own accounting snapshot"
  on public.accounting_snapshots for insert to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "owner updates own accounting snapshot" on public.accounting_snapshots;
create policy "owner updates own accounting snapshot"
  on public.accounting_snapshots for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "owner deletes own accounting snapshot" on public.accounting_snapshots;
create policy "owner deletes own accounting snapshot"
  on public.accounting_snapshots for delete to authenticated
  using (auth.uid() = user_id);
