-- FitMate initial schema, RLS, private RPCs, storage.

create extension if not exists pg_trgm;
create extension if not exists pgcrypto;

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
grant usage on schema private to postgres;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.user_id = (select auth.uid())
      and p.role = 'admin'
  );
$$;

create or replace function private.current_user_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select (select auth.uid());
$$;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  display_name text,
  age integer check (age is null or (age between 13 and 100)),
  sex text check (sex is null or sex in ('male', 'female', 'other')),
  height_cm numeric(5, 1) check (height_cm is null or (height_cm between 100 and 250)),
  activity_level text check (
    activity_level is null
    or activity_level in ('sedentary', 'lightly_active', 'moderately_active', 'very_active', 'extra_active')
  ),
  training_experience text check (
    training_experience is null
    or training_experience in ('beginner', 'intermediate', 'advanced')
  ),
  training_environment text check (
    training_environment is null
    or training_environment in ('home', 'gym', 'outdoor', 'combination')
  ),
  role text not null default 'user' check (role in ('user', 'admin')),
  onboarding_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index profiles_user_id_idx on public.profiles (user_id);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create or replace function private.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.role is distinct from old.role and not private.is_admin() then
    new.role := old.role;
  end if;
  return new;
end;
$$;

create trigger profiles_protect_role
before update on public.profiles
for each row execute function private.protect_profile_role();

create or replace function private.sync_profile_role_to_app_metadata()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
  set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || jsonb_build_object('role', new.role)
  where id = new.user_id;
  return new;
end;
$$;

create trigger profiles_sync_role
after insert or update of role on public.profiles
for each row execute function private.sync_profile_role_to_app_metadata();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, display_name, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)),
    'user'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------
-- Onboarding / goals / body
-- ---------------------------------------------------------------------------

create table public.fitness_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  goal_type text not null check (
    goal_type in ('lose_fat', 'build_muscle', 'get_stronger', 'improve_fitness', 'maintain_weight', 'custom')
  ),
  custom_goal_text text,
  target_weight_kg numeric(5, 1) check (target_weight_kg is null or target_weight_kg between 30 and 300),
  target_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index fitness_goals_user_id_idx on public.fitness_goals (user_id);
create unique index fitness_goals_one_active_idx
  on public.fitness_goals (user_id)
  where is_active;

create trigger fitness_goals_set_updated_at
before update on public.fitness_goals
for each row execute function private.set_updated_at();

create table public.body_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  weight_kg numeric(5, 1) not null check (weight_kg between 30 and 400),
  body_fat_percentage numeric(4, 1) check (body_fat_percentage is null or body_fat_percentage between 3 and 70),
  waist_cm numeric(5, 1) check (waist_cm is null or waist_cm between 40 and 200),
  recorded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index body_metrics_user_recorded_idx on public.body_metrics (user_id, recorded_at desc);

create table public.user_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  training_days_per_week integer check (training_days_per_week is null or training_days_per_week between 1 and 7),
  preferred_weekdays integer[] check (
    preferred_weekdays is null
    or (
      preferred_weekdays <@ array[0, 1, 2, 3, 4, 5, 6]
      and cardinality(preferred_weekdays) between 1 and 7
    )
  ),
  session_duration_minutes integer check (session_duration_minutes is null or session_duration_minutes between 10 and 180),
  diet_type text check (
    diet_type is null
    or diet_type in ('no_preference', 'balanced', 'high_protein', 'vegetarian', 'vegan', 'halal', 'keto', 'mediterranean')
  ),
  meals_per_day integer check (meals_per_day is null or meals_per_day between 2 and 6),
  cooking_ability text check (
    cooking_ability is null
    or cooking_ability in ('none', 'basic', 'intermediate', 'advanced')
  ),
  food_budget text check (
    food_budget is null
    or food_budget in ('low', 'medium', 'flexible')
  ),
  sleep_hours numeric(3, 1) check (sleep_hours is null or sleep_hours between 3 and 14),
  daily_steps_target integer check (daily_steps_target is null or daily_steps_target between 1000 and 30000),
  injuries text,
  limitations text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger user_preferences_set_updated_at
