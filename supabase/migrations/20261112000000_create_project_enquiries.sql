-- Zarvique project enquiry intake. Enquiries are private to their submitting member.
create table if not exists public.project_enquiries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  project_name text not null check (char_length(project_name) between 3 and 120),
  project_type text not null check (project_type in ('new_build', 'renovation', 'commercial', 'residential_development', 'other')),
  city text not null check (char_length(city) between 2 and 80),
  area text check (area is null or char_length(area) <= 120),
  property_status text not null check (property_status in ('owned', 'under_purchase', 'looking_for_property', 'other')),
  plot_size text check (plot_size is null or char_length(plot_size) <= 60),
  budget_range text check (budget_range is null or char_length(budget_range) <= 80),
  timeline text not null check (timeline in ('within_3_months', '3_to_6_months', '6_to_12_months', 'planning_only')),
  professionals_needed text[] not null default '{}',
  description text check (description is null or char_length(description) <= 1500),
  contact_phone text check (contact_phone is null or char_length(contact_phone) <= 30),
  status text not null default 'submitted' check (status in ('submitted', 'reviewing', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists project_enquiries_user_created_idx
  on public.project_enquiries (user_id, created_at desc);

alter table public.project_enquiries enable row level security;
grant select, insert on public.project_enquiries to authenticated;

drop policy if exists "Members can view their own project enquiries" on public.project_enquiries;
create policy "Members can view their own project enquiries"
  on public.project_enquiries for select
  to authenticated using (auth.uid() = user_id);

drop policy if exists "Members can submit their own project enquiries" on public.project_enquiries;
create policy "Members can submit their own project enquiries"
  on public.project_enquiries for insert
  to authenticated with check (auth.uid() = user_id and status = 'submitted');

drop trigger if exists set_project_enquiries_updated_at on public.project_enquiries;
create trigger set_project_enquiries_updated_at
before update on public.project_enquiries
for each row execute function public.set_updated_at();
