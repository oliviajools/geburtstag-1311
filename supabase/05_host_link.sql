-- Host-Zugang ohne E-Mail: Wer die Seite mit #host=GEHEIMNIS öffnet, wird in diesem Browser Host.
-- GEHEIMNIS unten durch einen langen Zufallswert ersetzen und NICHT ins Repo committen (das Repo ist öffentlich).

create table if not exists public.host_keys (
  key text primary key check (char_length(key) >= 24)
);
alter table public.host_keys enable row level security;
revoke all on public.host_keys from anon, authenticated;   -- niemand kann die Schlüssel lesen

create or replace function public.claim_host(k text)
returns boolean language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not exists (select 1 from public.host_keys where key = k) then
    return false;
  end if;
  insert into public.hosts (user_id) values (auth.uid()) on conflict do nothing;
  return true;
end;
$$;
revoke execute on function public.claim_host(text) from public, anon;
grant execute on function public.claim_host(text) to authenticated;

insert into public.host_keys (key) values ('GEHEIMNIS') on conflict do nothing;
