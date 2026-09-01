import { corsHeaders, json } from '../_shared/cors.ts'
import { adminClient, requireUser } from '../_shared/auth.ts'
import { buildContext } from '../_shared/context.ts'
import { chatJson } from '../_shared/openai.ts'
import { failClosedMessage, sanitizeUserMessage } from '../_shared/safety.ts'
import { LOW_RISK } from '../_shared/tools.ts'
import { APPLIABLE_ACTIONS, honestCoachMessage } from '../_shared/honesty.ts'
import { enforceRateLimit, recordUsage } from '../_shared/usage.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const { user, supabase } = await requireUser(req)
    const admin = adminClient()
    const config = await enforceRateLimit(admin, user.id)
    const body = await req.json()
    const message = sanitizeUserMessage(String(body.message ?? ''))
    if (!message) return json({ error: 'Message required' }, 400)

    const context = await buildContext(supabase, user.id)
    const { data: prompt } = await admin.from('ai_prompt_versions').select('*').eq('is_active', true).maybeSingle()

    let conversationId = body.conversation_id as string | undefined
    if (!conversationId) {
      const { data: existing } = await supabase.from('ai_conversations').select('id').order('updated_at', { ascending: false }).limit(1).maybeSingle()
      if (existing) conversationId = existing.id
      else {
        const { data: created } = await supabase.from('ai_conversations').insert({ user_id: user.id, title: 'Coach' }).select('id').single()
        conversationId = created?.id
      }
    }

    await supabase.from('ai_messages').insert({
      conversation_id: conversationId,
      role: 'user',
      content: { message },
    })

    const result = await chatJson({
      model: config?.model ?? prompt?.model ?? 'gpt-5.6-luna',
      temperature: Number(config?.temperature ?? 0.4),
      maxTokens: config?.max_output_tokens ?? 1200,
      system: `${prompt?.system_prompt ?? ''}\n${prompt?.coach_instruction ?? 'Return JSON with keys: message, requires_confirmation, actions (array of {type, target_id, changes}).'}\nNever say you updated, saved, or applied a plan change. High-risk changes (training days, workouts, goals) are proposals only until the user taps Apply. Allowed action types: update_training_plan, modify_workout_day, modify_workout_exercise, update_goal, record_weight. For weekly training days, use update_training_plan with the active plan id and changes.days_per_week. To add a day, include add_workout_day { name, weekday, exercises: [{ exercise_id, sets, reps, rest_seconds }] } using only provided exercise IDs. To drop a day, include remove_workout_day_id with that day's id.`,
      user: JSON.stringify({ message, context }),
    })

    const rawActions = Array.isArray(result.parsed.actions) ? result.parsed.actions as Record<string, unknown>[] : []
    const actions = rawActions.filter((action) => APPLIABLE_ACTIONS.has(String(action.type ?? '')))
    const droppedUnsupported = rawActions.length > actions.length
    const requiresConfirmation = actions.some((action) => !LOW_RISK.has(String(action.type ?? '')))

    let applied = false
    if (!requiresConfirmation && actions.length) {
      applied = await applyLowRisk(supabase, user.id, actions)
    }

    const messageText = honestCoachMessage({
      message: String(result.parsed.message ?? ''),
      requiresConfirmation,
      applied,
      droppedUnsupported,
    })

    const { data: assistant } = await supabase.from('ai_messages').insert({
      conversation_id: conversationId,
      role: 'assistant',
      content: {
        ...result.parsed,
        message: messageText,
        requires_confirmation: requiresConfirmation,
        actions,
        applied,
      },
      prompt_version_id: prompt?.id ?? null,
    }).select('id').single()

    if (actions.length) {
      await supabase.from('ai_actions').insert(actions.map((action) => ({
        conversation_id: conversationId,
        message_id: assistant?.id,
        action_type: action.type,
        arguments: action,
        status: requiresConfirmation ? 'proposed' : applied ? 'executed' : 'failed',
        requires_confirmation: requiresConfirmation,
        result: applied ? { ok: true } : requiresConfirmation ? null : { ok: false },
      })))
    }

    await recordUsage(admin, {
      userId: user.id,
      conversationId,
      model: result.model,
      input: result.usage.prompt_tokens,
      output: result.usage.completion_tokens,
      promptVersionId: prompt?.id,
    })

    return json({
      message: messageText,
      requires_confirmation: requiresConfirmation,
      applied,
      actions: requiresConfirmation ? actions : [],
      conversation_id: conversationId,
    })
  } catch (error) {
    if (error instanceof Response) return error
    const message = error instanceof Error ? error.message : 'chat_failed'
    if (message === 'rate_limited') return json({ error: 'Daily coaching limit reached.' }, 429)
    if (message === 'coach_disabled') return json({ error: 'Coaching is temporarily unavailable.' }, 400)
    return json({ error: failClosedMessage() }, 400)
  }
})

async function applyLowRisk(
  supabase: ReturnType<typeof requireUser> extends Promise<infer T> ? T extends { supabase: infer S } ? S : never : never,
  userId: string,
  actions: Record<string, unknown>[],
) {
  let saved = false
  for (const action of actions) {
    if (action.type !== 'record_weight') continue
    const changes = action.changes && typeof action.changes === 'object' ? action.changes as { weight_kg?: number } : {}
    const weight = Number(changes.weight_kg)
    if (weight < 30 || weight > 400) continue
    const { error } = await supabase.from('body_metrics').insert({ user_id: userId, weight_kg: weight })
    if (error) throw error
    saved = true
  }
  return saved
}
