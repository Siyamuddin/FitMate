import { SupabaseClient } from 'npm:@supabase/supabase-js@2'

const WEEKDAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']

function weekdayName(value: unknown) {
  const n = Number(value)
  if (!Number.isInteger(n) || n < 0 || n > 6) return null
  return WEEKDAYS[n]
}

export async function buildContext(supabase: SupabaseClient, userId: string) {
  const today = new Date().toISOString().slice(0, 10)
  const [
    { data: profile },
    { data: goal },
    { data: metrics },
    { data: plan },
    { data: sessions },
    { data: nutrition },
    { data: targets },
    { data: catalog },
    { data: foodLogs },
    { data: mealPlan },
  ] = await Promise.all([
    supabase.from('profiles').select(
      'age, height_cm, activity_level, training_experience, training_environment, display_name, sex',
    ).eq('user_id', userId).maybeSingle(),
    supabase.from('fitness_goals').select('goal_type, target_weight_kg, custom_goal_text').eq('is_active', true).maybeSingle(),
    supabase.from('body_metrics').select('weight_kg, recorded_at').order('recorded_at', { ascending: false }).limit(30),
    supabase.from('workout_plans').select(
      'id, name, status, days_per_week, workout_days(id, weekday, name, workout_exercises(id, target_sets, target_reps_min, target_reps_max, rest_seconds, exercise_id, exercises(id, name)))',
    ).eq('status', 'active').maybeSingle(),
    supabase.from('workout_sessions').select('id, started_at, status, duration_seconds').order('started_at', { ascending: false }).limit(7),
    supabase.from('nutrition_daily_logs').select(
      'log_date, calories, protein, carbohydrates, fat, calorie_target, protein_target',
    ).order('log_date', { ascending: false }).limit(14),
    supabase.from('nutrition_targets').select('calories, protein_g, carbohydrates_g, fat_g, bmr, tdee').eq('user_id', userId).maybeSingle(),
    supabase.from('exercises').select('id, name').eq('is_active', true).order('name').limit(400),
    supabase.from('food_logs').select('id, meal_slot, quantity, calories, protein, foods(name)').gte('logged_at', `${today}T00:00:00.000Z`).order('logged_at', { ascending: false }).limit(30),
    supabase.from('meal_plans').select(
      'id, name, calories, protein_g, meals(weekday, meal_slot, name, meal_foods(quantity, foods(name)))',
    ).eq('status', 'active').maybeSingle(),
  ])

  const days = ((plan as { workout_days?: unknown[] } | null)?.workout_days ?? []).map((raw) => {
    const day = raw as {
      id?: string
      weekday?: number
      name?: string
      workout_exercises?: unknown[]
    }
    return {
      id: day.id,
      weekday: day.weekday,
      weekday_name: weekdayName(day.weekday),
      name: day.name,
      exercises: (day.workout_exercises ?? []).map((item) => {
        const row = item as {
          id?: string
          target_sets?: number
          target_reps_min?: number
          rest_seconds?: number
          exercise_id?: string
          exercises?: { id?: string; name?: string } | { id?: string; name?: string }[]
        }
        const exercise = Array.isArray(row.exercises) ? row.exercises[0] : row.exercises
        return {
          id: row.id,
          exercise_id: exercise?.id ?? row.exercise_id,
          name: exercise?.name ?? 'Exercise',
          sets: row.target_sets,
          reps: row.target_reps_min,
          rest_seconds: row.rest_seconds,
        }
      }),
    }
  })

  return {
    user: {
      name: profile?.display_name,
      age: profile?.age,
      sex: profile?.sex,
      height_cm: profile?.height_cm,
      weight_kg: metrics?.[0]?.weight_kg,
      target_weight_kg: goal?.target_weight_kg,
      goal: goal?.goal_type,
      custom_goal: goal?.custom_goal_text,
      experience: profile?.training_experience,
      environment: profile?.training_environment,
      activity_level: profile?.activity_level,
    },
    nutrition_targets: targets,
    training: {
      plan_id: plan?.id,
      plan_name: plan?.name,
      days_per_week: plan?.days_per_week,
      days,
    },
    exercise_catalog: (catalog ?? []).map((row: { id: string; name: string }) => ({
      id: row.id,
      name: row.name,
    })),
    recent_performance: sessions ?? [],
    nutrition_days: nutrition ?? [],
    today_food_logs: (foodLogs ?? []).map((row: {
      id: string
      meal_slot: string
      quantity: number
      calories: number
      protein: number
      foods?: { name?: string } | { name?: string }[]
    }) => {
      const food = Array.isArray(row.foods) ? row.foods[0] : row.foods
      return {
        id: row.id,
        name: food?.name ?? 'Food',
        meal_slot: row.meal_slot,
        quantity: row.quantity,
        calories: row.calories,
        protein: row.protein,
      }
    }),
    meal_plan: mealPlan
      ? {
        name: (mealPlan as { name?: string }).name,
        calories: (mealPlan as { calories?: number }).calories,
        protein_g: (mealPlan as { protein_g?: number }).protein_g,
        meals: ((mealPlan as { meals?: unknown[] }).meals ?? []).map((raw) => {
          const meal = raw as {
            weekday?: number
            meal_slot?: string
            name?: string
            meal_foods?: { quantity?: number; foods?: { name?: string } | { name?: string }[] }[]
          }
          return {
            weekday_name: weekdayName(meal.weekday),
            slot: meal.meal_slot,
            name: meal.name,
            foods: (meal.meal_foods ?? []).map((item) => {
              const food = Array.isArray(item.foods) ? item.foods[0] : item.foods
              return { name: food?.name, quantity: item.quantity }
            }),
          }
        }),
      }
      : null,
    progress: {
      weights: (metrics ?? []).map((row: { weight_kg: number; recorded_at: string }) => ({
        weight_kg: row.weight_kg,
        recorded_at: row.recorded_at,
      })),
    },
  }
}
