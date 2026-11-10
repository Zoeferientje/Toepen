-- Stap 2: spellen en scores bijhouden
-- Plak dit in Supabase > SQL Editor en klik op Run. Je kunt het veilig vaker draaien.

-- Oude testdata weg: de losse "verliezen"-tabel en testspeler Lucas.
drop table if exists public.losses;
delete from public.players where lower(name) = 'lucas';

-- De vaste spelers van het huis.
insert into public.players (name, is_guest) values
  ('Henny', false), ('Vino', false), ('Siem', false), ('Luca', false), ('Tom', false)
on conflict do nothing;

-- Een spel (potje).
create table if not exists public.games (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  target int not null default 15 check (target between 2 and 100),
  round int not null default 1,
  status text not null default 'active' check (status in ('active', 'finished', 'cancelled'))
);
-- Er kan maar één spel tegelijk bezig zijn.
create unique index if not exists games_one_active on public.games (status) where status = 'active';

-- Wie er meedoet aan een spel, met de score en de uitslag.
create table if not exists public.game_players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.games(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  score int not null default 0,
  lost boolean not null default false,
  won boolean not null default false,
  unique (game_id, player_id)
);

alter table public.games enable row level security;
alter table public.game_players enable row level security;
grant select, insert, update on public.games to anon;
grant select, insert, update on public.game_players to anon;

drop policy if exists "lezen spellen" on public.games;
create policy "lezen spellen" on public.games for select to anon using (true);
drop policy if exists "starten spellen" on public.games;
create policy "starten spellen" on public.games for insert to anon with check (true);
drop policy if exists "bijwerken spellen" on public.games;
create policy "bijwerken spellen" on public.games for update to anon using (true) with check (true);

drop policy if exists "lezen deelnemers" on public.game_players;
create policy "lezen deelnemers" on public.game_players for select to anon using (true);
drop policy if exists "toevoegen deelnemers" on public.game_players;
create policy "toevoegen deelnemers" on public.game_players for insert to anon with check (true);
drop policy if exists "bijwerken deelnemers" on public.game_players;
create policy "bijwerken deelnemers" on public.game_players for update to anon using (true) with check (true);

-- Punt erbij of eraf. Gebeurt in de database zelf, zodat twee telefoons tegelijk elkaar niet overschrijven.
create or replace function public.adjust_score(p_id uuid, p_delta int)
returns int language sql as $$
  update public.game_players gp
     set score = greatest(0, least(g.target, gp.score + p_delta))
    from public.games g
   where gp.id = p_id and g.id = gp.game_id and g.status = 'active'
  returning gp.score;
$$;

create or replace function public.next_round(p_game uuid)
returns int language sql as $$
  update public.games set round = round + 1
   where id = p_game and status = 'active'
  returning round;
$$;

-- Spel afsluiten: verliezer(s) zoals gekozen, winnaar(s) = laagste score.
create or replace function public.finish_game(p_game uuid, p_losers uuid[])
returns void language plpgsql as $$
declare lowest int;
begin
  select min(score) into lowest from public.game_players
   where game_id = p_game and not (player_id = any(p_losers));
  update public.game_players
     set lost = player_id = any(p_losers),
         won  = score = lowest and not (player_id = any(p_losers))
   where game_id = p_game;
  update public.games set status = 'finished', ended_at = now()
   where id = p_game and status = 'active';
end;
$$;

grant execute on function public.adjust_score(uuid, int) to anon;
grant execute on function public.next_round(uuid) to anon;
grant execute on function public.finish_game(uuid, uuid[]) to anon;
