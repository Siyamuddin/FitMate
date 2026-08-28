import { corsHeaders, json } from '../_shared/cors.ts'
import { adminClient, requireUser } from '../_shared/auth.ts'
import { targets } from '../_shared/fitness.ts'
import { chatJson } from '../_shared/openai.ts'
import { enforceRateLimit, recordUsage } from '../_shared/usage.ts'
import { requireExerciseId, validateReps, validateRest, validateSets } from '../_shared/validate.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { user, supabase } = await requireUser(req)
    const admin = adminClient()
    const config = await enforceRateLimit(admin, user.id)

    const { data: profile } = await supabase.from('profiles').select('*').eq('user_id', user.id).single()
    const { data: goal } = await supabase.from('fitness_goals').select('*').eq('is_active', true).maybeSingle()
    const { data: metric } = await supabase.from('body_metrics').select('*').order('recorded_at', { ascending: false }).limit(1).maybeSingle()
    const { data: prefs } = await supabase.from('user_preferences').select('*').eq('user_id', user.id).maybeSingle()
    const { data: equipment } = await supabase.from('user_equipment').select('equipment').eq('user_id', user.id)
    const { data: exercises } = await supabase.from('exercises').select('id, name, equipment, compatible_equipment, primary_muscle').eq('is_active', true)
    const { data: foods } = await supabase.from('foods').select('id, name, calories, protein, carbohydrates, fat').eq('is_active', true).limit(80)
    const { data: prompt } = await admin.from('ai_prompt_versions').select('*').eq('is_active', true).maybeSingle()

    const metrics = targets({
      age: profile.age,
      sex: profile.sex,
      heightCm: Number(profile.height_cm),
      weightKg: Number(metric?.weight_kg ?? 74),
      activityLevel: profile.activity_level,
      goalType: goal?.goal_type ?? 'improve_fitness',
    })

    const allowed = new Set((exercises ?? []).map((row: { id: string }) => row.id))
    const result = await chatJson({
      model: config?.model ?? prompt?.model ?? 'gpt-4.1',
      temperature: Number(config?.temperature ?? prompt?.temperature ?? 0.4),
      maxTokens: config?.max_output_tokens ?? 2500,
      system: prompt?.system_prompt ?? 'You are FitMate. Return JSON only.',
      user: JSON.stringify({
        instruction: 'Create a structured workout plan and meal outline using only provided exercise and food IDs.',
        profile,
        goal,
        prefs,
        equipment,
        metrics,
        exercises,
        foods,
        schema: {
          workout: { name: 'string', days: [{ weekday: 0, name: 'string', exercises: [{ exercise_id: 'uuid', sets: 3, reps: 10, rest_seconds: 90 }] }] },
          meals: [{ slot: 'breakfast', name: 'string', food_ids: ['uuid'] }],
        },
      }),
    })

    await recordUsage(admin, {
      userId: user.id,
      model: result.model,
      input: result.usage.prompt_tokens,
      output: result.usage.completion_tokens,
      promptVersionId: prompt?.id,
    })

    const workout = result.parsed.workout
    if (!workout?.days?.length) throw new Error('invalid_plan')

    await supabase.from('workout_plans').update({ status: 'archived' }).eq('user_id', user.id).eq('status', 'active')
    const { data: plan, error: planError } = await supabase.from('workout_plans').insert({
      user_id: user.id,
      name: workout.name ?? 'FitMate Plan',
      goal: goal?.goal_type,
      days_per_week: workout.days.length,
      status: 'active',
      source: 'ai',
      prompt_version_id: prompt?.id ?? null,
      start_date: new Date().toISOString().slice(0, 10),
    }).select('id').single()
    if (planError || !plan) throw planError ?? new Error('plan_insert_failed')

    for (const [index, day] of workout.days.entries()) {
      const { data: dayRow, error: dayError } = await supabase.from('workout_days').insert({
        plan_id: plan.id,
        weekday: Number(day.weekday ?? index),
        sort_order: index,
        name: day.name ?? `Day ${index + 1}`,
        estimated_duration_minutes: prefs?.session_duration_minutes ?? 45,
      }).select('id').single()
      if (dayError || !dayRow) continue
      for (const [exIndex, item] of (day.exercises ?? []).entries()) {
        const exerciseId = requireExerciseId(item.exercise_id, allowed)
        const sets = validateSets(item.sets ?? 3)
        const reps = validateReps(item.reps ?? 10)
        const rest = validateRest(item.rest_seconds ?? 90)
        const { data: we } = await supabase.from('workout_exercises').insert({
          day_id: dayRow.id,
          exercise_id: exerciseId,
          sort_order: exIndex,
          target_sets: sets,
          target_reps_min: reps,
          target_reps_max: reps,
          rest_seconds: rest,
        }).select('id').single()
        if (we) {
          for (let setNumber = 1; setNumber <= sets; setNumber++) {
            await supabase.from('workout_sets').insert({
              workout_exercise_id: we.id,
              set_number: setNumber,
              target_reps: reps,
            })
          }
        }
      }
    }

    if (Array.isArray(result.parsed.meals) && result.parsed.meals.length) {
      await supabase.from('meal_plans').update({ status: 'archived' }).eq('user_id', user.id).eq('status', 'active')
      const { data: mealPlan } = await supabase.from('meal_plans').insert({
        user_id: user.id,
        name: 'FitMate meals',
        status: 'active',
        calories: metrics.calories,
        protein_g: metrics.proteinG,
        carbohydrates_g: metrics.carbohydratesG,
        fat_g: metrics.fatG,
        prompt_version_id: prompt?.id ?? null,
      }).select('id').single()
      if (mealPlan) {
        const allowedFoods = new Set((foods ?? []).map((row: { id: string }) => row.id))
        for (const [index, meal] of result.parsed.meals.entries()) {
          const { data: mealRow } = await supabase.from('meals').insert({
            meal_plan_id: mealPlan.id,
            meal_slot: ['breakfast', 'lunch', 'dinner', 'snack'].includes(meal.slot) ? meal.slot : 'lunch',
            name: meal.name ?? `Meal ${index + 1}`,
            sort_order: index,
          }).select('id').single()
          if (!mealRow) continue
          for (const foodId of meal.food_ids ?? []) {
            if (!allowedFoods.has(foodId)) continue
            const food = (foods ?? []).find((row: { id: string }) => row.id === foodId)
            if (!food) continue
            await supabase.from('meal_foods').insert({
              meal_id: mealRow.id,
              food_id: foodId,
              quantity: 1,
              unit: 'serving',
              calories: food.calories,
              protein: food.protein,
              carbohydrates: food.carbohydrates,
              fat: food.fat,
            })
          }
        }
      }
    }

    return json({ plan_id: plan.id, metrics })
  } catch (error) {
    if (error instanceof Response) return error
    const message = error instanceof Error ? error.message : 'plan_failed'
    if (message === 'rate_limited') return json({ error: 'Daily coaching limit reached.' }, 429)
    return json({ error: 'Could not generate a plan. Your profile is saved.' }, 400)
  }
})
