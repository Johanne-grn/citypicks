-- =====================================================================
-- CityPick's · Base de données Supabase
-- À coller dans Supabase > SQL Editor > New query, puis "Run".
-- Crée les tables, la sécurité (Row Level Security) et les fonctions.
-- =====================================================================

-- ---------- Tables ----------

-- Le catalogue des spots (public en lecture)
create table if not exists public.spots (
  id                text primary key,
  city              text not null check (city in ('paris','lisbonne','barcelone','rome','berlin','amsterdam')),
  name              text not null,
  cat               text not null check (cat in ('Restaurant','Activité','Bar & nuit','Culture')),
  price             text not null check (price in ('free','p1','p2','p3')),
  hood              text not null default '',
  address           text not null default '',
  "desc"            text not null default '',
  tip               text not null default '',
  pick              boolean not null default false,
  photo             text not null default '',
  credit            text not null default '',
  source            text not null default '',
  proposed_by_name  text,
  created_at        timestamptz not null default now()
);

-- Le profil de chaque utilisateur (créé automatiquement à l'inscription)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  pseudo      text not null check (char_length(pseudo) between 2 and 30),
  home_city   text,
  consent_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- Les favoris : un utilisateur + un spot
create table if not exists public.favorites (
  user_id     uuid not null references auth.users(id) on delete cascade,
  spot_id     text not null references public.spots(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, spot_id)
);

-- Les propositions de spots envoyées par les utilisateurs
create table if not exists public.proposals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  address     text not null check (char_length(address) between 1 and 120),
  city        text not null check (city in ('paris','lisbonne','barcelone','rome','berlin','amsterdam')),
  hood        text not null default '',
  cat         text not null check (cat in ('Restaurant','Activité','Bar & nuit','Culture')),
  price       text not null check (price in ('free','p1','p2','p3')),
  "desc"      text not null check (char_length("desc") between 1 and 300),
  status      text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at  timestamptz not null default now()
);

-- La liste des administrateurs (l'équipe CityPick's)
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

-- ---------- Fonctions ----------

-- Vrai si l'utilisateur connecté est administrateur
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;

-- Crée le profil automatiquement à l'inscription, à partir des infos du formulaire
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, pseudo, home_city)
  values (
    new.id,
    coalesce(nullif(left(trim(new.raw_user_meta_data->>'pseudo'), 30), ''), 'Voyageur'),
    new.raw_user_meta_data->>'home_city'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Permet à un utilisateur de supprimer son propre compte (et, en cascade, ses données)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Non connecté'; end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------- Sécurité : Row Level Security ----------

alter table public.spots     enable row level security;
alter table public.profiles  enable row level security;
alter table public.favorites enable row level security;
alter table public.proposals enable row level security;
alter table public.admins    enable row level security;

-- Spots : tout le monde lit, seuls les admins écrivent
drop policy if exists "spots lisibles par tous" on public.spots;
create policy "spots lisibles par tous" on public.spots for select to anon, authenticated using (true);
drop policy if exists "spots modifiables par les admins" on public.spots;
create policy "spots modifiables par les admins" on public.spots for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- Profils : chacun voit et modifie le sien ; les admins lisent tout (pour la modération)
drop policy if exists "profil : lecture" on public.profiles;
create policy "profil : lecture" on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
drop policy if exists "profil : modification" on public.profiles;
create policy "profil : modification" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Favoris : uniquement les siens
drop policy if exists "favoris : les siens" on public.favorites;
create policy "favoris : les siens" on public.favorites for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Propositions : l'auteur voit les siennes, les admins voient tout
drop policy if exists "propositions : lecture" on public.proposals;
create policy "propositions : lecture" on public.proposals for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
drop policy if exists "propositions : création" on public.proposals;
create policy "propositions : création" on public.proposals for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
drop policy if exists "propositions : modération" on public.proposals;
create policy "propositions : modération" on public.proposals for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "propositions : suppression" on public.proposals;
create policy "propositions : suppression" on public.proposals for delete to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- Admins : chacun peut seulement vérifier s'il est admin (la liste se gère dans le SQL Editor)
drop policy if exists "admins : soi-même" on public.admins;
create policy "admins : soi-même" on public.admins for select to authenticated
  using (user_id = auth.uid());
