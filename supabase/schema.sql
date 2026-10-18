-- Schema für die Geburtstagsseite. Einmal komplett im Supabase SQL Editor ausführen.

-- Wer Host ist (Wünsche anlegen/löschen, Ideen löschen). Wird von Hand befüllt, siehe README.
create table if not exists public.hosts (
  user_id uuid primary key references auth.users on delete cascade
);
alter table public.hosts enable row level security;

create or replace function public.is_host()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.hosts where user_id = auth.uid());
$$;
grant execute on function public.is_host() to authenticated;

-- Anmeldungen: eine Zeile pro Gast (anonymer Login), joined = Wünsche/Ideen, bei denen man mitmacht
create table if not exists public.guests (
  id uuid primary key default auth.uid() references auth.users on delete cascade,
  name text not null check (char_length(name) between 1 and 60),
  plus text[] not null default '{}' check (cardinality(plus) <= 8),
  note text not null default '' check (char_length(note) <= 200),
  coming boolean not null default true,
  joined text[] not null default '{}' check (cardinality(joined) <= 200),
  updated_at timestamptz not null default now()
);
alter table public.guests enable row level security;
create policy "guests: eigene oder Host lesen" on public.guests for select to authenticated using (id = auth.uid() or public.is_host());
create policy "guests: eigene anlegen" on public.guests for insert to authenticated with check (id = auth.uid());
create policy "guests: eigene ändern" on public.guests for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy "guests: eigene oder Host löschen" on public.guests for delete to authenticated using (id = auth.uid() or public.is_host());

-- Wünsche: nur der Host schreibt
create table if not exists public.wishes (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 90),
  price text not null default '' check (char_length(price) <= 20),
  link text not null default '' check (char_length(link) <= 400),
  note text not null default '' check (char_length(note) <= 200),
  created_at timestamptz not null default now()
);
alter table public.wishes enable row level security;
create policy "wishes: alle lesen" on public.wishes for select to authenticated using (true);
create policy "wishes: Host anlegen" on public.wishes for insert to authenticated with check (public.is_host());
create policy "wishes: Host ändern" on public.wishes for update to authenticated using (public.is_host()) with check (public.is_host());
create policy "wishes: Host löschen" on public.wishes for delete to authenticated using (public.is_host());

-- Geschenkideen der Gäste
create table if not exists public.ideas (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 90),
  price text not null default '' check (char_length(price) <= 20),
  link text not null default '' check (char_length(link) <= 400),
  note text not null default '' check (char_length(note) <= 200),
  author uuid not null default auth.uid() references auth.users on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.ideas enable row level security;
create policy "ideas: alle lesen" on public.ideas for select to authenticated using (true);
create policy "ideas: eigene anlegen" on public.ideas for insert to authenticated with check (author = auth.uid());
create policy "ideas: eigene oder Host löschen" on public.ideas for delete to authenticated using (author = auth.uid() or public.is_host());

-- Live-Updates
alter publication supabase_realtime add table public.guests, public.wishes, public.ideas;

-- Gruppen, Ideen-Autor:innen und Zähler für Gäste (die Gästeliste selbst sieht nur der Host)
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
