-- Admin console: prompt instruction columns, admin read access, member directory.

alter table public.ai_prompt_versions
  add column if not exists coach_instruction text,
  add column if not exists plan_instruction text;

update public.ai_prompt_versions
set
  coach_instruction = coalesce(
    coach_instruction,
    'Return JSON with keys: message, requires_confirmation, actions (array of {type, target_id, changes}).'
  ),
  plan_instruction = coalesce(
    plan_instruction,
    'Create a structured workout plan and meal outline using only provided exercise and food IDs.'
  );

drop policy if exists profiles_select_admin on public.profiles;
create policy profiles_select_admin on public.profiles
  for select to authenticated using (private.is_admin());

drop policy if exists fitness_goals_select_admin on public.fitness_goals;
create policy fitness_goals_select_admin on public.fitness_goals
  for select to authenticated using (private.is_admin());

drop policy if exists body_metrics_select_admin on public.body_metrics;
create policy body_metrics_select_admin on public.body_metrics
  for select to authenticated using (private.is_admin());

drop policy if exists workout_plans_select_admin on public.workout_plans;
create policy workout_plans_select_admin on public.workout_plans
  for select to authenticated using (private.is_admin());

drop policy if exists ai_conversations_select_admin on public.ai_conversations;
create policy ai_conversations_select_admin on public.ai_conversations
  for select to authenticated using (private.is_admin());

drop policy if exists ai_messages_select_admin on public.ai_messages;
create policy ai_messages_select_admin on public.ai_messages
  for select to authenticated using (private.is_admin());

create or replace function public.admin_list_members()
returns table (
  user_id uuid,
  email text,
  display_name text,
  role text,
  onboarding_completed_at timestamptz,
  created_at timestamptz,
  last_sign_in_at timestamptz,
  coach_calls bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    p.user_id,
    u.email,
    p.display_name,
    p.role,
    p.onboarding_completed_at,
    p.created_at,
    u.last_sign_in_at,
    coalesce((
      select count(*)::bigint from public.ai_usage usage where usage.user_id = p.user_id
    ), 0)
  from public.profiles p
  join auth.users u on u.id = p.user_id
  where private.is_admin();
$$;

revoke all on function public.admin_list_members() from public, anon;
grant execute on function public.admin_list_members() to authenticated;
