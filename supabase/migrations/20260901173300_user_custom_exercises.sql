alter table public.exercises
  add column user_id uuid references auth.users (id) on delete cascade;

alter table public.exercises drop constraint exercises_name_key;

create unique index exercises_catalog_name_key
  on public.exercises (lower(name))
  where user_id is null;

create unique index exercises_user_name_key
  on public.exercises (user_id, lower(name))
  where user_id is not null;

create index exercises_user_id_idx on public.exercises (user_id)
  where user_id is not null;

drop policy if exists exercises_select on public.exercises;

create policy exercises_select on public.exercises
  for select to authenticated
  using (
    (is_active and (user_id is null or user_id = (select auth.uid())))
    or private.is_admin()
  );

create policy exercises_insert_own on public.exercises
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy exercises_update_own on public.exercises
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy exercises_delete_own on public.exercises
  for delete to authenticated
  using (user_id = (select auth.uid()));