before update on public.user_preferences
for each row execute function private.set_updated_at();

create table public.user_equipment (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  equipment text not null check (
    equipment in (
      'bodyweight', 'dumbbells', 'barbell', 'bench', 'resistance_bands',
      'pull_up_bar', 'machines', 'cable_machine', 'kettlebells', 'other'
    )
  ),
  unique (user_id, equipment)
);

create index user_equipment_user_id_idx on public.user_equipment (user_id);

create table public.user_food_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  rule_type text not null check (rule_type in ('allergy', 'like', 'dislike')),
  value text not null,
  unique (user_id, rule_type, value)
);

create index user_food_rules_user_id_idx on public.user_food_rules (user_id);

create table public.nutrition_targets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  calories integer not null check (calories between 800 and 6000),
  protein_g numeric(6, 1) not null check (protein_g between 20 and 400),
  carbohydrates_g numeric(6, 1) not null check (carbohydrates_g between 20 and 800),
  fat_g numeric(6, 1) not null check (fat_g between 15 and 250),
  bmr numeric(7, 1) not null,
  tdee numeric(7, 1) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger nutrition_targets_set_updated_at
before update on public.nutrition_targets
for each row execute function private.set_updated_at();

-- ---------------------------------------------------------------------------
-- Catalogs
-- ---------------------------------------------------------------------------

create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  primary_muscle text not null,
  secondary_muscles text[] not null default '{}',
  equipment text not null,
  compatible_equipment text[] not null default '{}',
  movement_pattern text,
  difficulty text not null default 'beginner' check (difficulty in ('beginner', 'intermediate', 'advanced')),
  instructions text,
  video_url text,
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index exercises_name_trgm_idx on public.exercises using gin (name gin_trgm_ops);
create index exercises_active_idx on public.exercises (is_active);

create trigger exercises_set_updated_at
before update on public.exercises
for each row execute function private.set_updated_at();

create table public.foods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text,
  serving_size numeric(8, 2) not null check (serving_size > 0),
  serving_unit text not null default 'g',
  calories numeric(7, 1) not null check (calories >= 0),
  protein numeric(6, 1) not null check (protein >= 0),
  carbohydrates numeric(6, 1) not null check (carbohydrates >= 0),
  fat numeric(6, 1) not null check (fat >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index foods_name_trgm_idx on public.foods using gin (name gin_trgm_ops);
create index foods_active_idx on public.foods (is_active);
create unique index foods_name_brand_serving_idx on public.foods (name, coalesce(brand, ''), serving_size, serving_unit);

-- ---------------------------------------------------------------------------
-- Workouts
-- ---------------------------------------------------------------------------

create table public.workout_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  goal text,
  duration_weeks integer check (duration_weeks is null or duration_weeks between 1 and 52),
  days_per_week integer check (days_per_week is null or days_per_week between 1 and 7),
  difficulty text check (difficulty is null or difficulty in ('beginner', 'intermediate', 'advanced')),
  start_date date,
  end_date date,
  status text not null default 'draft' check (status in ('draft', 'active', 'completed', 'archived')),
  source text not null default 'ai' check (source in ('ai', 'manual', 'adapted')),
  prompt_version_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index workout_plans_user_id_idx on public.workout_plans (user_id);
create unique index workout_plans_one_active_idx
  on public.workout_plans (user_id)
  where status = 'active';

create trigger workout_plans_set_updated_at
before update on public.workout_plans
for each row execute function private.set_updated_at();

create table public.workout_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.workout_plans (id) on delete cascade,
  weekday integer not null check (weekday between 0 and 6),
  sort_order integer not null default 0,
  name text not null,
  description text,
  estimated_duration_minutes integer check (estimated_duration_minutes is null or estimated_duration_minutes between 5 and 240),
  status text not null default 'scheduled' check (status in ('scheduled', 'completed', 'skipped')),
  created_at timestamptz not null default now()
);

