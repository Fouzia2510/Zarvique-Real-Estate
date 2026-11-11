-- Zarvique: strengthen duplicate protection and keep duplicate feedback explicit.
-- A matching pending or published listing by the same owner cannot be submitted again.
-- Rejected listings may be resubmitted after correction.

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
      and p.status in ('pending', 'published')
      and lower(btrim(p.title)) = lower(btrim(new.title))
      and lower(btrim(p.city)) = lower(btrim(new.city))
      and lower(btrim(p.area)) = lower(btrim(new.area))
      and p.property_type = new.property_type
      and p.purpose = new.purpose
      and p.price = new.price
      and lower(btrim(p.size)) = lower(btrim(new.size))
  ) then
    raise exception 'DUPLICATE_PROPERTY: This same property has already been submitted. It was not added again.'
      using errcode = '23505';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_duplicate_pending_property on public.properties;
create trigger prevent_duplicate_pending_property
before insert on public.properties
for each row execute function public.prevent_duplicate_pending_property();
