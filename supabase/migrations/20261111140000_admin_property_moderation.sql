-- Zarvique admin moderation permissions.
-- Apply after 20261111000000_create_properties.sql.
-- Only a trusted project administrator may set app_metadata.role = 'admin'.
-- Never use user_metadata for authorization: users can edit their own user metadata.

create or replace function public.is_zarvique_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

drop policy if exists "Admins can view all properties" on public.properties;
create policy "Admins can view all properties"
  on public.properties for select
  to authenticated
  using (public.is_zarvique_admin());

-- Restrict authenticated updates to the status column only. The existing owner
-- policy still limits owners to their own pending records; admins can moderate
-- pending records through the policy below.
revoke update on public.properties from authenticated;
grant update (status) on public.properties to authenticated;

drop policy if exists "Admins can moderate pending properties" on public.properties;
create policy "Admins can moderate pending properties"
  on public.properties for update
  to authenticated
  using (public.is_zarvique_admin() and status = 'pending')
  with check (public.is_zarvique_admin() and status in ('published', 'rejected'));