create index workout_days_plan_id_idx on public.workout_days (plan_id);

create table public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  day_id uuid not null references public.workout_days (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  sort_order integer not null default 0,
  target_sets integer not null default 3 check (target_sets between 1 and 8),
  target_reps_min integer check (target_reps_min is null or target_reps_min between 1 and 50),
  target_reps_max integer check (target_reps_max is null or target_reps_max between 1 and 50),
  target_weight_kg numeric(6, 2),
  rest_seconds integer not null default 90 check (rest_seconds between 0 and 600),
  tempo text,
  notes text,
  created_at timestamptz not null default now()
);

create index workout_exercises_day_id_idx on public.workout_exercises (day_id);
create index workout_exercises_exercise_id_idx on public.workout_exercises (exercise_id);

create table public.workout_sets (
  id uuid primary key default gen_random_uuid(),
  workout_exercise_id uuid not null references public.workout_exercises (id) on delete cascade,
  set_number integer not null check (set_number between 1 and 12),
  target_reps integer check (target_reps is null or target_reps between 1 and 50),
  target_weight_kg numeric(6, 2),
  unique (workout_exercise_id, set_number)
);

create index workout_sets_exercise_idx on public.workout_sets (workout_exercise_id);

create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  plan_id uuid references public.workout_plans (id) on delete set null,
  day_id uuid references public.workout_days (id) on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  paused_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress', 'paused', 'completed', 'abandoned')),
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now()
);

create index workout_sessions_user_idx on public.workout_sessions (user_id, started_at desc);

create table public.workout_set_logs (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  workout_exercise_id uuid references public.workout_exercises (id) on delete set null,
  set_number integer not null check (set_number between 1 and 20),
  weight_kg numeric(6, 2),
  reps integer check (reps is null or reps between 0 and 100),
  duration_seconds integer,
  completed boolean not null default false,
  skipped boolean not null default false,
  notes text,
  completed_at timestamptz,
  client_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now(),
  unique (session_id, client_id)
);

create index workout_set_logs_session_idx on public.workout_set_logs (session_id);

create table public.personal_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id uuid not null references public.exercises (id),
  record_type text not null check (record_type in ('weight', 'reps', 'volume')),
  value numeric(10, 2) not null,
  achieved_at timestamptz not null default now(),
  session_id uuid references public.workout_sessions (id) on delete set null,
  unique (user_id, exercise_id, record_type)
);

create index personal_records_user_idx on public.personal_records (user_id);

-- ---------------------------------------------------------------------------
-- Nutrition
-- ---------------------------------------------------------------------------

create table public.meal_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  status text not null default 'active' check (status in ('draft', 'active', 'archived')),
  calories integer,
  protein_g numeric(6, 1),
  carbohydrates_g numeric(6, 1),
  fat_g numeric(6, 1),
  prompt_version_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index meal_plans_user_idx on public.meal_plans (user_id);
create unique index meal_plans_one_active_idx
  on public.meal_plans (user_id)
  where status = 'active';

create trigger meal_plans_set_updated_at
before update on public.meal_plans
for each row execute function private.set_updated_at();

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  meal_plan_id uuid not null references public.meal_plans (id) on delete cascade,
  weekday integer check (weekday is null or weekday between 0 and 6),
  meal_slot text not null check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  name text not null,
  sort_order integer not null default 0
);

create index meals_plan_idx on public.meals (meal_plan_id);

create table public.meal_foods (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  food_id uuid not null references public.foods (id),
  quantity numeric(8, 2) not null check (quantity > 0),
  unit text not null default 'g',
  calories numeric(7, 1) not null,
  protein numeric(6, 1) not null,
  carbohydrates numeric(6, 1) not null,
  fat numeric(6, 1) not null
);

create index meal_foods_meal_idx on public.meal_foods (meal_id);

