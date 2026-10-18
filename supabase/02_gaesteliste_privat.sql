-- Gästeliste nur für den Host. Gäste sehen nur ihre eigene Anmeldung.
-- Für Gruppen, Ideen-Autor:innen und den Zähler gibt es eine Funktion, die nur das Nötigste herausgibt.

drop policy if exists "guests: alle lesen" on public.guests;
drop policy if exists "guests: eigene oder Host lesen" on public.guests;
create policy "guests: eigene oder Host lesen" on public.guests for select to authenticated
  using (id = auth.uid() or public.is_host());

create or replace function public.party_public()
returns json language sql stable security definer set search_path = public as $$
  select case when auth.uid() is null then null else json_build_object(
    'count',   (select coalesce(sum(1 + cardinality(plus)), 0) from public.guests where coming),
    'members', (select coalesce(json_agg(json_build_object('item', j, 'guest', g.id, 'name', g.name)), '[]'::json)
                from public.guests g, unnest(g.joined) j),
    'authors', (select coalesce(json_agg(json_build_object('id', g.id, 'name', g.name)), '[]'::json)
                from public.guests g where g.id in (select author from public.ideas))
  ) end;
$$;
revoke execute on function public.party_public() from public, anon;
grant execute on function public.party_public() to authenticated;
