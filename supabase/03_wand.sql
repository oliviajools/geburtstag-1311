-- Die Wand: anonyme Geschichten (peinlich, lustig, wie wir uns kennengelernt haben).
-- Die Autor-ID wird nur gespeichert, damit man den eigenen Post wieder löschen kann.
-- Über die Seite ist sie für niemanden lesbar, auch nicht für den Host.

create table if not exists public.wall (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('peinlich', 'lustig', 'kennenlernen')),
  body text not null check (char_length(body) between 1 and 600),
  author uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.wall enable row level security;

drop policy if exists "wall: alle lesen" on public.wall;
drop policy if exists "wall: anlegen" on public.wall;
drop policy if exists "wall: Host löschen" on public.wall;
create policy "wall: alle lesen" on public.wall for select to authenticated using (true);
create policy "wall: anlegen" on public.wall for insert to authenticated with check (author = auth.uid());
create policy "wall: Host löschen" on public.wall for delete to authenticated using (public.is_host());

-- Spalte author ist für Gäste und Host unsichtbar
revoke all on public.wall from anon, authenticated;
grant select (id, kind, body, created_at) on public.wall to authenticated;
grant insert (kind, body) on public.wall to authenticated;
grant delete on public.wall to authenticated;

-- Eigene Posts erkennen und löschen, ohne die Autor-ID herauszugeben
create or replace function public.wall_mine()
returns setof uuid language sql stable security definer set search_path = public as $$
  select id from public.wall where author = auth.uid();
$$;
create or replace function public.wall_delete_mine(pid uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.wall where id = pid and author = auth.uid();
$$;
revoke execute on function public.wall_mine() from public, anon;
revoke execute on function public.wall_delete_mine(uuid) from public, anon;
grant execute on function public.wall_mine() to authenticated;
grant execute on function public.wall_delete_mine(uuid) to authenticated;
