-- Zarvique public agent directory with explicit opt-in.
-- Run once in the Supabase SQL Editor.

create table if not exists public.agent_public_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  display_name text not null,
  agency_name text,
  city text not null,
  service_areas text[] not null default '{}',
  specialties text[] not null default '{}',
  experience_years integer check (experience_years between 0 and 60),
  bio text,
  public_phone text,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists agent_public_profiles_published_city_idx
  on public.agent_public_profiles(is_published, city);

alter table public.agent_public_profiles enable row level security;
grant select, insert, update on public.agent_public_profiles to anon, authenticated;
grant insert, update on public.agent_public_profiles to authenticated;

drop policy if exists "Anyone can view published agent profiles" on public.agent_public_profiles;
create policy "Anyone can view published agent profiles" on public.agent_public_profiles
  for select to anon, authenticated using (is_published = true);

drop policy if exists "Agents can view their own directory profile" on public.agent_public_profiles;
create policy "Agents can view their own directory profile" on public.agent_public_profiles
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists "Agents can create their own directory profile" on public.agent_public_profiles;
create policy "Agents can create their own directory profile" on public.agent_public_profiles
  for insert to authenticated
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_type = 'agent_dealer'
    )
  );

drop policy if exists "Agents can update their own directory profile" on public.agent_public_profiles;
create policy "Agents can update their own directory profile" on public.agent_public_profiles
  for update to authenticated
  using (
    auth.uid() = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_type = 'agent_dealer'
    )
  )
  with check (
    auth.uid() = user_id
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.account_type = 'agent_dealer'
    )
  );

create or replace function public.set_agent_public_profile_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_agent_public_profiles_updated_at on public.agent_public_profiles;
create trigger set_agent_public_profiles_updated_at
before update on public.agent_public_profiles
for each row execute function public.set_agent_public_profile_updated_at();
