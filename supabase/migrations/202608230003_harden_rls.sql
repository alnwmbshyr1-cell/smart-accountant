-- تشديد RLS لجداول مقاني. يفترض تطبيق 202608230001_sync.sql أولاً.
-- نفّذها عبر Supabase CLI أو SQL Editor في بيئة staging قبل الإنتاج.

revoke all on table public.animals, public.health_records, public.financial_entries from anon;
grant select, insert, update, delete on table public.animals, public.health_records, public.financial_entries to authenticated;

alter table public.animals enable row level security;
alter table public.health_records enable row level security;
alter table public.financial_entries enable row level security;

-- اجعل الهجرة قابلة لإعادة التطبيق دون أخطاء create policy.
drop policy if exists "animals owner read" on public.animals;
drop policy if exists "animals owner insert" on public.animals;
drop policy if exists "animals owner update" on public.animals;
drop policy if exists "animals owner delete" on public.animals;
create policy "animals owner read" on public.animals for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "animals owner insert" on public.animals for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "animals owner update" on public.animals for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy "animals owner delete" on public.animals for delete to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "health_records owner read" on public.health_records;
drop policy if exists "health_records owner insert" on public.health_records;
drop policy if exists "health_records owner update" on public.health_records;
drop policy if exists "health_records owner delete" on public.health_records;
create policy "health_records owner read" on public.health_records for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "health_records owner insert" on public.health_records for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "health_records owner update" on public.health_records for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy "health_records owner delete" on public.health_records for delete to authenticated
  using ((select auth.uid()) = owner_id);

 drop policy if exists "financial_entries owner read" on public.financial_entries;
drop policy if exists "financial_entries owner insert" on public.financial_entries;
drop policy if exists "financial_entries owner update" on public.financial_entries;
drop policy if exists "financial_entries owner delete" on public.financial_entries;
create policy "financial_entries owner read" on public.financial_entries for select to authenticated
  using ((select auth.uid()) = owner_id);
create policy "financial_entries owner insert" on public.financial_entries for insert to authenticated
  with check ((select auth.uid()) = owner_id);
create policy "financial_entries owner update" on public.financial_entries for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);
create policy "financial_entries owner delete" on public.financial_entries for delete to authenticated
  using ((select auth.uid()) = owner_id);

create or replace function public.prevent_owner_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    raise exception 'owner_id cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists animals_owner_immutable on public.animals;
create trigger animals_owner_immutable before update on public.animals
for each row execute function public.prevent_owner_change();
drop trigger if exists health_records_owner_immutable on public.health_records;
create trigger health_records_owner_immutable before update on public.health_records
for each row execute function public.prevent_owner_change();
drop trigger if exists financial_entries_owner_immutable on public.financial_entries;
create trigger financial_entries_owner_immutable before update on public.financial_entries
for each row execute function public.prevent_owner_change();
