-- Zarvique admin review access for private project enquiries.
-- Admin authorization is based only on trusted app_metadata.role.

drop policy if exists "Admins can view all project enquiries" on public.project_enquiries;
create policy "Admins can view all project enquiries"
  on public.project_enquiries for select
  to authenticated
  using (public.is_zarvique_admin());

grant update (status) on public.project_enquiries to authenticated;

drop policy if exists "Admins can update project enquiry status" on public.project_enquiries;
create policy "Admins can update project enquiry status"
  on public.project_enquiries for update
  to authenticated
  using (public.is_zarvique_admin())
  with check (
    public.is_zarvique_admin()
    and status in ('submitted', 'reviewing', 'closed')
  );
