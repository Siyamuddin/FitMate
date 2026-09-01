import { SupabaseClient } from 'npm:@supabase/supabase-js@2'
import { assertNoUserIdOverride } from './safety.ts'

export function toolDefinitions() {
  const read = [
    'get_user_profile',
    'get_current_goal',
    'get_current_workout_plan',
    'get_recent_workout_history',
    'get_exercise_history',
    'get_nutrition_summary',
    'get_weight_history',
    'get_progress_summary',
  ]
  const write = [
    'create_workout_plan',
    'update_training_plan',
    'modify_workout_day',
    'modify_workout_exercise',
    'add_exercise',
    'remove_exercise',
    'replace_exercise',
    'update_workout_set',
    'create_meal_plan',
    'modify_meal_plan',
    'add_food_log',
    'update_goal',
    'record_weight',
  ]
  return [...read, ...write].map((name) => ({
    type: 'function',
    function: {
      name,
      description: name.replaceAll('_', ' '),
      parameters: {
        type: 'object',
        additionalProperties: false,
        properties: {
          target_id: { type: 'string' },
          changes: { type: 'object' },
        },
      },
    },
  }))
}

export const LOW_RISK = new Set(['record_weight'])

export async function executeReadTool(
  supabase: SupabaseClient,
  userId: string,
  name: string,
) {
  assertNoUserIdOverride({ name })
  switch (name) {
    case 'get_user_profile':
      return (await supabase.from('profiles').select('*').eq('user_id', userId).maybeSingle()).data
    case 'get_current_goal':
      return (await supabase.from('fitness_goals').select('*').eq('is_active', true).maybeSingle()).data
    case 'get_current_workout_plan':
      return (await supabase.from('workout_plans').select('id, name, status, days_per_week').eq('status', 'active').maybeSingle()).data
    case 'get_recent_workout_history':
      return (await supabase.from('workout_sessions').select('id, started_at, status, duration_seconds').order('started_at', { ascending: false }).limit(7)).data
    case 'get_nutrition_summary':
      return (await supabase.from('nutrition_daily_logs').select('*').order('log_date', { ascending: false }).limit(14)).data
    case 'get_weight_history':
      return (await supabase.from('body_metrics').select('weight_kg, recorded_at').order('recorded_at', { ascending: false }).limit(30)).data
    case 'get_progress_summary':
      return (await supabase.from('personal_records').select('*').limit(10)).data
    default:
      return null
  }
}
