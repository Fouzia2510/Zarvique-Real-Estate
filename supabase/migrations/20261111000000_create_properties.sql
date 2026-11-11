-- Zarvique property marketplace: first persistent listing table.
-- Run this migration in Supabase SQL Editor on the Zarvique project.

create table if not exists public.properties (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  title text not null check (char_length(title) between 3 and 90),
  city text not null check (char_length(city) between 2 and 60),
  area text not null check (char_length(area) between 2 and 90),
  property_type text not null check (property_type in ('House', 'Apartment', 'Plot', 'Commercial')),
  purpose text not null check (purpose in ('sale', 'rent')),
  price numeric(14, 2) not null check (price > 0),
  size text not null check (char_length(size) between 1 and 40),
  bedrooms integer not null default 0 check (bedrooms between 0 and 50),
  bathrooms integer not null default 0 check (bathrooms between 0 and 50),
  contact_phone text check (contact_phone is null or char_length(contact_phone) <= 30),
  description text check (description is null or char_length(description) <= 600),
  photo_url text,
  status text not null default 'pending' check (status in ('pending', 'published', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists properties_status_created_at_idx
  on public.properties (status, created_at desc);

create index if not exists properties_user_id_created_at_idx
  on public.properties (user_id, created_at desc);

alter table public.properties enable row level security;

grant select on public.properties to anon, authenticated;
grant insert, update, delete on public.properties to authenticated;

drop policy if exists "Public can view published properties" on public.properties;
create policy "Public can view published properties"
  on public.properties for select
  to anon, authenticated
  using (status = 'published');

drop policy if exists "Owners can view their own properties" on public.properties;
create policy "Owners can view their own properties"
  on public.properties for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Authenticated users can submit pending properties" on public.properties;
create policy "Authenticated users can submit pending properties"
  on public.properties for insert
  to authenticated
  with check (auth.uid() = user_id and status = 'pending');

drop policy if exists "Owners can update their own pending properties" on public.properties;
create policy "Owners can update their own pending properties"
  on public.properties for update
  to authenticated
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id and status = 'pending');

drop policy if exists "Owners can delete their own pending properties" on public.properties;
create policy "Owners can delete their own pending properties"
  on public.properties for delete
  to authenticated
  using (auth.uid() = user_id and status = 'pending');

-- Keep updated_at current on edits.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_properties_updated_at on public.properties;
create trigger set_properties_updated_at
before update on public.properties
for each row execute function public.set_updated_at();
