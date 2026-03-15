-- UFT 27 (Ultimate Futsal Team) - Supabase schema bootstrap
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
  id uuid primary key references public.player_accounts(id) on delete cascade,
  username text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

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

revoke all on public.player_accounts from anon, authenticated;
revoke all on public.profiles from anon, authenticated;

grant execute on function public.register_player(text, text) to anon, authenticated;
grant execute on function public.authenticate_player(text, text) to anon, authenticated;
