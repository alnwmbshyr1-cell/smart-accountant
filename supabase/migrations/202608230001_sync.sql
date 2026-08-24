-- مخطط اختياري لمزامنة بيانات مقاني مع Supabase.
-- شغّل هذه الهجرة بعد إنشاء مشروع Supabase، ولا تستخدم service_role_key داخل التطبيق.

create table if not exists public.animals (
  remote_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id bigint not null,
  number text not null,
  tag_color text not null,
  animal_type text not null,
  gender text not null,
  birth_date timestamptz,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (owner_id, local_id)
);

create table if not exists public.health_records (
  remote_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id bigint not null,
  animal_number text not null,
  condition text not null,
  notes text,
  status text not null,
  date timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (owner_id, local_id)
);

create table if not exists public.financial_entries (
  remote_id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  local_id bigint not null,
  kind text not null check (kind in ('income', 'expense')),
  amount numeric(12,2) not null check (amount > 0),
  category text not null,
  note text,
  date timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (owner_id, local_id)
);

create index if not exists animals_owner_updated_idx on public.animals(owner_id, updated_at);
create index if not exists health_owner_updated_idx on public.health_records(owner_id, updated_at);
create index if not exists finance_owner_updated_idx on public.financial_entries(owner_id, updated_at);

alter table public.animals enable row level security;
alter table public.health_records enable row level security;
alter table public.financial_entries enable row level security;

do $$
declare t text;
begin
  foreach t in array array['animals', 'health_records', 'financial_entries'] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy "%I owner read" on public.%I for select to authenticated using ((select auth.uid()) = owner_id)', t, t);
    execute format('create policy "%I owner insert" on public.%I for insert to authenticated with check ((select auth.uid()) = owner_id)', t, t);
    execute format('create policy "%I owner update" on public.%I for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id)', t, t);
    execute format('create policy "%I owner delete" on public.%I for delete to authenticated using ((select auth.uid()) = owner_id)', t, t);
  end loop;
end $$;
