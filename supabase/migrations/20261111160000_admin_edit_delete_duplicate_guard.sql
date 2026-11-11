-- Zarvique admin editing, deletion and duplicate-submission protection.
-- Apply after the existing property and admin moderation migrations.

-- Replace the status-only admin update rule with a full admin editing rule.
drop policy if exists "Admins can moderate pending properties" on public.properties;
drop policy if exists "Admins can edit properties" on public.properties;
create policy "Admins can edit properties"
  on public.properties for update
  to authenticated
  using (public.is_zarvique_admin())
  with check (public.is_zarvique_admin());

-- Authenticated owners retain the existing RLS-limited ability to edit their
-- own pending submissions. Admins can edit all listing fields via their policy.
revoke update on public.properties from authenticated;
grant update (
  title, city, area, property_type, purpose, price, size,
  bedrooms, bathrooms, contact_phone, description, status
) on public.properties to authenticated;

drop policy if exists "Admins can delete pending properties" on public.properties;
create policy "Admins can delete pending properties"
  on public.properties for delete
  to authenticated
  using (public.is_zarvique_admin() and status = 'pending');

-- Prevent the same signed-in owner from submitting an identical pending
-- property repeatedly within 24 hours. An advisory lock closes the race where
-- two identical submissions arrive at nearly the same time.
create or replace function public.prevent_duplicate_pending_property()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  owner_id uuid := auth.uid();
  duplicate_key text;
begin
  if owner_id is null then
    raise exception 'You must be signed in to submit a property.'
      using errcode = '42501';
  end if;

  duplicate_key := concat_ws('|',
    owner_id::text,
    lower(btrim(new.title)),
    lower(btrim(new.city)),
    lower(btrim(new.area)),
    new.property_type,
    new.purpose,
    new.price::text,
    lower(btrim(new.size))
  );

  perform pg_advisory_xact_lock(hashtextextended(duplicate_key, 0));

  if exists (
    select 1
    from public.properties p
    where p.user_id = owner_id
      and p.status = 'pending'
      and p.created_at >= now() - interval '24 hours'
      and lower(btrim(p.title)) = lower(btrim(new.title))
      and lower(btrim(p.city)) = lower(btrim(new.city))
      and lower(btrim(p.area)) = lower(btrim(new.area))
      and p.property_type = new.property_type
      and p.purpose = new.purpose
      and p.price = new.price
      and lower(btrim(p.size)) = lower(btrim(new.size))
  ) then
    raise exception 'A similar pending property was already submitted in the last 24 hours. Please do not submit it again.'
      using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_duplicate_pending_property on public.properties;
create trigger prevent_duplicate_pending_property
before insert on public.properties
for each row execute function public.prevent_duplicate_pending_property();
