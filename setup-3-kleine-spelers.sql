-- Stap 3: kleine spelers bijhouden
-- Plak dit in Supabase > SQL Editor (nieuwe snippet) en klik op Run. Je kunt het veilig vaker draaien.

-- small_current: de teller op het scherm (kan je terugzetten naar 0).
-- small_total:   hoe vaak iemand in dit potje in totaal niet is meegegaan (voor de statistieken).
alter table public.game_players add column if not exists small_current int not null default 0;
alter table public.game_players add column if not exists small_total int not null default 0;

-- Kleine speler erbij: teller én totaal gaan omhoog.
create or replace function public.add_small(p_id uuid)
returns int language sql as $$
  update public.game_players gp
     set small_current = gp.small_current + 1,
         small_total = gp.small_total + 1
    from public.games g
   where gp.id = p_id and g.id = gp.game_id and g.status = 'active'
  returning gp.small_current;
$$;

-- Teller terug naar 0 (het totaal blijft staan).
create or replace function public.reset_small(p_id uuid)
returns int language sql as $$
  update public.game_players gp
     set small_current = 0
    from public.games g
   where gp.id = p_id and g.id = gp.game_id and g.status = 'active'
  returning gp.small_current;
$$;

grant execute on function public.add_small(uuid) to anon;
grant execute on function public.reset_small(uuid) to anon;
