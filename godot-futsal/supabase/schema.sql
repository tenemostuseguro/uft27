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

revoke all on public.player_accounts from anon, authenticated;
revoke all on public.profiles from anon, authenticated;
revoke all on public.notifications from anon, authenticated;
revoke all on public.player_notification_reads from anon, authenticated;

grant execute on function public.register_player(text, text) to anon, authenticated;
grant execute on function public.authenticate_player(text, text) to anon, authenticated;
grant execute on function public.list_player_notifications(uuid, integer) to anon, authenticated;
grant execute on function public.mark_player_notification_read(uuid, uuid) to anon, authenticated;
