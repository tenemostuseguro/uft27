-- UFT 27 (Ultimate Futsal Team) - Supabase schema bootstrap / migration
-- Ejecutar en SQL Editor de Supabase.

create extension if not exists pgcrypto;

create table if not exists public.player_accounts (
  id uuid primary key default gen_random_uuid(),
  username text not null unique,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key,
  username text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Migración desde versión anterior:
-- si profiles todavía apunta a auth.users, reemplazar el FK para que apunte a player_accounts.
alter table if exists public.profiles
  drop constraint if exists profiles_id_fkey;

alter table if exists public.profiles
  add constraint profiles_id_fkey
  foreign key (id) references public.player_accounts(id) on delete cascade not valid;

-- Limpieza de objetos legacy ligados a auth.users (si existen).
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();

create or replace function public.register_player(p_username text, p_password_hash text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if p_username is null or length(trim(p_username)) < 3 then
    raise exception 'username inválido';
  end if;

  if p_password_hash is null or length(trim(p_password_hash)) = 0 then
    raise exception 'password inválida';
  end if;

  insert into public.player_accounts (username, password_hash)
  values (lower(trim(p_username)), trim(p_password_hash))
  returning id into new_id;

  insert into public.profiles (id, username)
  values (new_id, lower(trim(p_username)));

  return new_id;
exception
  when unique_violation then
    raise exception 'Ese username ya existe';
end;
$$;

create or replace function public.authenticate_player(p_username text, p_password_hash text)
returns table(id uuid, username text)
language sql
security definer
set search_path = public
as $$
  select pa.id, pa.username
  from public.player_accounts pa
  where pa.username = lower(trim(p_username))
    and pa.password_hash = trim(p_password_hash)
  limit 1;
$$;

-- ============================
-- Notificaciones in-game
-- ============================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  header text not null default 'MENSAJE DEL EQUIPO UFT',
  title text not null,
  body text not null,
  image_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  starts_at timestamptz,
  ends_at timestamptz
);

create table if not exists public.player_notification_reads (
  player_id uuid not null references public.player_accounts(id) on delete cascade,
  notification_id uuid not null references public.notifications(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (player_id, notification_id)
);

create index if not exists idx_notifications_active_created_at
  on public.notifications (active, created_at desc);

create index if not exists idx_player_notification_reads_player
  on public.player_notification_reads (player_id, read_at desc);

create or replace function public.list_player_notifications(
  p_player_id uuid,
  p_limit integer default 10
)
returns table(
  id uuid,
  header text,
  title text,
  body text,
  image_url text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select n.id, n.header, n.title, n.body, n.image_url, n.created_at
  from public.notifications n
  where n.active = true
    and (n.starts_at is null or n.starts_at <= now())
    and (n.ends_at is null or n.ends_at > now())
    and not exists (
      select 1
      from public.player_notification_reads r
      where r.player_id = p_player_id
        and r.notification_id = n.id
    )
  order by n.created_at asc
  limit greatest(coalesce(p_limit, 10), 1);
$$;

create or replace function public.mark_player_notification_read(
  p_player_id uuid,
  p_notification_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_player_id is null or p_notification_id is null then
    return false;
  end if;

  insert into public.player_notification_reads(player_id, notification_id)
  values (p_player_id, p_notification_id)
  on conflict (player_id, notification_id) do nothing;

  return true;
end;
$$;



-- ============================
-- Perfil visual (logos/avatar)
-- ============================

create table if not exists public.profile_logos (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  image_url text not null,
  source_type text not null default 'event', -- event | team | default
  is_default boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.player_profile_logo (
  player_id uuid primary key references public.player_accounts(id) on delete cascade,
  logo_id uuid references public.profile_logos(id) on delete set null,
  custom_image_url text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.uft_countries (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  iso_code text not null unique,
  logo_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.uft_leagues (
  id uuid primary key default gen_random_uuid(),
  country_id uuid not null references public.uft_countries(id) on delete cascade,
  name text not null,
  tier_level integer not null default 1,
  logo_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (country_id, name, tier_level)
);

create table if not exists public.uft_clubs (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.uft_leagues(id) on delete cascade,
  name text not null,
  logo_url text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (league_id, name)
);

create table if not exists public.player_profile_club (
  player_id uuid primary key references public.player_accounts(id) on delete cascade,
  club_id uuid references public.uft_clubs(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.profile_logos (code, name, image_url, source_type, is_default, active)
values ('uft_default', 'UFT Default', 'res://assets/default_profile_logo.png', 'default', true, true)
on conflict (code) do update set
  name = excluded.name,
  image_url = excluded.image_url,
  source_type = excluded.source_type,
  is_default = true,
  active = true;

create or replace function public.list_profile_logos()
returns table(id uuid, name text, image_url text, source_type text, is_default boolean)
language sql
security definer
set search_path = public
as $$
  select c.id, c.name, c.logo_url as image_url, 'club'::text as source_type, false as is_default
  from public.uft_clubs c
  where c.active = true
  union all
  select l.id, l.name, l.image_url, l.source_type, l.is_default
  from public.profile_logos l
  where l.active = true and l.is_default = true
  order by is_default desc, source_type asc, name asc;
$$;

create or replace function public.get_player_profile_logo(p_player_id uuid)
returns table(
  logo_id uuid,
  logo_name text,
  logo_image_url text,
  source_type text,
  custom_image_url text,
  resolved_image_url text
)
language sql
security definer
set search_path = public
as $$
  with default_logo as (
    select id, name, image_url, source_type
    from public.profile_logos
    where active = true and is_default = true
    order by created_at asc
    limit 1
  ), selected_logo as (
    select ppc.player_id, ppc.club_id as logo_id, ''::text as custom_image_url,
           c.name, c.logo_url as image_url, 'club'::text as source_type
    from public.player_profile_club ppc
    left join public.uft_clubs c on c.id = ppc.club_id
    where ppc.player_id = p_player_id
    union all
    select ppl.player_id, ppl.logo_id, ppl.custom_image_url,
           pl.name, pl.image_url, pl.source_type
    from public.player_profile_logo ppl
    left join public.profile_logos pl on pl.id = ppl.logo_id
    where ppl.player_id = p_player_id
    limit 1
  )
  select
    coalesce(sl.logo_id, dl.id) as logo_id,
    coalesce(sl.name, dl.name) as logo_name,
    coalesce(sl.image_url, dl.image_url) as logo_image_url,
    coalesce(sl.source_type, dl.source_type) as source_type,
    coalesce(sl.custom_image_url, '') as custom_image_url,
    coalesce(nullif(sl.custom_image_url, ''), sl.image_url, dl.image_url) as resolved_image_url
  from default_logo dl
  left join selected_logo sl on true;
$$;

create or replace function public.set_player_profile_logo(
  p_player_id uuid,
  p_logo_id uuid,
  p_custom_image_url text default ''
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_player_id is null then
    return false;
  end if;

  if exists (select 1 from public.uft_clubs c where c.id = p_logo_id and c.active = true) then
    insert into public.player_profile_club(player_id, club_id, updated_at)
    values (p_player_id, p_logo_id, now())
    on conflict (player_id) do update set
      club_id = excluded.club_id,
      updated_at = now();
    return true;
  end if;

  insert into public.player_profile_logo(player_id, logo_id, custom_image_url, updated_at)
  values (p_player_id, p_logo_id, coalesce(trim(p_custom_image_url), ''), now())
  on conflict (player_id) do update set
    logo_id = excluded.logo_id,
    custom_image_url = excluded.custom_image_url,
    updated_at = now();

  return true;
end;
$$;

create or replace function public.upsert_uft_country(
  p_country_id uuid default null,
  p_name text default '',
  p_iso_code text default '',
  p_logo_url text default '',
  p_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_country_id, gen_random_uuid());
begin
  insert into public.uft_countries(id, name, iso_code, logo_url, active, updated_at)
  values (v_id, nullif(trim(p_name), ''), upper(nullif(trim(p_iso_code), '')), coalesce(trim(p_logo_url), ''), coalesce(p_active, true), now())
  on conflict (id) do update set
    name = excluded.name,
    iso_code = excluded.iso_code,
    logo_url = excluded.logo_url,
    active = excluded.active,
    updated_at = now();
  return v_id;
end;
$$;

create or replace function public.upsert_uft_league(
  p_league_id uuid default null,
  p_country_id uuid default null,
  p_name text default '',
  p_tier_level integer default 1,
  p_logo_url text default '',
  p_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_league_id, gen_random_uuid());
begin
  if p_country_id is null then
    return null;
  end if;
  insert into public.uft_leagues(id, country_id, name, tier_level, logo_url, active, updated_at)
  values (v_id, p_country_id, nullif(trim(p_name), ''), greatest(coalesce(p_tier_level, 1), 1), coalesce(trim(p_logo_url), ''), coalesce(p_active, true), now())
  on conflict (id) do update set
    country_id = excluded.country_id,
    name = excluded.name,
    tier_level = excluded.tier_level,
    logo_url = excluded.logo_url,
    active = excluded.active,
    updated_at = now();
  return v_id;
end;
$$;

create or replace function public.upsert_uft_club(
  p_club_id uuid default null,
  p_league_id uuid default null,
  p_name text default '',
  p_logo_url text default '',
  p_active boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := coalesce(p_club_id, gen_random_uuid());
begin
  if p_league_id is null then
    return null;
  end if;
  insert into public.uft_clubs(id, league_id, name, logo_url, active, updated_at)
  values (v_id, p_league_id, nullif(trim(p_name), ''), coalesce(trim(p_logo_url), ''), coalesce(p_active, true), now())
  on conflict (id) do update set
    league_id = excluded.league_id,
    name = excluded.name,
    logo_url = excluded.logo_url,
    active = excluded.active,
    updated_at = now();
  return v_id;
end;
$$;

create or replace function public.list_uft_countries()
returns table(id uuid, name text, iso_code text, logo_url text, active boolean)
language sql
security definer
set search_path = public
as $$
  select c.id, c.name, c.iso_code, c.logo_url, c.active
  from public.uft_countries c
  order by c.name asc;
$$;

create or replace function public.list_uft_leagues()
returns table(id uuid, country_id uuid, country_name text, name text, tier_level integer, logo_url text, active boolean)
language sql
security definer
set search_path = public
as $$
  select l.id, l.country_id, c.name as country_name, l.name, l.tier_level, l.logo_url, l.active
  from public.uft_leagues l
  join public.uft_countries c on c.id = l.country_id
  order by c.name asc, l.tier_level asc, l.name asc;
$$;

drop function if exists public.list_uft_clubs();
create or replace function public.list_uft_clubs()
returns table(id uuid, league_id uuid, league_name text, league_logo_url text, country_name text, country_logo_url text, name text, logo_url text, active boolean)
language sql
security definer
set search_path = public
as $$
  select cl.id, cl.league_id, l.name as league_name, l.logo_url as league_logo_url, c.name as country_name, c.logo_url as country_logo_url, cl.name, cl.logo_url, cl.active
  from public.uft_clubs cl
  join public.uft_leagues l on l.id = cl.league_id
  join public.uft_countries c on c.id = l.country_id
  order by c.name asc, l.tier_level asc, l.name asc, cl.name asc;
$$;
revoke all on public.player_accounts from anon, authenticated;
revoke all on public.profiles from anon, authenticated;
revoke all on public.notifications from anon, authenticated;
revoke all on public.player_notification_reads from anon, authenticated;
revoke all on public.profile_logos from anon, authenticated;
revoke all on public.player_profile_logo from anon, authenticated;
revoke all on public.uft_countries from anon, authenticated;
revoke all on public.uft_leagues from anon, authenticated;
revoke all on public.uft_clubs from anon, authenticated;
revoke all on public.player_profile_club from anon, authenticated;

grant execute on function public.register_player(text, text) to anon, authenticated;
grant execute on function public.authenticate_player(text, text) to anon, authenticated;
grant execute on function public.list_player_notifications(uuid, integer) to anon, authenticated;
grant execute on function public.mark_player_notification_read(uuid, uuid) to anon, authenticated;
grant execute on function public.list_profile_logos() to anon, authenticated;
grant execute on function public.get_player_profile_logo(uuid) to anon, authenticated;
grant execute on function public.set_player_profile_logo(uuid, uuid, text) to anon, authenticated;
grant execute on function public.upsert_uft_country(uuid, text, text, text, boolean) to anon, authenticated;
grant execute on function public.upsert_uft_league(uuid, uuid, text, integer, text, boolean) to anon, authenticated;
grant execute on function public.upsert_uft_club(uuid, uuid, text, text, boolean) to anon, authenticated;
grant execute on function public.list_uft_countries() to anon, authenticated;
grant execute on function public.list_uft_leagues() to anon, authenticated;
grant execute on function public.list_uft_clubs() to anon, authenticated;

-- ============================
-- Ultimate Team (UFT) config + estado persistente
-- ============================

create table if not exists public.uft_config (
  key text primary key,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.uft_club_snapshots (
  player_id uuid primary key references public.player_accounts(id) on delete cascade,
  snapshot jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.uft_config(key, payload) values
  ('base_players', '[]'::jsonb),
  ('cards', '[]'::jsonb),
  ('packs', '[]'::jsonb),
  ('market', '[]'::jsonb),
  ('events', '[]'::jsonb),
  ('season', '{}'::jsonb)
on conflict (key) do nothing;

create or replace function public.list_uft_configs()
returns table(key text, payload jsonb, updated_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select c.key, c.payload, c.updated_at
  from public.uft_config c
  order by c.key asc;
$$;

create or replace function public.save_uft_config(
  p_key text,
  p_payload jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_key is null or trim(p_key) = '' then
    return false;
  end if;

  insert into public.uft_config(key, payload, updated_at)
  values (trim(p_key), coalesce(p_payload, '{}'::jsonb), now())
  on conflict (key) do update set
    payload = excluded.payload,
    updated_at = now();

  return true;
end;
$$;

create or replace function public.get_uft_snapshot(
  p_player_id uuid
)
returns table(snapshot jsonb)
language sql
security definer
set search_path = public
as $$
  select coalesce(s.snapshot, '{}'::jsonb) as snapshot
  from public.uft_club_snapshots s
  where s.player_id = p_player_id
  union all
  select '{}'::jsonb
  where not exists (
    select 1 from public.uft_club_snapshots x where x.player_id = p_player_id
  )
  limit 1;
$$;

create or replace function public.save_uft_snapshot(
  p_player_id uuid,
  p_snapshot jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_player_id is null then
    return false;
  end if;

  insert into public.uft_club_snapshots(player_id, snapshot, updated_at)
  values (p_player_id, coalesce(p_snapshot, '{}'::jsonb), now())
  on conflict (player_id) do update set
    snapshot = excluded.snapshot,
    updated_at = now();

  return true;
end;
$$;

revoke all on public.uft_config from anon, authenticated;
revoke all on public.uft_club_snapshots from anon, authenticated;

grant execute on function public.list_uft_configs() to anon, authenticated;
grant execute on function public.save_uft_config(text, jsonb) to anon, authenticated;
grant execute on function public.get_uft_snapshot(uuid) to anon, authenticated;
grant execute on function public.save_uft_snapshot(uuid, jsonb) to anon, authenticated;

-- ============================
-- Ultimate Team (UFT) catálogos administrables
-- ============================

create table if not exists public.uft_players (
  player_id text primary key,
  name text not null,
  main_position text not null,
  secondary_positions jsonb not null default '[]'::jsonb,
  dominant_foot text,
  nationality text,
  club_id uuid references public.uft_clubs(id) on delete set null,
  club text,
  photo_face_url text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.uft_players add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table public.uft_players add column if not exists club_id uuid references public.uft_clubs(id) on delete set null;

create table if not exists public.uft_cards_catalog (
  card_id text primary key,
  player_id text not null references public.uft_players(player_id) on delete cascade,
  card_type text not null,
  rarity text not null,
  evolution_level integer not null default 1,
  ovr integer not null default 1,
  pace integer not null default 1,
  dribbling integer not null default 1,
  passing integer not null default 1,
  shooting integer not null default 1,
  defense integer not null default 1,
  physical integer not null default 1,
  gk_reflejos integer not null default 1,
  gk_parada integer not null default 1,
  gk_uno_vs_uno integer not null default 1,
  gk_colocacion integer not null default 1,
  gk_juego_pies integer not null default 1,
  gk_fisico integer not null default 1,
  card_frame_url text not null default '',
  face_url text not null default '',
  owned boolean not null default true,
  transferable boolean not null default true,
  locked boolean not null default false,
  suggested_price integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.uft_cards_catalog add column if not exists evolution_level integer not null default 1;
alter table public.uft_cards_catalog add column if not exists owned boolean not null default true;
alter table public.uft_cards_catalog add column if not exists suggested_price integer not null default 0;
alter table public.uft_cards_catalog add column if not exists pace integer not null default 1;
alter table public.uft_cards_catalog add column if not exists dribbling integer not null default 1;
alter table public.uft_cards_catalog add column if not exists passing integer not null default 1;
alter table public.uft_cards_catalog add column if not exists shooting integer not null default 1;
alter table public.uft_cards_catalog add column if not exists defense integer not null default 1;
alter table public.uft_cards_catalog add column if not exists physical integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_reflejos integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_parada integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_uno_vs_uno integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_colocacion integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_juego_pies integer not null default 1;
alter table public.uft_cards_catalog add column if not exists gk_fisico integer not null default 1;

create table if not exists public.uft_card_types_catalog (
  card_type text primary key,
  display_name text not null,
  rarity_default text not null default 'Common',
  style jsonb not null default '{}'::jsonb,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.uft_card_types_catalog(card_type, display_name, rarity_default, style, active)
values
  ('Base', 'Base', 'Common', '{}'::jsonb, true),
  ('Especial', 'Especial', 'Rare', '{}'::jsonb, true),
  ('Evento', 'Evento', 'Epic', '{}'::jsonb, true),
  ('TOTW', 'Team of the Week', 'Epic', '{}'::jsonb, true),
  ('Icono', 'Icono', 'Legendary', '{}'::jsonb, true),
  ('Evolucion', 'Evolución', 'Rare', '{}'::jsonb, true)
on conflict (card_type) do nothing;

create table if not exists public.uft_events_catalog (
  event_id text primary key,
  name text not null,
  description text not null default '',
  start_unix bigint not null,
  end_unix bigint not null,
  active boolean not null default true,
  access_cost_coins integer not null default 0,
  rules jsonb not null default '{}'::jsonb,
  rewards jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.uft_packs_catalog (
  pack_id text primary key,
  name text not null,
  cost_coins integer not null default 0,
  cost_points integer not null default 0,
  cards_count integer not null default 1,
  duplicate_policy text not null default 'allow',
  pool jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.uft_market_catalog (
  listing_id text primary key,
  card_id text not null references public.uft_cards_catalog(card_id) on delete cascade,
  price integer not null default 100,
  start_price integer not null default 100,
  current_bid integer not null default 0,
  buy_now_price integer not null default 1000,
  highest_bidder text not null default '',
  expires_at_unix bigint not null default (extract(epoch from now())::bigint + 7200),
  seller text not null default 'npc_market',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.uft_market_catalog add column if not exists start_price integer not null default 100;
alter table public.uft_market_catalog add column if not exists current_bid integer not null default 0;
alter table public.uft_market_catalog add column if not exists buy_now_price integer not null default 1000;
alter table public.uft_market_catalog add column if not exists highest_bidder text not null default '';
alter table public.uft_market_catalog add column if not exists expires_at_unix bigint not null default (extract(epoch from now())::bigint + 7200);

create table if not exists public.uft_seasons_catalog (
  season_id text primary key,
  name text not null,
  start_unix bigint not null,
  end_unix bigint not null,
  levels jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.upsert_uft_player(
  p_player_id text,
  p_name text,
  p_main_position text,
  p_secondary_positions jsonb default '[]'::jsonb,
  p_dominant_foot text default null,
  p_nationality text default null,
  p_club_id uuid default null,
  p_photo_face_url text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_name text;
begin
  if p_player_id is null or trim(p_player_id) = '' then return false; end if;
  select c.name into v_club_name
  from public.uft_clubs c
  where c.id = p_club_id;

  insert into public.uft_players(player_id, name, main_position, secondary_positions, dominant_foot, nationality, club_id, club, photo_face_url, metadata, updated_at)
  values (
    trim(p_player_id),
    coalesce(p_name, 'Unknown'),
    coalesce(p_main_position, 'P'),
    coalesce(p_secondary_positions, '[]'::jsonb),
    p_dominant_foot,
    p_nationality,
    p_club_id,
    v_club_name,
    coalesce(p_photo_face_url, ''),
    coalesce(p_metadata, '{}'::jsonb),
    now()
  )
  on conflict (player_id) do update set
    name = excluded.name,
    main_position = excluded.main_position,
    secondary_positions = excluded.secondary_positions,
    dominant_foot = excluded.dominant_foot,
    nationality = excluded.nationality,
    club_id = excluded.club_id,
    club = excluded.club,
    photo_face_url = excluded.photo_face_url,
    metadata = excluded.metadata,
    updated_at = now();
  return true;
end;
$$;

-- Compatibilidad con paneles antiguos que enviaban nombre de club en texto libre.
create or replace function public.upsert_uft_player(
  p_player_id text,
  p_name text,
  p_main_position text,
  p_secondary_positions jsonb default '[]'::jsonb,
  p_dominant_foot text default null,
  p_nationality text default null,
  p_club text default null,
  p_photo_face_url text default '',
  p_metadata jsonb default '{}'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_club_id uuid;
begin
  if p_club is not null and trim(p_club) <> '' then
    select c.id into v_club_id
    from public.uft_clubs c
    where lower(c.name) = lower(trim(p_club))
    limit 1;
  end if;

  return public.upsert_uft_player(
    p_player_id,
    p_name,
    p_main_position,
    p_secondary_positions,
    p_dominant_foot,
    p_nationality,
    v_club_id,
    p_photo_face_url,
    p_metadata
  );
end;
$$;

create or replace function public.upsert_uft_card(
  p_card_id text,
  p_player_id text,
  p_card_type text,
  p_rarity text,
  p_ovr integer,
  p_pace integer,
  p_dribbling integer,
  p_passing integer,
  p_shooting integer,
  p_defense integer,
  p_physical integer,
  p_gk_reflejos integer,
  p_gk_parada integer,
  p_gk_uno_vs_uno integer,
  p_gk_colocacion integer,
  p_gk_juego_pies integer,
  p_gk_fisico integer,
  p_card_frame_url text,
  p_face_url text,
  p_transferable boolean default true,
  p_locked boolean default false,
  p_evolution_level integer default 1,
  p_owned boolean default true,
  p_suggested_price integer default 0
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_card_id is null or trim(p_card_id) = '' or p_player_id is null or trim(p_player_id) = '' then return false; end if;
  insert into public.uft_cards_catalog(card_id, player_id, card_type, rarity, evolution_level, ovr, pace, dribbling, passing, shooting, defense, physical, gk_reflejos, gk_parada, gk_uno_vs_uno, gk_colocacion, gk_juego_pies, gk_fisico, card_frame_url, face_url, owned, transferable, locked, suggested_price, updated_at)
  values (
    trim(p_card_id),
    trim(p_player_id),
    coalesce(p_card_type, 'Base'),
    coalesce(p_rarity, 'Common'),
    greatest(coalesce(p_evolution_level, 1), 1),
    greatest(coalesce(p_ovr, 1),1),
    greatest(coalesce(p_pace, 1), 1),
    greatest(coalesce(p_dribbling, 1), 1),
    greatest(coalesce(p_passing, 1), 1),
    greatest(coalesce(p_shooting, 1), 1),
    greatest(coalesce(p_defense, 1), 1),
    greatest(coalesce(p_physical, 1), 1),
    greatest(coalesce(p_gk_reflejos, 1), 1),
    greatest(coalesce(p_gk_parada, 1), 1),
    greatest(coalesce(p_gk_uno_vs_uno, 1), 1),
    greatest(coalesce(p_gk_colocacion, 1), 1),
    greatest(coalesce(p_gk_juego_pies, 1), 1),
    greatest(coalesce(p_gk_fisico, 1), 1),
    coalesce(p_card_frame_url, ''),
    coalesce(p_face_url, ''),
    coalesce(p_owned, true),
    coalesce(p_transferable, true),
    coalesce(p_locked, false),
    greatest(coalesce(p_suggested_price, 0), 0),
    now()
  )
  on conflict (card_id) do update set
    player_id = excluded.player_id,
    card_type = excluded.card_type,
    rarity = excluded.rarity,
    evolution_level = excluded.evolution_level,
    ovr = excluded.ovr,
    pace = excluded.pace,
    dribbling = excluded.dribbling,
    passing = excluded.passing,
    shooting = excluded.shooting,
    defense = excluded.defense,
    physical = excluded.physical,
    gk_reflejos = excluded.gk_reflejos,
    gk_parada = excluded.gk_parada,
    gk_uno_vs_uno = excluded.gk_uno_vs_uno,
    gk_colocacion = excluded.gk_colocacion,
    gk_juego_pies = excluded.gk_juego_pies,
    gk_fisico = excluded.gk_fisico,
    card_frame_url = excluded.card_frame_url,
    face_url = excluded.face_url,
    owned = excluded.owned,
    transferable = excluded.transferable,
    locked = excluded.locked,
    suggested_price = excluded.suggested_price,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.upsert_uft_card_type(
  p_card_type text,
  p_display_name text,
  p_rarity_default text default 'Common',
  p_style jsonb default '{}'::jsonb,
  p_active boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_card_type is null or trim(p_card_type) = '' then return false; end if;
  insert into public.uft_card_types_catalog(card_type, display_name, rarity_default, style, active, updated_at)
  values (trim(p_card_type), coalesce(nullif(trim(p_display_name), ''), trim(p_card_type)), coalesce(nullif(trim(p_rarity_default), ''), 'Common'), coalesce(p_style, '{}'::jsonb), coalesce(p_active, true), now())
  on conflict (card_type) do update set
    display_name = excluded.display_name,
    rarity_default = excluded.rarity_default,
    style = excluded.style,
    active = excluded.active,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.upsert_uft_event(
  p_event_id text,
  p_name text,
  p_description text,
  p_start_unix bigint,
  p_end_unix bigint,
  p_active boolean default true,
  p_access_cost_coins integer default 0,
  p_rules jsonb default '{}'::jsonb,
  p_rewards jsonb default '[]'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event_id is null or trim(p_event_id) = '' then return false; end if;
  insert into public.uft_events_catalog(event_id, name, description, start_unix, end_unix, active, access_cost_coins, rules, rewards, updated_at)
  values (trim(p_event_id), coalesce(p_name, 'Evento'), coalesce(p_description, ''), coalesce(p_start_unix, 0), coalesce(p_end_unix, 0), coalesce(p_active, true), greatest(coalesce(p_access_cost_coins,0),0), coalesce(p_rules, '{}'::jsonb), coalesce(p_rewards, '[]'::jsonb), now())
  on conflict (event_id) do update set
    name = excluded.name,
    description = excluded.description,
    start_unix = excluded.start_unix,
    end_unix = excluded.end_unix,
    active = excluded.active,
    access_cost_coins = excluded.access_cost_coins,
    rules = excluded.rules,
    rewards = excluded.rewards,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.upsert_uft_pack(
  p_pack_id text,
  p_name text,
  p_cost_coins integer default 0,
  p_cost_points integer default 0,
  p_cards_count integer default 1,
  p_duplicate_policy text default 'allow',
  p_pool jsonb default '[]'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_pack_id is null or trim(p_pack_id) = '' then return false; end if;
  insert into public.uft_packs_catalog(pack_id, name, cost_coins, cost_points, cards_count, duplicate_policy, pool, updated_at)
  values (trim(p_pack_id), coalesce(p_name, 'Sobre'), greatest(coalesce(p_cost_coins, 0), 0), greatest(coalesce(p_cost_points, 0), 0), greatest(coalesce(p_cards_count, 1), 1), coalesce(p_duplicate_policy, 'allow'), coalesce(p_pool, '[]'::jsonb), now())
  on conflict (pack_id) do update set
    name = excluded.name,
    cost_coins = excluded.cost_coins,
    cost_points = excluded.cost_points,
    cards_count = excluded.cards_count,
    duplicate_policy = excluded.duplicate_policy,
    pool = excluded.pool,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.upsert_uft_market_listing(
  p_listing_id text,
  p_card_id text,
  p_price integer default 100,
  p_start_price integer default 100,
  p_current_bid integer default 0,
  p_buy_now_price integer default 1000,
  p_highest_bidder text default '',
  p_expires_at_unix bigint default null,
  p_seller text default 'npc_market',
  p_active boolean default true
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_listing_id is null or trim(p_listing_id) = '' or p_card_id is null or trim(p_card_id) = '' then return false; end if;
  insert into public.uft_market_catalog(listing_id, card_id, price, start_price, current_bid, buy_now_price, highest_bidder, expires_at_unix, seller, active, updated_at)
  values (
    trim(p_listing_id),
    trim(p_card_id),
    greatest(coalesce(p_price, 100), 100),
    greatest(coalesce(p_start_price, p_price, 100), 100),
    greatest(coalesce(p_current_bid, 0), 0),
    greatest(coalesce(p_buy_now_price, p_start_price, p_price, 1000), 100),
    coalesce(p_highest_bidder, ''),
    coalesce(p_expires_at_unix, extract(epoch from now())::bigint + 7200),
    coalesce(nullif(trim(p_seller), ''), 'npc_market'),
    coalesce(p_active, true),
    now()
  )
  on conflict (listing_id) do update set
    card_id = excluded.card_id,
    price = excluded.price,
    start_price = excluded.start_price,
    current_bid = excluded.current_bid,
    buy_now_price = excluded.buy_now_price,
    highest_bidder = excluded.highest_bidder,
    expires_at_unix = excluded.expires_at_unix,
    seller = excluded.seller,
    active = excluded.active,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.upsert_uft_season(
  p_season_id text,
  p_name text,
  p_start_unix bigint,
  p_end_unix bigint,
  p_levels jsonb default '[]'::jsonb
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_season_id is null or trim(p_season_id) = '' then return false; end if;
  insert into public.uft_seasons_catalog(season_id, name, start_unix, end_unix, levels, updated_at)
  values (trim(p_season_id), coalesce(p_name, 'Temporada'), coalesce(p_start_unix, 0), coalesce(p_end_unix, 0), coalesce(p_levels, '[]'::jsonb), now())
  on conflict (season_id) do update set
    name = excluded.name,
    start_unix = excluded.start_unix,
    end_unix = excluded.end_unix,
    levels = excluded.levels,
    updated_at = now();
  return true;
end;
$$;

create or replace function public.list_uft_players()
returns setof public.uft_players
language sql
security definer
set search_path = public
as $$ select * from public.uft_players order by updated_at desc; $$;

create or replace function public.list_uft_cards()
returns setof public.uft_cards_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_cards_catalog order by updated_at desc; $$;

create or replace function public.list_uft_events()
returns setof public.uft_events_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_events_catalog order by updated_at desc; $$;

create or replace function public.list_uft_card_types()
returns setof public.uft_card_types_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_card_types_catalog order by updated_at desc; $$;

create or replace function public.list_uft_packs()
returns setof public.uft_packs_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_packs_catalog order by updated_at desc; $$;

create or replace function public.list_uft_market_listings()
returns setof public.uft_market_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_market_catalog order by expires_at_unix asc, updated_at desc; $$;

create or replace function public.list_uft_seasons()
returns setof public.uft_seasons_catalog
language sql
security definer
set search_path = public
as $$ select * from public.uft_seasons_catalog order by updated_at desc; $$;

revoke all on public.uft_players from anon, authenticated;
revoke all on public.uft_cards_catalog from anon, authenticated;
revoke all on public.uft_events_catalog from anon, authenticated;
revoke all on public.uft_packs_catalog from anon, authenticated;
revoke all on public.uft_market_catalog from anon, authenticated;
revoke all on public.uft_seasons_catalog from anon, authenticated;
revoke all on public.uft_card_types_catalog from anon, authenticated;

grant execute on function public.upsert_uft_player(text, text, text, jsonb, text, text, uuid, text, jsonb) to anon, authenticated;
grant execute on function public.upsert_uft_player(text, text, text, jsonb, text, text, text, text, jsonb) to anon, authenticated;
grant execute on function public.upsert_uft_card(text, text, text, text, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, text, text, boolean, boolean, integer, boolean, integer) to anon, authenticated;
grant execute on function public.upsert_uft_card_type(text, text, text, jsonb, boolean) to anon, authenticated;
grant execute on function public.upsert_uft_event(text, text, text, bigint, bigint, boolean, integer, jsonb, jsonb) to anon, authenticated;
grant execute on function public.upsert_uft_pack(text, text, integer, integer, integer, text, jsonb) to anon, authenticated;
grant execute on function public.upsert_uft_market_listing(text, text, integer, integer, integer, integer, text, bigint, text, boolean) to anon, authenticated;
grant execute on function public.upsert_uft_season(text, text, bigint, bigint, jsonb) to anon, authenticated;
grant execute on function public.list_uft_players() to anon, authenticated;
grant execute on function public.list_uft_cards() to anon, authenticated;
grant execute on function public.list_uft_card_types() to anon, authenticated;
grant execute on function public.list_uft_events() to anon, authenticated;
grant execute on function public.list_uft_packs() to anon, authenticated;
grant execute on function public.list_uft_market_listings() to anon, authenticated;
grant execute on function public.list_uft_seasons() to anon, authenticated;
