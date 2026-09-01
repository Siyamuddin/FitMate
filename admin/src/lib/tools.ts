export const READ_TOOLS = [
  'get_user_profile',
  'get_current_goal',
  'get_current_workout_plan',
  'get_recent_workout_history',
  'get_exercise_history',
  'get_nutrition_summary',
  'get_weight_history',
  'get_progress_summary',
] as const

export const WRITE_TOOLS = [
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
] as const

export const MODELS = ['gpt-5.6-luna', 'gpt-5.6-terra', 'gpt-5.6-sol'] as const

export function isGpt56(model: string) {
  return model.includes('gpt-5.6') || model.includes('luna') || model.includes('terra') || model.includes('sol')
}

export const CONTEXT_SHAPE = `{
  profile, goal, plan,
  recent_sessions,
  nutrition_logs,
  weight_history
}`