create table public.food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  food_id uuid not null references public.foods (id),
  meal_slot text not null check (meal_slot in ('breakfast', 'lunch', 'dinner', 'snack')),
  quantity numeric(8, 2) not null check (quantity > 0),
  unit text not null default 'g',
  calories numeric(7, 1) not null,
  protein numeric(6, 1) not null,
  carbohydrates numeric(6, 1) not null,
  fat numeric(6, 1) not null,
  logged_at timestamptz not null default now(),
  source text not null default 'manual' check (source in ('manual', 'ai', 'plan')),
  created_at timestamptz not null default now()
);

create index food_logs_user_logged_idx on public.food_logs (user_id, logged_at desc);

create table public.nutrition_daily_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,
  calories numeric(8, 1) not null default 0,
  protein numeric(7, 1) not null default 0,
  carbohydrates numeric(7, 1) not null default 0,
  fat numeric(7, 1) not null default 0,
  calorie_target integer,
  protein_target numeric(6, 1),
  unique (user_id, log_date)
);

create index nutrition_daily_logs_user_idx on public.nutrition_daily_logs (user_id, log_date desc);

create or replace function private.refresh_nutrition_daily_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid;
  v_date date;
begin
  v_user := coalesce(new.user_id, old.user_id);
  v_date := (coalesce(new.logged_at, old.logged_at) at time zone 'utc')::date;

  insert into public.nutrition_daily_logs as d (
    user_id, log_date, calories, protein, carbohydrates, fat, calorie_target, protein_target
  )
  select
    v_user,
    v_date,
    coalesce(sum(fl.calories), 0),
    coalesce(sum(fl.protein), 0),
    coalesce(sum(fl.carbohydrates), 0),
    coalesce(sum(fl.fat), 0),
    nt.calories,
    nt.protein_g
  from public.food_logs fl
  left join public.nutrition_targets nt on nt.user_id = v_user
  where fl.user_id = v_user
    and (fl.logged_at at time zone 'utc')::date = v_date
  group by nt.calories, nt.protein_g
  on conflict (user_id, log_date) do update
    set calories = excluded.calories,
        protein = excluded.protein,
        carbohydrates = excluded.carbohydrates,
        fat = excluded.fat,
        calorie_target = excluded.calorie_target,
        protein_target = excluded.protein_target;

  return coalesce(new, old);
end;
$$;

create trigger food_logs_refresh_daily
after insert or update or delete on public.food_logs
for each row execute function private.refresh_nutrition_daily_log();

-- ---------------------------------------------------------------------------
-- AI
-- ---------------------------------------------------------------------------

create table public.ai_prompt_versions (
  id uuid primary key default gen_random_uuid(),
  version integer not null unique,
  system_prompt text not null,
  model text not null,
  temperature numeric(3, 2) not null default 0.4,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id)
);

create unique index ai_prompt_versions_one_active_idx
  on public.ai_prompt_versions (is_active)
  where is_active;

create table public.ai_configurations (
  id uuid primary key default gen_random_uuid(),
  model text not null default 'gpt-4.1',
  temperature numeric(3, 2) not null default 0.4,
  max_output_tokens integer not null default 2000,
  enabled_tools text[] not null default '{}',
  enabled boolean not null default true,
  daily_request_limit integer not null default 50,
  updated_at timestamptz not null default now()
);

create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'Coach',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ai_conversations_user_idx on public.ai_conversations (user_id, updated_at desc);

create trigger ai_conversations_set_updated_at
before update on public.ai_conversations
for each row execute function private.set_updated_at();

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  role text not null check (role in ('user', 'assistant', 'system')),
  content jsonb not null,
  prompt_version_id uuid references public.ai_prompt_versions (id),
  created_at timestamptz not null default now()
);

create index ai_messages_conversation_idx on public.ai_messages (conversation_id, created_at);

create table public.ai_actions (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations (id) on delete cascade,
  message_id uuid references public.ai_messages (id) on delete set null,
  action_type text not null,
  arguments jsonb not null default '{}'::jsonb,
  status text not null default 'proposed' check (
    status in ('proposed', 'approved', 'executed', 'rejected', 'failed')
  ),
  result jsonb,
  requires_confirmation boolean not null default true,
  created_at timestamptz not null default now()
);

