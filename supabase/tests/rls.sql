-- RLS isolation checks for two users A and B.
-- Nested tables must never leak by UUID.

select tablename
from pg_tables
where schemaname = 'public'
  and rowsecurity = false;

select polname, tablename, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'workout_days',
    'workout_exercises',
    'workout_sets',
    'workout_set_logs',
    'ai_messages',
    'ai_actions',
    'meal_foods',
    'meals',
    'health_metrics',
    'health_connections'
  )
order by tablename, polname;

select tablename, polname
from pg_policies
where schemaname = 'public'
  and tablename in ('ai_prompt_versions', 'ai_configurations', 'ai_usage');

select tablename, qual
from pg_policies
where schemaname = 'public'
  and tablename in ('workout_days', 'workout_exercises', 'workout_set_logs', 'ai_messages', 'meal_foods')
  and (qual ilike '%exists%' or with_check ilike '%exists%');
