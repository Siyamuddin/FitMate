import { corsHeaders, json } from '../_shared/cors.ts'
import { adminClient, requireUser } from '../_shared/auth.ts'
import { buildContext } from '../_shared/context.ts'
import { chatJson } from '../_shared/openai.ts'
import { failClosedMessage, sanitizeUserMessage } from '../_shared/safety.ts'
import { LOW_RISK } from '../_shared/tools.ts'
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
      model: config?.model ?? prompt?.model ?? 'gpt-4.1',
      temperature: Number(config?.temperature ?? 0.4),
      maxTokens: config?.max_output_tokens ?? 1200,
      system: `${prompt?.system_prompt ?? ''}\nReturn JSON with keys: message, requires_confirmation, actions (array of {type, target_id, changes}).`,
      user: JSON.stringify({ message, context }),
    })

    const actions = Array.isArray(result.parsed.actions) ? result.parsed.actions : []
    const requiresConfirmation = result.parsed.requires_confirmation !== false && actions.some((action: { type?: string }) => !LOW_RISK.has(action.type ?? ''))

    const { data: assistant } = await supabase.from('ai_messages').insert({
      conversation_id: conversationId,
      role: 'assistant',
      content: result.parsed,
      prompt_version_id: prompt?.id ?? null,
    }).select('id').single()

    if (actions.length) {
      await supabase.from('ai_actions').insert(actions.map((action: Record<string, unknown>) => ({
        conversation_id: conversationId,
        message_id: assistant?.id,
        action_type: action.type,
        arguments: action,
        status: requiresConfirmation ? 'proposed' : 'executed',
        requires_confirmation: requiresConfirmation,
      })))
    }

    if (!requiresConfirmation) {
      for (const action of actions) {
        await applyAction(supabase, user.id, action)
      }
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
      message: result.parsed.message ?? 'I am here to help with your training.',
      requires_confirmation: requiresConfirmation,
      actions,
      conversation_id: conversationId,
    })
  } catch (error) {
    if (error instanceof Response) return error
    const message = error instanceof Error ? error.message : 'chat_failed'
    if (message === 'rate_limited') return json({ error: 'Daily coaching limit reached.' }, 429)
    return json({ error: failClosedMessage() }, 400)
  }
})

async function applyAction(supabase: ReturnType<typeof requireUser> extends Promise<infer T> ? T extends { supabase: infer S } ? S : never : never, userId: string, action: Record<string, unknown>) {
  if (action.type === 'record_weight' && action.changes && typeof action.changes === 'object') {
    const weight = Number((action.changes as { weight_kg?: number }).weight_kg)
    if (weight >= 30 && weight <= 400) {
      await supabase.from('body_metrics').insert({ user_id: userId, weight_kg: weight })
    }
  }
}
