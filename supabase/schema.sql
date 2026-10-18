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
create policy "guests: alle lesen" on public.guests for select to authenticated using (true);
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
