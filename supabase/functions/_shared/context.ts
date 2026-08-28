import { SupabaseClient } from 'npm:@supabase/supabase-js@2'

export async function buildContext(supabase: SupabaseClient, userId: string) {
  const [{ data: profile }, { data: goal }, { data: metrics }, { data: plan }, { data: sessions }, { data: nutrition }] =
    await Promise.all([
      supabase.from('profiles').select('*').eq('user_id', userId).maybeSingle(),
      supabase.from('fitness_goals').select('*').eq('is_active', true).maybeSingle(),
      supabase.from('body_metrics').select('weight_kg, recorded_at').order('recorded_at', { ascending: false }).limit(30),
      supabase.from('workout_plans').select('id, name, status, days_per_week, workout_days(id, weekday, name, workout_exercises(id, target_sets, target_reps_min, target_reps_max, exercise_id))').eq('status', 'active').maybeSingle(),
      supabase.from('workout_sessions').select('id, started_at, status, duration_seconds').order('started_at', { ascending: false }).limit(7),
      supabase.from('nutrition_daily_logs').select('*').order('log_date', { ascending: false }).limit(14),
    ])

  return {
    user: {
      age: profile?.age,
      height_cm: profile?.height_cm,
      weight_kg: metrics?.[0]?.weight_kg,
      target_weight_kg: goal?.target_weight_kg,
      goal: goal?.goal_type,
      experience: profile?.training_experience,
      environment: profile?.training_environment,
    },
    training: { current_plan: plan },
    recent_performance: sessions ?? [],
    nutrition: nutrition ?? [],
    progress: { weights: (metrics ?? []).map((row: { weight_kg: number }) => row.weight_kg) },
  }
}
