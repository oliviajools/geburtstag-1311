-- „Ich kauf das“: Gäste reservieren einen Wunsch. Andere sehen nur „Vergeben“, nicht von wem.
-- Pro Wunsch höchstens eine Reservierung (Primärschlüssel).

create table if not exists public.claims (
  wish uuid primary key references public.wishes on delete cascade,
  buyer uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.claims enable row level security;

drop policy if exists "claims: alle lesen" on public.claims;
drop policy if exists "claims: anlegen" on public.claims;
create policy "claims: alle lesen" on public.claims for select to authenticated using (true);
create policy "claims: anlegen" on public.claims for insert to authenticated
  with check (buyer = auth.uid() and not public.is_host());

-- Spalte buyer bleibt für alle unsichtbar
revoke all on public.claims from anon, authenticated;
grant select (wish, created_at) on public.claims to authenticated;
grant insert (wish) on public.claims to authenticated;

create or replace function public.claims_mine()
returns setof uuid language sql stable security definer set search_path = public as $$
  select wish from public.claims where buyer = auth.uid();
$$;
create or replace function public.claim_release(w uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.claims where wish = w and (buyer = auth.uid() or public.is_host());
$$;
revoke execute on function public.claims_mine() from public, anon;
revoke execute on function public.claim_release(uuid) from public, anon;
grant execute on function public.claims_mine() to authenticated;
grant execute on function public.claim_release(uuid) to authenticated;