create index ai_actions_conversation_idx on public.ai_actions (conversation_id);

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  conversation_id uuid references public.ai_conversations (id) on delete set null,
  model text not null,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  estimated_cost numeric(10, 6) not null default 0,
  prompt_version_id uuid references public.ai_prompt_versions (id),
  created_at timestamptz not null default now()
);

create index ai_usage_user_created_idx on public.ai_usage (user_id, created_at desc);

alter table public.workout_plans
  add constraint workout_plans_prompt_version_fk
  foreign key (prompt_version_id) references public.ai_prompt_versions (id);

alter table public.meal_plans
  add constraint meal_plans_prompt_version_fk
  foreign key (prompt_version_id) references public.ai_prompt_versions (id);

-- ---------------------------------------------------------------------------
-- Health / notifications / analytics
-- ---------------------------------------------------------------------------

create table public.health_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users (id) on delete cascade,
  provider text not null default 'apple_health',
  connected boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger health_connections_set_updated_at
before update on public.health_connections
for each row execute function private.set_updated_at();

create table public.health_metrics (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  metric_type text not null check (
    metric_type in ('steps', 'heart_rate', 'sleep', 'active_energy', 'resting_heart_rate', 'weight')
  ),
  value numeric(12, 2) not null,
  unit text not null,
  recorded_at timestamptz not null,
  source text not null default 'apple_health',
  unique (user_id, metric_type, recorded_at, source)
);

create index health_metrics_user_idx on public.health_metrics (user_id, metric_type, recorded_at desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('workout_reminder', 'meal_reminder', 'weight_reminder', 'coach_insight')),
  title text not null,
  body text not null,
  scheduled_for timestamptz,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, scheduled_for);

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete set null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index analytics_events_user_idx on public.analytics_events (user_id, created_at desc);
create index analytics_events_name_idx on public.analytics_events (event_name);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.fitness_goals enable row level security;
alter table public.fitness_goals force row level security;
alter table public.body_metrics enable row level security;
alter table public.body_metrics force row level security;
alter table public.user_preferences enable row level security;
alter table public.user_preferences force row level security;
alter table public.user_equipment enable row level security;
alter table public.user_equipment force row level security;
alter table public.user_food_rules enable row level security;
alter table public.user_food_rules force row level security;
alter table public.nutrition_targets enable row level security;
alter table public.nutrition_targets force row level security;
alter table public.exercises enable row level security;
alter table public.exercises force row level security;
alter table public.foods enable row level security;
alter table public.foods force row level security;
alter table public.workout_plans enable row level security;
alter table public.workout_plans force row level security;
alter table public.workout_days enable row level security;
alter table public.workout_days force row level security;
alter table public.workout_exercises enable row level security;
alter table public.workout_exercises force row level security;
alter table public.workout_sets enable row level security;
alter table public.workout_sets force row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sessions force row level security;
alter table public.workout_set_logs enable row level security;
alter table public.workout_set_logs force row level security;
alter table public.personal_records enable row level security;
alter table public.personal_records force row level security;
alter table public.meal_plans enable row level security;
alter table public.meal_plans force row level security;
alter table public.meals enable row level security;
alter table public.meals force row level security;
alter table public.meal_foods enable row level security;
alter table public.meal_foods force row level security;
alter table public.food_logs enable row level security;
alter table public.food_logs force row level security;
alter table public.nutrition_daily_logs enable row level security;
alter table public.nutrition_daily_logs force row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_conversations force row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_messages force row level security;
alter table public.ai_actions enable row level security;
alter table public.ai_actions force row level security;
alter table public.health_connections enable row level security;
alter table public.health_connections force row level security;
alter table public.health_metrics enable row level security;
alter table public.health_metrics force row level security;
alter table public.notifications enable row level security;
alter table public.notifications force row level security;
alter table public.analytics_events enable row level security;
alter table public.analytics_events force row level security;
alter table public.ai_prompt_versions enable row level security;
alter table public.ai_prompt_versions force row level security;
alter table public.ai_configurations enable row level security;
alter table public.ai_configurations force row level security;
alter table public.ai_usage enable row level security;
alter table public.ai_usage force row level security;

