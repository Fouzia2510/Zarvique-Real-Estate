-- Zarvique member profiles: role-specific profile data with owner-only access.
-- Run this migration once in the Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text not null default '',
  country text not null default 'Pakistan',
  city text not null default '',
  account_type text not null default 'buyer_renter'
    check (account_type in ('owner_seller','buyer_renter','agent_dealer','investor','builder_contractor','architect_engineer','company_firm','supplier_service')),
  business_name text,
  profile_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_account_type_idx on public.profiles(account_type);
alter table public.profiles enable row level security;
grant select, insert, update on public.profiles to authenticated;

drop policy if exists "Members can view their own profile" on public.profiles;
create policy "Members can view their own profile" on public.profiles
  for select to authenticated using (auth.uid() = id);
drop policy if exists "Members can create their own profile" on public.profiles;
create policy "Members can create their own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Members can update their own profile" on public.profiles;
create policy "Members can update their own profile" on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create or replace function public.handle_new_zarvique_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
begin
  insert into public.profiles (id, full_name, phone, country, city, account_type, business_name, profile_details)
  values (
    new.id,
    coalesce(meta->>'full_name', ''),
    coalesce(meta->>'phone', ''),
    coalesce(meta->>'country', 'Pakistan'),
    coalesce(meta->>'city', ''),
    case when meta->>'account_type' in ('owner_seller','buyer_renter','agent_dealer','investor','builder_contractor','architect_engineer','company_firm','supplier_service')
      then meta->>'account_type' else 'buyer_renter' end,
    nullif(meta->>'business_name',''),
    case when jsonb_typeof(meta->'profile_details')='object' then meta->'profile_details' else '{}'::jsonb end
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_zarvique on auth.users;
create trigger on_auth_user_created_zarvique
after insert on auth.users
for each row execute procedure public.handle_new_zarvique_user();

-- Backfill accounts created before this profile table existed.
insert into public.profiles (id, full_name, phone, country, city, account_type, business_name, profile_details)
select
  u.id,
  coalesce(u.raw_user_meta_data->>'full_name',''),
  coalesce(u.raw_user_meta_data->>'phone',''),
  coalesce(u.raw_user_meta_data->>'country','Pakistan'),
  coalesce(u.raw_user_meta_data->>'city',''),
  case when u.raw_user_meta_data->>'account_type' in ('owner_seller','buyer_renter','agent_dealer','investor','builder_contractor','architect_engineer','company_firm','supplier_service')
    then u.raw_user_meta_data->>'account_type' else 'buyer_renter' end,
  nullif(u.raw_user_meta_data->>'business_name',''),
  case when jsonb_typeof(u.raw_user_meta_data->'profile_details')='object' then u.raw_user_meta_data->'profile_details' else '{}'::jsonb end
from auth.users u
on conflict (id) do nothing;

create or replace function public.set_profile_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end;
$$;
drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at before update on public.profiles
for each row execute function public.set_profile_updated_at();
