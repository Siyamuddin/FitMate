import { corsHeaders, json } from '../_shared/cors.ts'
import { requireUser } from '../_shared/auth.ts'
import { validateReps, validateSets } from '../_shared/validate.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { user, supabase } = await requireUser(req)
    const body = await req.json()
    const actions = Array.isArray(body.actions) ? body.actions : []

    for (const action of actions) {
      const type = String(action.type ?? '')
      const targetId = String(action.target_id ?? '')
      const changes = action.changes ?? {}

      if (type === 'modify_workout_exercise' && targetId) {
        const { data: owned } = await supabase
          .from('workout_exercises')
          .select('id, workout_days!inner(plan_id, workout_plans!inner(user_id, status))')
          .eq('id', targetId)
          .maybeSingle()
        if (!owned) throw new Error('not_owned')
        const patch: Record<string, unknown> = {}
        if (changes.sets !== undefined || changes.target_sets !== undefined) {
          patch.target_sets = validateSets(changes.sets ?? changes.target_sets)
        }
        if (changes.reps !== undefined) {
          patch.target_reps_min = validateReps(changes.reps)
          patch.target_reps_max = validateReps(changes.reps)
        }
        if (Object.keys(patch).length) {
          await supabase.from('workout_exercises').update(patch).eq('id', targetId)
        }
      }

      if (type === 'record_weight') {
        const weight = Number(changes.weight_kg)
        if (weight >= 30 && weight <= 400) {
          await supabase.from('body_metrics').insert({ user_id: user.id, weight_kg: weight })
        }
      }

      if (type === 'update_goal' && changes.target_weight_kg) {
        await supabase.from('fitness_goals').update({
          target_weight_kg: Number(changes.target_weight_kg),
        }).eq('user_id', user.id).eq('is_active', true)
      }

      await supabase.from('ai_actions').update({
        status: 'executed',
        result: { ok: true },
      }).eq('action_type', type).eq('status', 'proposed')
    }

    return json({ ok: true })
  } catch (error) {
    if (error instanceof Response) return error
    return json({ error: 'Could not apply those changes.' }, 400)
  }
})