-- Direct user-owned tables
create policy profiles_select on public.profiles
  for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_update on public.profiles
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy fitness_goals_all on public.fitness_goals
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy body_metrics_all on public.body_metrics
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy user_preferences_all on public.user_preferences
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy user_equipment_all on public.user_equipment
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy user_food_rules_all on public.user_food_rules
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy nutrition_targets_all on public.nutrition_targets
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy workout_plans_all on public.workout_plans
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy workout_sessions_all on public.workout_sessions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy personal_records_all on public.personal_records
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy meal_plans_all on public.meal_plans
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy food_logs_all on public.food_logs
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy nutrition_daily_logs_all on public.nutrition_daily_logs
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy ai_conversations_all on public.ai_conversations
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy health_connections_all on public.health_connections
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy health_metrics_all on public.health_metrics
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy notifications_all on public.notifications
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy analytics_events_insert on public.analytics_events
  for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy analytics_events_select on public.analytics_events
  for select to authenticated
  using (user_id = (select auth.uid()));

-- Nested workout ownership
create policy workout_days_all on public.workout_days
  for all to authenticated
  using (
    exists (
      select 1 from public.workout_plans p
      where p.id = workout_days.plan_id and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.workout_plans p
      where p.id = workout_days.plan_id and p.user_id = (select auth.uid())
    )
  );

create policy workout_exercises_all on public.workout_exercises
  for all to authenticated
  using (
    exists (
      select 1
      from public.workout_days d
      join public.workout_plans p on p.id = d.plan_id
      where d.id = workout_exercises.day_id and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.workout_days d
      join public.workout_plans p on p.id = d.plan_id
      where d.id = workout_exercises.day_id and p.user_id = (select auth.uid())
    )
  );

create policy workout_sets_all on public.workout_sets
  for all to authenticated
  using (
    exists (
      select 1
      from public.workout_exercises we
      join public.workout_days d on d.id = we.day_id
      join public.workout_plans p on p.id = d.plan_id
      where we.id = workout_sets.workout_exercise_id and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.workout_exercises we
      join public.workout_days d on d.id = we.day_id
      join public.workout_plans p on p.id = d.plan_id
      where we.id = workout_sets.workout_exercise_id and p.user_id = (select auth.uid())
    )
  );

create policy workout_set_logs_all on public.workout_set_logs
  for all to authenticated
  using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_set_logs.session_id and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.workout_sessions s
      where s.id = workout_set_logs.session_id and s.user_id = (select auth.uid())
    )
  );

create policy meals_all on public.meals
  for all to authenticated
  using (
    exists (
      select 1 from public.meal_plans mp
      where mp.id = meals.meal_plan_id and mp.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.meal_plans mp
      where mp.id = meals.meal_plan_id and mp.user_id = (select auth.uid())
    )
  );

create policy meal_foods_all on public.meal_foods
  for all to authenticated
  using (
    exists (
      select 1
      from public.meals m
      join public.meal_plans mp on mp.id = m.meal_plan_id
      where m.id = meal_foods.meal_id and mp.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.meals m
      join public.meal_plans mp on mp.id = m.meal_plan_id
      where m.id = meal_foods.meal_id and mp.user_id = (select auth.uid())
    )
  );

create policy ai_messages_all on public.ai_messages
  for all to authenticated
  using (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_messages.conversation_id and c.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_messages.conversation_id and c.user_id = (select auth.uid())
    )
  );

create policy ai_actions_all on public.ai_actions
  for all to authenticated
  using (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_actions.conversation_id and c.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_actions.conversation_id and c.user_id = (select auth.uid())
    )
  );

create policy exercises_select on public.exercises
  for select to authenticated using (is_active or private.is_admin());
create policy exercises_write on public.exercises
  for all to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy foods_select on public.foods
  for select to authenticated using (is_active or private.is_admin());
