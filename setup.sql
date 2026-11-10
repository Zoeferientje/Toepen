-- Toepen leaderboard: tabellen en regels
-- Plak dit in Supabase > SQL Editor en klik op Run.

create table if not exists public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 30),
  is_guest boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index if not exists players_name_unique on public.players (lower(trim(name)));

create table if not exists public.losses (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references public.players(id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists losses_created_at_idx on public.losses (created_at desc);

alter table public.players enable row level security;
alter table public.losses enable row level security;

grant select, insert on public.players to anon;
grant select, insert, delete on public.losses to anon;

-- Iedereen met de link mag lezen, spelers toevoegen, verliezen toevoegen en een verlies ongedaan maken.
drop policy if exists "lezen spelers" on public.players;
create policy "lezen spelers" on public.players for select to anon using (true);
drop policy if exists "toevoegen spelers" on public.players;
create policy "toevoegen spelers" on public.players for insert to anon with check (true);

drop policy if exists "lezen verliezen" on public.losses;
create policy "lezen verliezen" on public.losses for select to anon using (true);
drop policy if exists "toevoegen verliezen" on public.losses;
create policy "toevoegen verliezen" on public.losses for insert to anon with check (true);
drop policy if exists "ongedaan maken verliezen" on public.losses;
create policy "ongedaan maken verliezen" on public.losses for delete to anon using (true);