create policy foods_write on public.foods
  for all to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy ai_prompt_admin on public.ai_prompt_versions
  for all to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy ai_config_admin on public.ai_configurations
  for all to authenticated
  using (private.is_admin())
  with check (private.is_admin());

create policy ai_usage_admin_select on public.ai_usage
  for select to authenticated
  using (private.is_admin() or user_id = (select auth.uid()));

-- Grants
grant usage on schema public to anon, authenticated, service_role;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.fitness_goals to authenticated;
grant select, insert, update, delete on public.body_metrics to authenticated;
grant select, insert, update, delete on public.user_preferences to authenticated;
grant select, insert, update, delete on public.user_equipment to authenticated;
grant select, insert, update, delete on public.user_food_rules to authenticated;
grant select, insert, update, delete on public.nutrition_targets to authenticated;
grant select on public.exercises to authenticated;
grant select, insert, update, delete on public.exercises to authenticated;
grant select on public.foods to authenticated;
grant select, insert, update, delete on public.foods to authenticated;
grant select, insert, update, delete on public.workout_plans to authenticated;
grant select, insert, update, delete on public.workout_days to authenticated;
grant select, insert, update, delete on public.workout_exercises to authenticated;
grant select, insert, update, delete on public.workout_sets to authenticated;
grant select, insert, update, delete on public.workout_sessions to authenticated;
grant select, insert, update, delete on public.workout_set_logs to authenticated;
grant select, insert, update, delete on public.personal_records to authenticated;
grant select, insert, update, delete on public.meal_plans to authenticated;
grant select, insert, update, delete on public.meals to authenticated;
grant select, insert, update, delete on public.meal_foods to authenticated;
grant select, insert, update, delete on public.food_logs to authenticated;
grant select, insert, update, delete on public.nutrition_daily_logs to authenticated;
grant select, insert, update, delete on public.ai_conversations to authenticated;
grant select, insert, update, delete on public.ai_messages to authenticated;
grant select, insert, update, delete on public.ai_actions to authenticated;
grant select, insert, update, delete on public.health_connections to authenticated;
grant select, insert, update, delete on public.health_metrics to authenticated;
grant select, insert, update, delete on public.notifications to authenticated;
grant select, insert on public.analytics_events to authenticated;
grant select on public.ai_usage to authenticated;

revoke all on public.ai_prompt_versions from anon, authenticated;
revoke all on public.ai_configurations from anon, authenticated;
grant all on public.ai_prompt_versions to service_role;
grant all on public.ai_configurations to service_role;
grant all on public.ai_usage to service_role;

-- Admin policies already allow authenticated admins; grant table rights so policies can apply.
grant select, insert, update, delete on public.ai_prompt_versions to authenticated;
grant select, insert, update, delete on public.ai_configurations to authenticated;

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', false),
  ('exercise-media', 'exercise-media', true)
on conflict (id) do nothing;

create policy avatars_select on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_update on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy avatars_delete on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy exercise_media_select on storage.objects
  for select to authenticated
  using (bucket_id = 'exercise-media');

create policy exercise_media_write on storage.objects
  for all to authenticated
  using (bucket_id = 'exercise-media' and private.is_admin())
  with check (bucket_id = 'exercise-media' and private.is_admin());

-- ---------------------------------------------------------------------------
-- Private validation helpers used by Edge Functions
-- ---------------------------------------------------------------------------

create or replace function private.assert_exercise_allowed(p_exercise_id uuid, p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_exists boolean;
  v_compatible text[];
  v_has_equipment boolean;
begin
  select true, e.compatible_equipment
    into v_exists, v_compatible
  from public.exercises e
  where e.id = p_exercise_id and e.is_active;

  if v_exists is not true then
    raise exception 'exercise_not_found';
  end if;

  select exists (
    select 1
    from public.user_equipment ue
    where ue.user_id = p_user_id
      and (
        ue.equipment = any (v_compatible)
        or 'bodyweight' = any (v_compatible)
      )
  ) into v_has_equipment;

  if not v_has_equipment then
    raise exception 'exercise_incompatible_equipment';
  end if;
end;
$$;
